import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var setupRequest: SetupRequest?
    private struct SetupRequest: Identifiable { let id = UUID(); let step: Int }
    @State private var showResetConfirmation = false
    @State private var showBackup = false
    @ObservedObject private var drafts = TeamDraftStore.shared
    @State private var selectedDraft: TeamLineupDraft?
    @State private var showDrafts = false
    private var currentDrafts: [TeamLineupDraft] {
        viewModel.game.isDrawComplete ? [] : drafts.drafts(for: viewModel.game.id)
    }

    private var nextStep: Int {
        if !viewModel.game.isTeamSetupComplete { return 0 }
        if viewModel.game.sweepstakePlayers.count < 2 { return 1 }
        return 2
    }
    private var hasScores: Bool {
        viewModel.game.teamMembers.contains { $0.points > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.game.displayTitle).font(.largeTitle.bold())
                            Text(viewModel.game.isCompleted ? "Game Completed" : (viewModel.game.isDrawComplete ? "Match Day" : "Set Up Your Game")).font(.title3.weight(.semibold))
                            if let team = viewModel.game.selectedTeamName, !team.isEmpty {
                                Text("Following \(team)").font(.subheadline)
                            }
                        }
                        .foregroundStyle(.white)
                        if let draft = currentDrafts.first {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Unfinished Team", systemImage: "doc.text").font(.headline)
                                    Text(draft.fixtureName ?? draft.teamName).font(.subheadline.weight(.semibold))
                                    Text("\(draft.teamName) · \(draft.namedCount) of 23 named").font(.subheadline).foregroundStyle(.secondary)
                                    Button { selectedDraft = draft } label: {
                                        Label("Resume Draft", systemImage: "pencil").frame(maxWidth: .infinity)
                                    }.buttonStyle(.borderedProminent).controlSize(.large)
                                }
                            }
                        }
                        if viewModel.game.isCompleted { completedGame }
                        else if viewModel.game.isDrawComplete { matchDay }
                        else { setup }
                        Button { showResetConfirmation = true } label: {
                            Label("Start a New Game", systemImage: "plus.circle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        if !drafts.drafts.isEmpty {
                            Button { showDrafts = true } label: {
                                Label("Manage Team Drafts (\(drafts.drafts.count))", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).tint(.white)
                        }
                        Button { showBackup = true } label: {
                            Label("Backup & Restore", systemImage: "externaldrive").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(.white)
                        Text("Your current game is saved to History before a new one starts.")
                            .font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding()
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedDraft) { draft in SavedTeamDraftReviewView(draft: draft).environmentObject(viewModel) }
            .sheet(isPresented: $showDrafts) { DraftManagementView().environmentObject(viewModel) }
            .sheet(isPresented: $showBackup) { BackupRestoreView().environmentObject(viewModel) }
            .sheet(item: $setupRequest) { request in GameSetupView(initialStep: request.step).environmentObject(viewModel) }
            .alert("Start a New Game?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Save & Start New Game") {
                    if viewModel.resetGame() {
                        setupRequest = SetupRequest(step: 0)
                    }
                }
            } message: {
                Text("Your current team, draw and scores will be saved to History. Your saved people and photos remain available.")
            }
        }
    }

    @ViewBuilder private var setup: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Three steps to your draw").font(.headline)
                setupRow(0, "Match & Team", "\(viewModel.game.namedStarters.count) of 15 starters named", complete: viewModel.game.isTeamSetupComplete)
                Divider()
                setupRow(1, "Participants", "\(viewModel.game.sweepstakePlayers.count) selected", complete: viewModel.game.sweepstakePlayers.count >= 2)
                Divider()
                setupRow(2, "Review & Draw", viewModel.game.canRunDraw ? "Ready to draw" : "Check allocations and exclusions", complete: false)
                Button {
                    setupRequest = SetupRequest(step: nextStep)
                } label: {
                    Label(nextStep == 2 ? "Review & Run Draw" : "Continue Setup", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
    }

    private func setupRow(_ index: Int, _ title: String, _ detail: String, complete: Bool) -> some View {
        Button { setupRequest = SetupRequest(step: index) } label: {
            HStack(spacing: 12) {
                Image(systemName: complete ? "checkmark.circle.fill" : "\(index + 1).circle")
                    .foregroundStyle(complete ? .green : Color.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var completedGame: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Final Results Saved", systemImage: "checkmark.seal.fill").font(.headline)
                if let winner = viewModel.game.winningParticipants.first {
                    Text("\(viewModel.game.winningParticipants.count == 1 ? "Winner" : "Joint winners"): \(viewModel.game.winningParticipants.map(\.name).joined(separator: ", "))")
                        .font(.title3.bold())
                    Text("\(viewModel.game.pointsForParticipant(winner.id)) points\(viewModel.game.winningParticipants.count > 1 ? " each" : "")")
                }
                NavigationLink { GameResultsView(game: viewModel.game) } label: {
                    Label("View & Share Final Results", systemImage: "trophy.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                Text("Open results to review allocations or reopen this game for corrections.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var matchDay: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(hasScores ? "Game in progress" : "Draw complete — ready to score", systemImage: "sportscourt.fill")
                    .font(.headline)
                Text("\(viewModel.game.sweepstakePlayers.count) participants · \(viewModel.game.enabledStarters.count) rugby players allocated")
                    .font(.subheadline).foregroundStyle(.secondary)
                NavigationLink { MatchDayView(initialSection: .score) } label: {
                    Label(hasScores ? "Continue Scoring" : "Start Scoring", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                NavigationLink { MatchDayView(initialSection: .leaderboard) } label: {
                    Label("Leaderboard", systemImage: "trophy").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
        }
        GlassCard {
            NavigationLink { MatchDayView(initialSection: .allocations) } label: {
                HStack {
                    Label("View & Share Allocations", systemImage: "list.bullet.clipboard")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
            }
        }
        Text("Your team and participant selection are locked for this draw. Start a new game to change them.")
            .font(.caption).foregroundStyle(.white.opacity(0.85))
    }
}

#Preview { HomeView().environmentObject(GameViewModel()) }
