import SwiftUI

/// A short setup journey; the active game remains the single source of truth.
struct GameSetupView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var showFixturePicker = false
    @State private var showTeamEditor = false
    @ObservedObject private var drafts = TeamDraftStore.shared
    @State private var selectedDraft: TeamLineupDraft?
    @State private var showDrafts = false
    @State private var showAddParticipant = false
    @State private var newParticipantName = ""
    @State private var showExclusions = false
    init(initialStep: Int) { _step = State(initialValue: min(max(initialStep, 0), 2)) }
    private let titles = ["Match & Team", "Participants", "Review & Draw"]

    private var participantsReady: Bool {
        (2...15).contains(viewModel.game.sweepstakePlayers.count) && viewModel.game.sweepstakePlayers.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    private var canContinue: Bool {
        step == 0 ? viewModel.game.isTeamSetupComplete : participantsReady
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        VStack(spacing: 5) {
                            Capsule().fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2)).frame(height: 4)
                            Text(titles[index]).font(.caption2).foregroundStyle(index == step ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                Form {
                    if step == 0 { teamStep }
                    else if step == 1 { participantsStep }
                    else { reviewStep }
                }
            }
            .navigationTitle(titles[step])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 0 ? "Close" : "Back") {
                        if step > 0 { step -= 1 } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step > 0 { Button("Save & Close") { dismiss() } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if step == 2 {
                        Button {
                            guard viewModel.game.canRunDraw, viewModel.game.isTeamSetupComplete, participantsReady else { return }
                            viewModel.runFullDraw()
                            dismiss()
                        } label: {
                            Label("Run Draw", systemImage: "shuffle").frame(maxWidth: .infinity)
                        }
                        .disabled(!viewModel.game.canRunDraw || !viewModel.game.isTeamSetupComplete || !participantsReady)
                    } else {
                        Button { step += 1 } label: {
                            Text(step == 0 ? "Continue to Participants" : "Review Draw").frame(maxWidth: .infinity)
                        }
                        .disabled(!canContinue)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showFixturePicker) { MatchdayImportView().environmentObject(viewModel) }
            .sheet(isPresented: $showDrafts) { DraftManagementView().environmentObject(viewModel) }
            .sheet(item: $selectedDraft) { draft in SavedTeamDraftReviewView(draft: draft).environmentObject(viewModel) }
            .sheet(isPresented: $showTeamEditor) {
                CurrentTeamReviewView().environmentObject(viewModel)
            }
            .alert("Add Participant", isPresented: $showAddParticipant) {
                TextField("Name", text: $newParticipantName)
                Button("Cancel", role: .cancel) { newParticipantName = "" }
                Button("Add to Game") {
                    let name = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    let id = viewModel.addMasterPlayer(name: name)
                    viewModel.togglePlayerSelection(id)
                    newParticipantName = ""
                }
            } message: { Text("They will also be saved for future games.") }
        }
    }

    @ViewBuilder private var teamStep: some View {
        Section {
            Text("Choose the rugby team for this sweepstake. Your setup is saved as you go.")
            Button { showFixturePicker = true } label: {
                Label("Choose Fixture & Team", systemImage: "sportscourt")
            }
            Text("Look up fixtures by date, or try a saved sample.")
                .font(.caption).foregroundStyle(.secondary)
            Button { showTeamEditor = true } label: {
                Label(viewModel.game.isTeamSetupComplete ? "Review or Edit Team" : "Finalise Team", systemImage: "person.3")
            }
        } header: { Text("Choose your team") }
        if !viewModel.game.isDrawComplete && !drafts.drafts.isEmpty {
            Section("Saved team drafts") {
                ForEach(drafts.drafts(for: viewModel.game.id)) { draft in
                    Button { selectedDraft = draft } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.fixtureName ?? draft.teamName).font(.headline)
                            Text("\(draft.teamName) · \(draft.namedCount) of 23 named").font(.subheadline)
                            Text("Saved \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button { showDrafts = true } label: { Label("Manage or Delete Drafts", systemImage: "doc.on.doc") }
            }
        }
        Section("Current selection") {
            if viewModel.game.fixtureName != nil { LabeledContent("Fixture", value: viewModel.game.displayTitle) }
            if let source = viewModel.game.providerName {
                Text("Lineup source: \(source)").font(.caption).foregroundStyle(.secondary)
            }
            TextField("Team name (for example, England)", text: Binding(
                get: { viewModel.game.selectedTeamName ?? "" },
                set: { viewModel.setSelectedTeamName($0) }
            ))
            LabeledContent("Starters named", value: "\(viewModel.game.namedStarters.count) of 15")
            LabeledContent("Replacements named", value: "\(viewModel.game.namedSubstitutes.count) of 8")
            if !viewModel.game.isTeamSetupComplete {
                Label("Name all 15 starters to continue", systemImage: "info.circle").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var participantsStep: some View {
        Section {
            Text("Choose the people taking part in this sweepstake.")
            LabeledContent("Selected", value: "\(viewModel.game.sweepstakePlayers.count)")
            Button { showAddParticipant = true } label: { Label("Add Participant", systemImage: "person.badge.plus") }
        }
        Section("Saved participants") {
            ForEach(viewModel.masterPlayerList) { participant in
                Button { viewModel.togglePlayerSelection(participant.id) } label: {
                    HStack {
                        Circle().fill(participant.color.color).frame(width: 16, height: 16)
                        Text(participant.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: viewModel.isPlayerSelectedForGame(participant.id) ? "checkmark.circle.fill" : "circle")
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(participant.name)
                .accessibilityValue(viewModel.isPlayerSelectedForGame(participant.id) ? "Selected" : "Not selected")
            }
        }
        if !participantsReady {
            Section { Text("Select between two and fifteen participants with names.").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var reviewStep: some View {
        Section("Draw summary") {
            LabeledContent("Team", value: viewModel.game.selectedTeamName ?? "Your team")
            LabeledContent("Participants", value: "\(viewModel.game.sweepstakePlayers.count)")
            LabeledContent("Rugby players included", value: "\(viewModel.game.enabledStarters.count)")
            if viewModel.game.canRunDraw {
                LabeledContent("Rugby players per participant", value: "\(viewModel.game.enabledStarters.count / viewModel.game.sweepstakePlayers.count)")
            }
            Text("Drawn starters and their linked replacements contribute points to their participant.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if viewModel.game.playersToDisableForEvenDraw > 0 {
            Section("Balance the draw") {
                let count = viewModel.game.playersToDisableForEvenDraw
                Text("Exclude \(count) more rugby \(count == 1 ? "player" : "players") so everyone receives the same number.")
                Button("Choose \(count) Exclusions Randomly") { viewModel.disableRandomStartersForEvenDraw(); showExclusions = true }
                    .disabled(count >= viewModel.game.enabledStarters.count)
            }
        }
        Section {
            DisclosureGroup("Review Included Players & Exclusions", isExpanded: $showExclusions) {
                ForEach(Array(viewModel.game.starters.enumerated()), id: \.element.id) { index, member in
                    Toggle(isOn: Binding(get: { member.isEnabledForGame }, set: { _ in viewModel.toggleEnabledForGame(member.id) })) {
                        Text("\(index + 1). \(member.name.isEmpty ? "Unnamed player" : member.name)")
                    }
                    .tint(.accentColor)
                }
            }
            Text("Excluded rugby players remain in the team but receive no allocation.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if !viewModel.game.canRunDraw {
            Section {
                if !viewModel.game.isTeamSetupComplete { Text("Go back and name all 15 starters.") }
                if viewModel.game.enabledStarters.isEmpty { Text("Include rugby players before running the draw.") }
                if !participantsReady { Text("Go back and select at least two named participants.") }
            }
            .foregroundStyle(.orange)
        }
    }
}
