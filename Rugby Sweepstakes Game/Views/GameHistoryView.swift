import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let onResume: () -> Void
    @State private var search = ""
    private var games: [Game] {
        viewModel.savedGames.filter {
            search.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(search) || ($0.selectedTeamName ?? "").localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if viewModel.savedGames.isEmpty {
                    ContentUnavailableView("No Saved Games Yet", systemImage: "clock", description: Text("Finish a game or start a new one to save the current game here."))
                } else if games.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                ForEach(games) { game in
                    NavigationLink {
                        GameResultsView(game: game, onResume: onResume)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.displayTitle).font(.headline)
                            if let team = game.selectedTeamName { Text("Following \(team)").font(.subheadline) }
                            Text(game.isCompleted ? "Completed" : (game.isDrawComplete ? "Saved in progress" : "Setup saved"))
                                .font(.caption.weight(.semibold)).foregroundStyle(game.isCompleted ? Color.green : Color.secondary)
                            if let date = game.completedAt ?? game.savedToHistoryAt {
                                Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            if game.isCompleted && !game.winningParticipants.isEmpty {
                                Text("\(game.winningParticipants.count == 1 ? "Winner" : "Joint winners"): \(game.winningParticipants.map(\.name).joined(separator: ", "))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Find match or team")
        }
    }
}

struct GameResultsView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    let game: Game
    var onResume: (() -> Void)? = nil
    @State private var showReopen = false
    @State private var showShare = false
    @State private var expanded: Set<UUID> = []

    var body: some View {
        List {
            Section {
                Text(game.displayTitle).font(.headline)
                if let team = game.selectedTeamName { Text("Following \(team)") }
                if let date = game.completedAt {
                    Label("Completed \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.secondary)
                } else { Text("Saved in progress · read-only preview").font(.caption).foregroundStyle(.secondary) }
            }
            if game.isCompleted, let winner = game.winningParticipants.first {
                Section {
                    Label(game.winningParticipants.count == 1 ? "Winner" : "Joint Winners", systemImage: "trophy.fill").font(.headline).foregroundStyle(.orange)
                    Text(game.winningParticipants.map(\.name).joined(separator: ", ")).font(.title2.bold())
                    Text("\(game.pointsForParticipant(winner.id)) points\(game.winningParticipants.count > 1 ? " each" : "")")
                }
            }
            if game.isCompleted {
                Section {
                    Button { showShare = true } label: { Label("Share Final Results Image", systemImage: "photo.on.rectangle") }
                    Text("Send the winners and full standings on WhatsApp or another app.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if game.isDrawComplete {
            Section(game.isCompleted ? "Final standings" : "Current standings") {
                ForEach(game.rankedParticipants) { person in
                    DisclosureGroup(isExpanded: Binding(get: { expanded.contains(person.id) }, set: { if $0 { expanded.insert(person.id) } else { expanded.remove(person.id) } })) {
                        ForEach(person.assignedTeamMemberIds, id: \.self) { id in
                            if let player = game.teamMembers.first(where: { $0.id == id }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack { Text(player.name); Spacer(); Text("\(game.pointsForBundle(id)) pts") }
                                    if let replacement = game.teamMembers.first(where: { $0.id == player.linkedSubstituteId }) {
                                        Text("\(replacement.name) on").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.font(.subheadline)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(game.participantRank(person.id))").monospacedDigit().frame(width: 22)
                            Circle().fill(person.color.color).frame(width: 12, height: 12)
                            Text(person.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(game.pointsForParticipant(person.id)) pts").bold().foregroundStyle(.primary)
                        }.padding(.vertical, 5)
                    }
                }
            }
            } else {
                Section("Setup progress") {
                    LabeledContent("Starters named", value: "\(game.namedStarters.count) of 15")
                    LabeledContent("Participants selected", value: "\(game.sweepstakePlayers.count)")
                }
            }
            if !(game.scoringHistory ?? []).isEmpty {
                Section("Scoring record") {
                    ForEach((game.scoringHistory ?? []).reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.event.description) · \(game.teamMembers.first { $0.id == entry.teamMemberID }?.name ?? "Player") · \(entry.points > 0 ? "+" : "")\(entry.points) pts")
                            Text("\(entry.recordedAt.formatted(date: .omitted, time: .shortened))\(entry.undoneAt != nil ? " · Undone" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }.strikethrough(entry.undoneAt != nil)
                    }
                }
            }
            Section {
                Button(game.isCompleted ? "Reopen for Corrections" : "Resume This Game") { showReopen = true }
                Text("The current game is saved to History before switching. Completed results stay read-only until reopened.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(game.isCompleted ? "Final Results" : "Saved Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { Button { showShare = true } label: { Label("Share Results", systemImage: "square.and.arrow.up") } }
        .sheet(isPresented: $showShare) {
            if game.isCompleted { ResultsShareView(game: game) }
            else { ShareSheet(activityItems: [game.resultsShareText]) }
        }
        .confirmationDialog(game.isCompleted ? "Reopen this game?" : "Resume this game?", isPresented: $showReopen, titleVisibility: .visible) {
            Button(game.isCompleted ? "Reopen for Corrections" : "Resume Game") {
                if viewModel.reopenGame(game.id) { dismiss(); onResume?() }
            }
        } message: {
            Text("Any other current game will be saved to History. Finish this game again after corrections to save updated final results.")
        }
    }
}
