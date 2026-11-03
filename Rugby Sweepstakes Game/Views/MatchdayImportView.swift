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
                if fixture.lineups?.home == nil || fixture.lineups?.away == nil {
                    Section("Lineup availability") {
                        Text(isSample ? "This sample does not include a lineup for every team." : "Lineup not currently available from Highlightly for \(fixture.lineups?.home == nil && fixture.lineups?.away == nil ? "either team" : (fixture.lineups?.home == nil ? fixture.homeTeam.name : fixture.awayTeam.name)).")
                            .font(.subheadline)
                        if !isSample {
                            Text("Open your team to refresh the lineup nearer the match. Highlightly may not provide lineups for every match, so availability is not guaranteed.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Choose a team to finalise its lineup using the provider, a team-sheet photo or manual entry.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
            MatchdayLineupReview(teamName: name, sheet: sheet, isSample: isSample, matchID: isSample ? nil : fixture.id, fixtureName: fixture.title, fixtureDate: fixture.date) { players, edited in
                onImport(fixture, name, players, edited)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                Text(sheet == nil ? "Lineup unavailable · enter manually" : (sheet!.issues.isEmpty ? "Complete team sheet" : "Incomplete · review missing players"))
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

/// All lineup sources feed a draft here. The game changes only after Use This Team.
private struct MatchdayLineupReview: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let teamName: String
    let sheet: MatchdayFixture.TeamSheet?
    let isSample: Bool
    let matchID: Int?
    let onImport: ([ExtractedPlayer], Bool) -> Void
    let fixtureName: String?
    let fixtureDate: String?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drafts = TeamDraftStore.shared
    @State private var draftLoaded = false
    @State private var savedAt: Date?
    @State private var draftError: String?
    @State private var finalised = false
    @State private var names: [String]
    @State private var confirmImport = false
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var pendingPhoto: [ExtractedPlayer] = []
    @State private var confirmPhoto = false
    @State private var confirmRefresh = false
    @State private var busy = false
    @State private var message: String?
    @State private var sourceNote: String?
    @State private var squadSlot: SquadSlot?
    @State private var showPhotoSources = false
    @ObservedObject private var photoLibrary = PlayerPhotoLibrary.shared
    private let originalNames: [String]
    private struct SquadSlot: Identifiable { let id: Int }

    init(teamName: String, sheet: MatchdayFixture.TeamSheet?, isSample: Bool, matchID: Int? = nil,
         initialPlayers: [ExtractedPlayer]? = nil, fixtureName: String? = nil, fixtureDate: String? = nil, onImport: @escaping ([ExtractedPlayer], Bool) -> Void) {
        self.fixtureName = fixtureName; self.fixtureDate = fixtureDate
        self.teamName = teamName; self.sheet = sheet; self.isSample = isSample; self.matchID = matchID; self.onImport = onImport
        let values = (1...23).map { number in
            initialPlayers?.first { $0.number == number }?.name ?? sheet?.players.first { $0.shirtNumber == number }?.name ?? ""
        }
        originalNames = values; _names = State(initialValue: values)
    }
    private var missing: Int { names.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var locked: Bool { viewModel.game.isDrawComplete }
    private var isEngland: Bool { teamName.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("England") == .orderedSame }

    var body: some View {
        Form {
            Section("Finalise your team") {
                if isSample { Text("Historical sample").font(.caption).foregroundStyle(.secondary) }
                Text("Enter names below, import a team-sheet photo or load the available lineup. Check the shirt numbers before using this team.")
                if let savedAt {
                    Label("Draft saved \(savedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Your edits are saved automatically on this device. Resume this draft from Match & Team.")
                    .font(.caption).foregroundStyle(.secondary)
                if let draftError { Text(draftError).foregroundStyle(.orange) }
                LabeledContent("Named", value: "\(23 - missing) of 23")
                if missing > 0 { Text("\(missing) more \(missing == 1 ? "name is" : "names are") needed to use this team.").font(.caption).foregroundStyle(.secondary) }
                if sheet == nil && matchID != nil && sourceNote == nil {
                    Text("Lineup not currently available from Highlightly for this team. Try refreshing, import a photo or enter the names below.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if locked { Text("Your team is locked after the draw. Start a new game to change the lineup.").foregroundStyle(.orange) }
                if let sourceNote { Text(sourceNote).font(.caption).foregroundStyle(.secondary) }
                if let message { Text(message).font(.subheadline).foregroundStyle(.orange) }
            }
            Section("Import options") {
                Button { selectedImage = nil; showPhotoPicker = true } label: {
                    Label("Import Team-Sheet Photo", systemImage: "photo.on.rectangle")
                }
                if matchID != nil {
                    Button { confirmRefresh = true } label: {
                        Label("Refresh Highlightly Lineup", systemImage: "arrow.clockwise")
                    }
                    Text("Lineups may not be available for every match. If supplied, the selected team’s lineup will replace this draft after confirmation.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let sheet {
                    Button("Restore Original Lineup") { confirmRefresh = true }
                        .disabled(sheet.players.isEmpty)
                }
                Button { showPhotoSources = true } label: {
                    Label("Photo Pages & Squads", systemImage: "person.crop.rectangle.stack")
                }
                Text("Load a saved squad to choose players by name and photo, or add another team’s photo page.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Imports update this draft. Nothing is saved to your game until you choose Use This Team.")
                    .font(.caption).foregroundStyle(.secondary)
                if busy { ProgressView("Loading players…") }
            }.disabled(locked || busy)
            Group {
                lineupSection("Starting XV", range: 0..<15)
                lineupSection("Replacements", range: 15..<23)
            }.disabled(locked || busy)
        }
        .navigationTitle(teamName).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button("Save Draft & Close") { if saveDraft() { dismiss() } }
                    .disabled(locked || busy)
                Button("Use This Team") { confirmImport = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(missing > 0 || locked || busy)
                Text(missing > 0 ? "Complete all 15 starters and 8 replacements." : "All 23 names ready — check the lineup before saving.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
        }
        .confirmationDialog("Use this team for your sweepstake?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Use This Team") {
                guard missing == 0 && !locked else { return }
                finalised = true
                if let draft = matchingDraft { try? drafts.remove(id: draft.id) }
                onImport(names.enumerated().map { ExtractedPlayer(number: $0.offset + 1, name: $0.element.trimmingCharacters(in: .whitespacesAndNewlines)) }, sheet == nil || names != originalNames)
            }
        } message: { Text("This replaces the team in your current setup. Your participants remain selected.") }
        .confirmationDialog("Replace the draft with the available lineup?", isPresented: $confirmRefresh, titleVisibility: .visible) {
            Button("Load Lineup") { Task { await refreshLineup() } }
        } message: { Text("Any names you have entered will be replaced only if a lineup is available.") }
        .confirmationDialog("Apply names from this photo?", isPresented: $confirmPhoto, titleVisibility: .visible) {
            Button("Apply Photo Names") {
                guard !locked else { return }
                for player in pendingPhoto {
                    if let number = player.number { names[number - 1] = player.name }
                }
                sourceNote = "Photo names applied. Check every name and shirt number before using this team."
                pendingPhoto = []
            }
            Button("Cancel", role: .cancel) { pendingPhoto = [] }
        } message: { Text("\(pendingPhoto.count) numbered names found. Matching shirts will be replaced; other names stay as entered.") }
        .sheet(isPresented: $showPhotoPicker, onDismiss: {
            if let image = selectedImage { selectedImage = nil; Task { await readPhoto(image) } }
        }) {
            PhotoPickerView(selectedImage: $selectedImage) { showPhotoPicker = false }
        }
        .sheet(item: $squadSlot) { slot in
            EnglandPlayerPickerView(players: availableSquad(for: slot.id), currentPlayer: squadPlayers.first { EnglandPlayerNameMatcher.key($0.name) == EnglandPlayerNameMatcher.key(names[slot.id]) }, onSelect: { player in
                if !locked { names[slot.id] = player?.name ?? "" }
                squadSlot = nil
            }, teamName: teamName)
        }
        .sheet(isPresented: $showPhotoSources) { PhotoSourcesView() }
        .onAppear {
            guard !draftLoaded else { return }
            if !locked, let draft = matchingDraft {
                names = draft.names; sourceNote = draft.sourceNote; savedAt = draft.updatedAt
            }
            draftLoaded = true
        }
        .onChange(of: names) { _, _ in if draftLoaded { saveDraft() } }
        .onChange(of: sourceNote) { _, _ in if draftLoaded { saveDraft() } }
    }

    private var matchingDraft: TeamLineupDraft? {
        drafts.find(gameID: viewModel.game.id, matchID: matchID, fixtureName: fixtureName, fixtureDate: fixtureDate, teamName: teamName, isSample: isSample)
    }
    @discardableResult private func saveDraft() -> Bool {
        guard !locked && !finalised else { return false }
        do {
            let saved = try drafts.save(gameID: viewModel.game.id, matchID: matchID, fixtureName: fixtureName, fixtureDate: fixtureDate,
                teamName: teamName, isSample: isSample, names: names, sourceNote: sourceNote)
            savedAt = saved.updatedAt; draftError = nil
            return true
        } catch { draftError = error.localizedDescription; return false }
    }

    private var squadPlayers: [EnglandSquadPlayer] {
        let imported = photoLibrary.players(for: teamName)
        return imported.isEmpty && isEngland ? viewModel.englandSquad : imported
    }

    private func lineupSection(_ title: String, range: Range<Int>) -> some View {
        Section(title) {
            ForEach(range, id: \.self) { index in
                HStack {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 30)
                    if !names[index].isEmpty {
                        PlayerPortrait(name: names[index], remoteURL: isEngland ? viewModel.englandSquadPlayer(named: names[index])?.photoURL : nil, teamName: teamName)
                            .frame(width: 32, height: 32)
                    }
                    TextField("Player name", text: $names[index]).autocorrectionDisabled()
                        .accessibilityLabel("Shirt \(index + 1) player name")
                    if !squadPlayers.isEmpty {
                        Button { squadSlot = SquadSlot(id: index) } label: { Image(systemName: "person.crop.circle.badge.plus") }
                            .buttonStyle(.borderless).accessibilityLabel("Choose squad player for shirt \(index + 1)")
                    }
                    if names[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).accessibilityLabel("Missing name")
                    }
                }
            }
        }
    }
    private func availableSquad(for slot: Int) -> [EnglandSquadPlayer] {
        let used = Set(names.enumerated().filter { $0.offset != slot }.map { EnglandPlayerNameMatcher.key($0.element) })
        return squadPlayers.filter { !used.contains(EnglandPlayerNameMatcher.key($0.name)) }
    }
    private func refreshLineup() async {
        guard !busy && !locked else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            let replacement: MatchdayFixture.TeamSheet?
            if let matchID {
                guard let key = HighlightlyCredentials.load() else { throw HighlightlyClient.APIError.missingKey }
                let fixture = try await HighlightlyClient().fixture(id: matchID, key: key, refresh: true)
                replacement = fixture.homeTeam.name == teamName ? fixture.lineups?.home : (fixture.awayTeam.name == teamName ? fixture.lineups?.away : nil)
            } else { replacement = sheet }
            guard let replacement, !replacement.players.isEmpty else {
                message = "Lineup not currently available from Highlightly for this team. Your draft has been kept."
                return
            }
            guard !locked else { return }
            names = (1...23).map { number in replacement.players.first { $0.shirtNumber == number }?.name ?? "" }
            sourceNote = "Lineup loaded. Review all 23 names before using this team."
        } catch { message = error.localizedDescription }
    }
    private func readPhoto(_ image: UIImage) async {
        guard !busy && !locked else { return }
        busy = true; message = nil
        let players = await TeamPhotoImporter.extractPlayers(from: image)
        busy = false
        guard !locked else { return }
        let numbered = players.filter { player in
            guard let number = player.number else { return false }
            return (1...23).contains(number) && !player.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !numbered.isEmpty else {
            message = "No numbered players could be read. Try a clearer photo showing shirt numbers 1–23, or enter the names manually. Your draft has been kept."
            return
        }
        guard Set(numbered.compactMap(\.number)).count == numbered.count else {
            message = "The photo contains repeated shirt numbers. Use a photo of just the selected team, or enter the names manually. Your draft has been kept."
            return
        }
        pendingPhoto = numbered; confirmPhoto = true
    }
}

/// Manual setup and reopening an existing draft use the same finalisation screen.
struct CurrentTeamReviewView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            MatchdayLineupReview(teamName: viewModel.game.selectedTeamName ?? "Your Team", sheet: nil, isSample: false,
                matchID: viewModel.game.providerMatchID,
                initialPlayers: viewModel.game.teamMembers.enumerated().map { ExtractedPlayer(number: $0.offset + 1, name: $0.element.name) },
                fixtureName: viewModel.game.fixtureName, fixtureDate: viewModel.game.fixtureDate) { players, _ in
                let game = viewModel.game
                viewModel.importMatchdayTeam(players, fixtureName: game.fixtureName, teamName: game.selectedTeamName,
                    fixtureDate: game.fixtureDate, providerMatchID: game.providerMatchID, providerName: "Reviewed team")
                dismiss()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct SavedTeamDraftReviewView: View {
    let draft: TeamLineupDraft
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            MatchdayLineupReview(teamName: draft.teamName, sheet: nil, isSample: draft.isSample, matchID: draft.matchID,
                initialPlayers: draft.names.enumerated().map { ExtractedPlayer(number: $0.offset + 1, name: $0.element) },
                fixtureName: draft.fixtureName, fixtureDate: draft.fixtureDate) { players, _ in
                viewModel.importMatchdayTeam(players, fixtureName: draft.fixtureName, teamName: draft.teamName,
                    fixtureDate: draft.fixtureDate, providerMatchID: draft.matchID, providerName: "Reviewed team")
                dismiss()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
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
