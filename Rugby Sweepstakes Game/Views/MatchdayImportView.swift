import SwiftUI

struct MatchdayImportView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var client = HighlightlyClient()
    @State private var source = FixtureSource.live
    @State private var date = Date()
    @State private var fixtures: [MatchdayFixture] = []
    @State private var totalCount = 0
    @State private var nextOffset = 0
    @State private var search = ""
    @State private var leagueID: Int?
    @State private var error: String?
    @State private var loading = false
    @State private var connected = false
    @State private var showConnection = false
    @State private var hasLoaded = false
    @State private var loadTask: Task<Void, Never>?
    private enum FixtureSource: String, CaseIterable, Identifiable {
        case live = "Live Fixtures", samples = "Samples"
        var id: String { rawValue }
    }
    private var dateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private var leagues: [MatchdayFixture.League] {
        var seen: Set<Int> = []
        return fixtures.compactMap(\.league).filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }
    }
    private var visibleFixtures: [MatchdayFixture] {
        fixtures.filter {
            (leagueID == nil || $0.league?.id == leagueID) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || ($0.league?.name ?? "").localizedCaseInsensitiveContains(search))
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Fixture source", selection: $source) {
                        ForEach(FixtureSource.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    if source == .live {
                        DatePicker("Match date", selection: $date, displayedComponents: .date)
                        Button { beginLoad() } label: {
                            Label(loading ? "Loading Fixtures…" : "Load Fixtures", systemImage: "arrow.clockwise")
                        }.disabled(loading || !connected)
                        if !connected {
                            Button("Connect Highlightly") { showConnection = true }
                            Text("Connect your account to find Premiership and international fixtures.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Lookups use your plan’s allowance. Results are cached briefly; there is no background polling.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Historical samples for trying the app without an API connection.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.orange) }
                }
                if !fixtures.isEmpty {
                    Section {
                        TextField("Search team or competition", text: $search)
                            .autocorrectionDisabled()
                        if !leagues.isEmpty {
                            Picker("Competition", selection: $leagueID) {
                                Text("All competitions").tag(nil as Int?)
                                ForEach(leagues, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                            }
                        }
                    }
                }
                if loading && fixtures.isEmpty { ProgressView("Finding fixtures…") }
                ForEach(visibleFixtures) { fixture in
                    NavigationLink {
                        FixtureTeamsView(reference: fixture, isSample: source == .samples, client: client) { match, team, players, manuallyEdited in
                            viewModel.importMatchdayTeam(players, fixtureName: match.title, teamName: team, fixtureDate: match.date,
                                providerMatchID: match.id, providerName: source == .samples ? "Highlightly sample" : (manuallyEdited ? "Highlightly + manual review" : "Highlightly"))
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(fixture.title).font(.headline)
                            if let league = fixture.league { Text(league.name).font(.caption).foregroundStyle(.secondary) }
                            Text(displayDate(fixture.date)).font(.caption).foregroundStyle(.secondary)
                            if let state = fixture.state?.description {
                                Text(state + (fixture.state?.score.map { " · \($0)" } ?? "")).font(.caption).foregroundStyle(.secondary)
                            }
                            if source == .samples && fixture.lineups == nil {
                                Text("No provider lineup · manual entry available").font(.caption).foregroundStyle(.orange)
                            }
                        }.padding(.vertical, 3)
                    }
                }
                if hasLoaded && !loading && visibleFixtures.isEmpty {
                    Section { Text(fixtures.isEmpty ? "No fixtures returned for this date. Try another date or use a sample." : "No fixtures match your filters.").foregroundStyle(.secondary) }
                }
                if source == .live && nextOffset < totalCount {
                    Section {
                        Button("Load More Fixtures (\(fixtures.count) of \(totalCount))") { beginLoad(more: true) }.disabled(loading)
                        Text("Competition and search filters apply to fixtures loaded so far.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Fixture").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showConnection = true } label: { Image(systemName: "key") }.accessibilityLabel("Highlightly connection")
                }
            }
            .onAppear { connected = HighlightlyCredentials.load() != nil }
            .onChange(of: source) { _, value in
                loadTask?.cancel(); loading = false; fixtures = []; totalCount = 0; nextOffset = 0; error = nil; search = ""; leagueID = nil; hasLoaded = false
                if value == .samples {
                    do { fixtures = try MatchdayFixture.samples(); hasLoaded = true }
                    catch { self.error = "Sample fixtures could not be loaded. Manual and photo import are still available." }
                }
            }
            .onChange(of: date) { _, _ in
                loadTask?.cancel(); loading = false; fixtures = []; totalCount = 0; nextOffset = 0; error = nil; leagueID = nil; hasLoaded = false
            }
            .onDisappear { loadTask?.cancel(); loading = false }
            .sheet(isPresented: $showConnection, onDismiss: { connected = HighlightlyCredentials.load() != nil; client.clearCache() }) {
                HighlightlyConnectionView()
            }
        }
    }

    private func beginLoad(more: Bool = false) {
        loadTask?.cancel()
        let lookupDate = dateKey
        let offset = more ? nextOffset : 0
        loading = true; error = nil
        loadTask = Task {
            defer { if !Task.isCancelled { loading = false } }
            do {
                guard let key = HighlightlyCredentials.load() else { throw HighlightlyClient.APIError.missingKey }
                let page = try await client.fixtures(date: lookupDate, offset: offset, key: key)
                try Task.checkCancellation()
                if more {
                    var seen = Set(fixtures.map(\.id))
                    fixtures += page.data.filter { seen.insert($0.id).inserted }
                } else { fixtures = page.data }
                nextOffset = offset + page.data.count
                totalCount = page.data.isEmpty ? nextOffset : (page.pagination?.totalCount ?? nextOffset)
                hasLoaded = true
            } catch is CancellationError { }
            catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }

    private func displayDate(_ value: String) -> String {
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return String(value.prefix(10)) }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct FixtureTeamsView: View {
    let reference: MatchdayFixture
    let isSample: Bool
    let client: HighlightlyClient
    let onImport: (MatchdayFixture, String, [ExtractedPlayer], Bool) -> Void
    @State private var details: MatchdayFixture?
    @State private var loading = false
    @State private var error: String?
    @State private var loadedAt: Date?

    var body: some View {
        List {
            Section {
                Text(reference.title).font(.headline)
                if isSample { Text("Historical sample").font(.caption).foregroundStyle(.secondary) }
                else {
                    Button("Refresh Lineups") { Task { await load(refresh: true) } }.disabled(loading)
                    if let loadedAt { Text("Loaded \(loadedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if loading { ProgressView("Loading match details…") }
            if let error { Section { Text(error).foregroundStyle(.orange) } }
            if let fixture = details {
                Section("Choose your team") {
                    teamLink(fixture, home: true)
                    teamLink(fixture, home: false)
                }
                if fixture.lineups == nil {
                    Section { Text("The provider has not supplied a lineup for this match. Choose a team to enter the names manually, or go back and import a photo.").font(.subheadline).foregroundStyle(.secondary) }
                }
            } else if !loading && error != nil {
                Section {
                    Button("Continue with Manual Team Entry") { details = reference }
                }
            }
        }
        .navigationTitle("Choose Team").navigationBarTitleDisplayMode(.inline)
        .task { if isSample { details = reference } else { await load() } }
    }

    private func teamLink(_ fixture: MatchdayFixture, home: Bool) -> some View {
        let name = home ? fixture.homeTeam.name : fixture.awayTeam.name
        let sheet = home ? fixture.lineups?.home : fixture.lineups?.away
        return NavigationLink {
            MatchdayLineupReview(teamName: name, sheet: sheet, isSample: isSample) { players, edited in
                onImport(fixture, name, players, edited)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                Text(sheet == nil ? "No lineup · enter manually" : (sheet!.issues.isEmpty ? "Complete team sheet" : "Incomplete · review missing players"))
                    .font(.caption).foregroundStyle(sheet?.issues.isEmpty == true ? Color.secondary : Color.orange)
            }
        }
    }
    private func load(refresh: Bool = false) async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            guard let key = HighlightlyCredentials.load() else { throw HighlightlyClient.APIError.missingKey }
            let value = try await client.fixture(id: reference.id, key: key, refresh: refresh)
            try Task.checkCancellation()
            details = value; loadedAt = Date()
        } catch is CancellationError { }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

private struct MatchdayLineupReview: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let teamName: String
    let sheet: MatchdayFixture.TeamSheet?
    let isSample: Bool
    let onImport: ([ExtractedPlayer], Bool) -> Void
    @State private var names: [String]
    @State private var confirmImport = false
    private let originalNames: [String]
    init(teamName: String, sheet: MatchdayFixture.TeamSheet?, isSample: Bool, onImport: @escaping ([ExtractedPlayer], Bool) -> Void) {
        self.teamName = teamName; self.sheet = sheet; self.isSample = isSample; self.onImport = onImport
        let values = (1...23).map { number in sheet?.players.first { $0.shirtNumber == number }?.name ?? "" }
        originalNames = values; _names = State(initialValue: values)
    }
    private var missing: Int { names.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    var body: some View {
        Form {
            Section {
                if isSample { Text("Historical sample · review before importing").font(.caption).foregroundStyle(.secondary) }
                Text("Review the matchday 23. You can correct names or fill any gaps before importing.")
                LabeledContent("Named", value: "\(23 - missing) of 23")
                if sheet == nil {
                    Text("No provider lineup is available. Enter the team manually or return to photo import.").foregroundStyle(.orange)
                } else if let sheet, !sheet.issues.isEmpty {
                    ForEach(sheet.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    Text("Check the official team sheet and complete the fields below.").font(.caption).foregroundStyle(.secondary)
                }
                if viewModel.game.isDrawComplete { Text("This game’s team is locked. Start a new game before importing another lineup.").foregroundStyle(.orange) }
            }
            lineupSection("Starting XV", range: 0..<15)
            lineupSection("Replacements", range: 15..<23)
            Section { Text("Import replaces the team and scores in your current setup. Your saved participants remain.").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle(teamName).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Import Team") { confirmImport = true }.disabled(missing > 0 || viewModel.game.isDrawComplete)
            }
        }
        .confirmationDialog("Replace the team in your current setup?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import Reviewed Team") {
                guard missing == 0 && !viewModel.game.isDrawComplete else { return }
                onImport(names.enumerated().map { ExtractedPlayer(number: $0.offset + 1, name: $0.element.trimmingCharacters(in: .whitespacesAndNewlines)) }, sheet == nil || names != originalNames)
            }
        }
    }
    private func lineupSection(_ title: String, range: Range<Int>) -> some View {
        Section(title) {
            ForEach(range, id: \.self) { index in
                HStack {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 30)
                    TextField("Player name", text: $names[index]).autocorrectionDisabled()
                        .accessibilityLabel("Shirt \(index + 1) player name")
                    if names[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).accessibilityLabel("Missing name")
                    }
                }
            }
        }
    }
}

private struct HighlightlyConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var connected = HighlightlyCredentials.load() != nil
    @State private var error: String?
    @State private var confirmRemoval = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(connected ? "A Highlightly key is saved on this device." : "Connect your Highlightly Rugby API account.")
                    SecureField(connected ? "Replacement API key" : "API key", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Save Key") {
                        do { try HighlightlyCredentials.save(key); key = ""; connected = true; dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: { Text("Your key stays in this device’s Keychain. Fixture requests use your Highlightly allowance.") }
                if let error { Text(error).foregroundStyle(.orange) }
                if connected {
                    Button("Remove Saved Key", role: .destructive) { confirmRemoval = true }
                }
            }
            .navigationTitle("Highlightly Connection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { key = ""; dismiss() } } }
            .confirmationDialog("Remove this device’s API key?", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("Remove Key", role: .destructive) {
                    do { try HighlightlyCredentials.remove(); connected = false; key = "" }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}
