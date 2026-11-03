import SwiftUI

enum MatchDaySection: String, CaseIterable, Identifiable {
    case score = "Score", leaderboard = "Leaderboard", allocations = "Allocations"
    var id: String { rawValue }
}

struct MatchDayView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var section: MatchDaySection
    @State private var filter = FieldFilter.onField
    @State private var search = ""
    @State private var selectedPlayer: TeamMember?
    @State private var showSubstitution = false
    @State private var showHistory = false
    @State private var showShare = false
    @State private var showFinish = false
    @State private var expandedParticipants: Set<UUID> = []

    init(initialSection: MatchDaySection = .score) { _section = State(initialValue: initialSection) }
    private enum FieldFilter: String, CaseIterable, Identifiable {
        case onField = "On field", bench = "Off field", all = "All"
        var id: String { rawValue }
    }
    private var players: [TeamMember] {
        viewModel.game.teamMembers.filter { member in
            let matchesFilter = filter == .all || (filter == .onField ? viewModel.isOnField(member) : !viewModel.isOnField(member))
            let matchesSearch = search.isEmpty || member.name.localizedCaseInsensitiveContains(search) || String(shirtNumber(member)).contains(search)
            return !member.name.isEmpty && matchesFilter && matchesSearch
        }
    }
    private func shirtNumber(_ member: TeamMember) -> Int {
        (viewModel.game.teamMembers.firstIndex { $0.id == member.id } ?? 0) + 1
    }
    private var visibleParticipants: [SweepstakePlayer] {
        viewModel.getSortedSweepstakePlayers().filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var shareText: String {
        if viewModel.game.isCompleted && section != .allocations { return viewModel.game.resultsShareText }
        var lines = ["Rugby Sweepstakes — Current \(section.rawValue)"]
        lines.append(viewModel.game.displayTitle)
        if let team = viewModel.game.selectedTeamName { lines.append("Following \(team)") }
        for participant in viewModel.getSortedSweepstakePlayers() {
            lines.append("\(viewModel.rank(for: participant.id)). \(participant.name): \(viewModel.getTotalPoints(for: participant.id)) pts")
            if section == .allocations {
                for id in participant.assignedTeamMemberIds {
                    guard let member = viewModel.getTeamMember(by: id) else { continue }
                    let replacement = viewModel.getLinkedSubstitute(for: id).map { " · \($0.name) on" } ?? ""
                    lines.append("  \(member.name)\(replacement)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        List {
            if !viewModel.game.isDrawComplete {
                ContentUnavailableView("Run the Draw First", systemImage: "shuffle", description: Text("Complete setup to open Match Day."))
            } else {
                LiveMatchScoreView(matchID: viewModel.game.providerMatchID, providerName: viewModel.game.providerName)
                if viewModel.game.isCompleted {
                    Section {
                        NavigationLink { GameResultsView(game: viewModel.game) } label: {
                            Label("Completed — View Final Results", systemImage: "checkmark.seal.fill")
                        }
                        Text("Read-only. Open final results to reopen this game for corrections.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if section == .score { scoreList }
                else if section == .leaderboard { leaderboard }
                else { allocations }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: section == .score ? "Find rugby player or shirt number" : "Find participant")
        .navigationTitle(viewModel.game.isCompleted ? "Results" : "Match Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.game.displayTitle).font(.subheadline.weight(.semibold))
                Text("\(viewModel.game.selectedTeamName ?? "Your team") · \(viewModel.game.isCompleted ? "Completed" : "Manual scoring")")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Match Day section", selection: $section) {
                    ForEach(MatchDaySection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal).padding(.vertical, 10).background(.regularMaterial)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("Scoring history")
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share \(section.rawValue)")
                if !viewModel.game.isCompleted && viewModel.game.isDrawComplete {
                    Menu {
                        Button { showFinish = true } label: { Label("Finish & Save Game", systemImage: "checkmark.seal") }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Game actions")
                }
            }
        }
        .confirmationDialog("Finish and save this game?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Finish & Save Results") {
                if viewModel.finishGame() { section = .leaderboard }
            }
        } message: { Text("Final results will be saved to History. Scoring will be locked until you reopen the game for corrections.") }
        .onAppear { if viewModel.game.isCompleted { section = .leaderboard } }
        .onChange(of: section) { _, _ in search = "" }
        .sheet(item: $selectedPlayer) { member in
            RecordScoreSheet(memberID: member.id).environmentObject(viewModel)
        }
        .sheet(isPresented: $showSubstitution) { MatchSubstitutionSheet().environmentObject(viewModel) }
        .sheet(isPresented: $showHistory) { MatchActivityView().environmentObject(viewModel) }
        .sheet(isPresented: $showShare) {
            if section == .allocations { DrawShareView(game: viewModel.game, englandSquad: viewModel.englandSquad) }
            else if viewModel.game.isCompleted { ResultsShareView(game: viewModel.game) }
            else { ShareSheet(activityItems: [shareText]) }
        }
    }

    @ViewBuilder private var scoreList: some View {
        Section {
            HStack {
                Button { showSubstitution = true } label: { Label("Make Substitution", systemImage: "arrow.left.arrow.right") }
                    .disabled(viewModel.game.isCompleted)
                Spacer()
                Text("\(viewModel.game.teamMembers.reduce(0) { $0 + $1.points }) pts recorded")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Players shown", selection: $filter) {
                ForEach(FieldFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        if let entry = viewModel.activeScoringHistory.last {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.event.description) · \(viewModel.getTeamMember(by: entry.teamMemberID)?.name ?? "Player")").font(.subheadline)
                        Text("\(entry.points > 0 ? "+" : "")\(entry.points) pts · \(entry.recordedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Undo") { viewModel.undoLastScoringAction() }.disabled(viewModel.game.isCompleted)
                }
            }
        }
        Section {
            ForEach(players) { member in
                Button { selectedPlayer = member } label: {
                    HStack(spacing: 12) {
                        Text("\(shirtNumber(member))").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24)
                        portrait(member)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                            if let participant = viewModel.participant(forBundle: viewModel.scoringBundle(for: member.id)) {
                                HStack(spacing: 5) {
                                    Circle().fill(participant.color.color).frame(width: 7, height: 7)
                                    Text(participant.name)
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(member.isSubstitute && !viewModel.isOnField(member) ? "Bench · make substitution to score" : "Excluded from sweepstake")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Text("\(member.points)").font(.headline.monospacedDigit()).foregroundStyle(.primary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if players.isEmpty { Text("No players match this filter.").foregroundStyle(.secondary) }
        } header: { Text("Tap a rugby player to record points") }
    }

    @ViewBuilder private var leaderboard: some View {
        Section {
            Text(viewModel.game.isCompleted ? "Final standings · equal scores share a rank." : "Current standings · leaders are confirmed when the game finishes.")
                .font(.caption).foregroundStyle(.secondary)
        }
        ForEach(visibleParticipants) { participant in
            Section {
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedParticipants.contains(participant.id) },
                    set: { if $0 { expandedParticipants.insert(participant.id) } else { expandedParticipants.remove(participant.id) } }
                )) {
                    ForEach(participant.assignedTeamMemberIds, id: \.self) { id in
                        if let member = viewModel.getTeamMember(by: id) {
                            HStack {
                                Text(member.name)
                                Spacer()
                                Text("\(viewModel.getTotalPointsForTeamMember(id)) pts").monospacedDigit()
                            }.font(.subheadline)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("\(viewModel.rank(for: participant.id))").font(.headline).frame(width: 24)
                        Circle().fill(participant.color.color).frame(width: 14, height: 14)
                        Text(participant.name).foregroundStyle(.primary)
                        Spacer()
                        Text("\(viewModel.getTotalPoints(for: participant.id)) pts").font(.headline.monospacedDigit()).foregroundStyle(.primary)
                    }
                    .padding(.vertical, 7)
                }
            }
        }
        if visibleParticipants.isEmpty { Text("No participants match your search.").foregroundStyle(.secondary) }
    }

    @ViewBuilder private var allocations: some View {
        Section {
            Button { showShare = true } label: {
                Label("Share Draw with Player Photos", systemImage: "photo.on.rectangle")
            }
            Text("Create an image of the full draw to send on WhatsApp or another app.")
                .font(.caption).foregroundStyle(.secondary)
        }
        ForEach(visibleParticipants) { participant in
            Section {
                ForEach(participant.assignedTeamMemberIds, id: \.self) { id in
                    if let member = viewModel.getTeamMember(by: id) {
                        HStack(spacing: 12) {
                            portrait(member)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.name)
                                if let replacement = viewModel.getLinkedSubstitute(for: id) {
                                    Text("\(replacement.name) on").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(viewModel.getTotalPointsForTeamMember(id)) pts").font(.subheadline.monospacedDigit())
                        }.padding(.vertical, 3)
                    }
                }
            } header: {
                HStack { Circle().fill(participant.color.color).frame(width: 8, height: 8); Text(participant.name) }
            }
        }
        if visibleParticipants.isEmpty { Text("No participants match your search.").foregroundStyle(.secondary) }
    }

    private func portrait(_ member: TeamMember) -> some View {
        PlayerPortrait(name: member.name, remoteURL: viewModel.englandSquadPlayer(named: member.name)?.photoURL ?? PlayerPhotoCatalogue.url(named: member.name), teamName: viewModel.game.selectedTeamName)
            .frame(width: 40, height: 40).clipShape(Circle()).accessibilityHidden(true)
    }
}

private struct RecordScoreSheet: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    let memberID: UUID
    private var member: TeamMember? { viewModel.getTeamMember(by: memberID) }
    private var canScore: Bool { !viewModel.game.isCompleted && (member?.isStarter == true || viewModel.scoringBundle(for: memberID) != nil) }
    var body: some View {
        NavigationStack {
            Form {
                if let member {
                    Section {
                        TeamMemberProfileView(member: member, imageSize: 56)
                        if let participant = viewModel.participant(forBundle: viewModel.scoringBundle(for: memberID)) {
                            Text("Points go to \(participant.name)").font(.subheadline)
                        } else {
                            Text(viewModel.game.isCompleted ? "This game is complete and read-only." : (canScore ? "This rugby player is excluded from the sweepstake. Their scores do not award participant points." : "Make a substitution before recording points for this replacement."))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if !viewModel.isOnField(member) && member.isStarter {
                            Text("Off field: use this player only to record or correct an earlier score.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("Record a score") {
                        ForEach(ScoringEvent.allCases) { event in
                            Button {
                                viewModel.adjustScoringEvent(event, for: memberID, by: 1)
                                dismiss()
                            } label: {
                                HStack { Text(event.description); Spacer(); Text("+\(event.points) pts").bold() }.padding(.vertical, 10)
                            }
                            .disabled(!canScore)
                            .accessibilityLabel("Record \(event.description) for \(member.name)")
                        }
                    }
                    Section("Recorded for this player") {
                        LabeledContent("Tries", value: "\(member.tryCount)")
                        LabeledContent("Penalties", value: "\(member.penaltyCount)")
                        LabeledContent("Conversions", value: "\(member.conversionCount)")
                        LabeledContent("Drop goals", value: "\(member.dropGoalCount)")
                        Text("Open scoring history to undo a specific recorded score.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Record Score").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct MatchSubstitutionSheet: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var outgoingID: UUID?
    @State private var replacementID: UUID?
    private var onField: [TeamMember] { viewModel.game.teamMembers.filter { viewModel.isOnField($0) && !$0.name.isEmpty } }
    private var bench: [TeamMember] { viewModel.game.substitutes.filter { !viewModel.isOnField($0) && !$0.name.isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Player coming off") {
                    Picker("Player", selection: $outgoingID) {
                        Text("Choose player").tag(nil as UUID?)
                        ForEach(onField) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section("Replacement coming on") {
                    Picker("Replacement", selection: $replacementID) {
                        Text("Choose replacement").tag(nil as UUID?)
                        ForEach(bench) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if let outgoingID, let participant = viewModel.participant(forBundle: viewModel.scoringBundle(for: outgoingID)) {
                        Text("New scores from the replacement go to \(participant.name). Earlier points keep their original allocation.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Confirm Substitution") {
                        guard let outgoingID, let replacementID else { return }
                        viewModel.makeSubstitution(outgoingID: outgoingID, incomingID: replacementID)
                        dismiss()
                    }.disabled(outgoingID == nil || replacementID == nil)
                }
                if !viewModel.game.starters.filter({ $0.linkedSubstituteId != nil }).isEmpty {
                    Section {
                        ForEach(viewModel.game.starters.filter { $0.linkedSubstituteId != nil }) { starter in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(viewModel.getLinkedSubstitute(for: starter.id)?.name ?? "Replacement") for \(starter.name)")
                                Button("Return \(starter.name)") { viewModel.unlinkSubstitute(from: starter.id) }
                            }.padding(.vertical, 5)
                        }
                    } header: { Text("Current replacements") } footer: { Text("Select any player currently on field, including a replacement. Returning an original starter keeps all earlier points with their original allocation.") }
                }
            }
            .navigationTitle("Substitution").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct MatchActivityView: View {
    @State private var correctionID: UUID?
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Undo Latest Score") { viewModel.undoLastScoringAction() }
                        .disabled(viewModel.game.isCompleted || viewModel.activeScoringHistory.isEmpty)
                    Text("Undo the latest score, or choose an individual entry below. Corrections are saved and remain visible in the record.")
                        .font(.caption).foregroundStyle(.secondary)
                    if (viewModel.game.scoringBaseline ?? []).contains(where: { $0.points != 0 }) || (viewModel.game.scoringBaseline == nil && viewModel.game.teamMembers.contains(where: { $0.points != 0 })) {
                        Text("Earlier scores are retained. Detailed history starts with scores recorded in this version.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Scoring entries") {
                    ForEach((viewModel.game.scoringHistory ?? []).reversed()) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("\(entry.event.description) · \(viewModel.getTeamMember(by: entry.teamMemberID)?.name ?? "Player")")
                                Spacer()
                                Text("\(entry.points > 0 ? "+" : "")\(entry.points)").monospacedDigit()
                            }
                            if let ownerID = entry.participantID, let owner = viewModel.game.sweepstakePlayers.first(where: { $0.id == ownerID }) {
                                Text("Awarded to \(owner.name)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))\(entry.undoneAt == nil ? "" : " · Undone")")
                                .font(.caption).foregroundStyle(.secondary)
                            if viewModel.canUndoScoringEntry(entry.id) {
                                Button(entry.points < 0 ? "Undo This Correction" : "Undo This Score") { correctionID = entry.id }
                                    .font(.caption).accessibilityLabel("Undo \(entry.event.description) for \(viewModel.getTeamMember(by: entry.teamMemberID)?.name ?? "player")")
                            }
                        }
                        .strikethrough(entry.undoneAt != nil)
                        .opacity(entry.undoneAt == nil ? 1 : 0.55)
                        .padding(.vertical, 3)
                    }
                    if (viewModel.game.scoringHistory ?? []).isEmpty { Text("No new scores recorded yet.").foregroundStyle(.secondary) }
                }
                Section("Substitutions") {
                    ForEach((viewModel.game.substitutionHistory ?? []).reversed()) { entry in
                        let starter = viewModel.getTeamMember(by: entry.starterID)?.name ?? "Starter"
                        let replacement = viewModel.getTeamMember(by: entry.replacementID)?.name ?? "Replacement"
                        let outgoing = viewModel.getTeamMember(by: entry.outgoingPlayerID ?? entry.starterID)?.name ?? starter
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.isReturn ? "\(starter) returned · \(replacement) off" : "\(replacement) on · \(outgoing) off")
                            Text(entry.recordedAt.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if (viewModel.game.substitutionHistory ?? []).isEmpty { Text("No new substitutions recorded yet.").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Scoring History").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Undo this recorded score?", isPresented: Binding(get: { correctionID != nil }, set: { if !$0 { correctionID = nil } }), titleVisibility: .visible) {
                Button("Undo Selected Score", role: .destructive) {
                    if let id = correctionID { viewModel.undoScoringEntry(id) }
                    correctionID = nil
                }
            } message: { Text("The selected entry will be reversed for its original participant. Other scores and substitutions stay unchanged.") }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
