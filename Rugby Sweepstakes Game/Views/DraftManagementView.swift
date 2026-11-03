import SwiftUI

struct DraftManagementView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TeamDraftStore.shared
    @State private var selectedDraft: TeamLineupDraft?
    @State private var pendingDelete: TeamLineupDraft?
    @State private var error: String?
    private var drafts: [TeamLineupDraft] { store.drafts.sorted { $0.updatedAt > $1.updatedAt } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Resume a draft for your current setup, or delete drafts you no longer need. Deleting a draft leaves saved teams, scores and participants unchanged.")
                        .font(.subheadline)
                }
                if drafts.isEmpty {
                    ContentUnavailableView("No Team Drafts", systemImage: "doc", description: Text("Unfinished lineups appear here as you edit them."))
                }
                ForEach(drafts) { draft in
                    HStack(spacing: 12) {
                        if canResume(draft) {
                            Button { selectedDraft = draft } label: { row(draft) }.buttonStyle(.plain)
                        } else { row(draft) }
                        Spacer(minLength: 0)
                        Button { pendingDelete = draft } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).foregroundStyle(.red)
                            .accessibilityLabel("Delete \(draft.teamName) draft")
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { pendingDelete = draft }
                    }
                }
            }
            .navigationTitle("Team Drafts").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedDraft) { draft in SavedTeamDraftReviewView(draft: draft).environmentObject(viewModel) }
            .confirmationDialog("Delete this team draft?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                if let draft = pendingDelete {
                    Button("Delete Draft", role: .destructive) {
                        do { try store.remove(id: draft.id); pendingDelete = nil }
                        catch { self.error = error.localizedDescription }
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { Text("Only the unfinished draft will be removed. Your saved team, draw and scores will stay unchanged.") }
            .alert("Draft Could Not Be Deleted", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(error ?? "") }
        }
    }
    private func canResume(_ draft: TeamLineupDraft) -> Bool {
        draft.gameID == viewModel.game.id && !viewModel.game.isDrawComplete
    }
    private func row(_ draft: TeamLineupDraft) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(draft.fixtureName ?? draft.teamName).font(.headline)
            Text("\(draft.teamName) · \(draft.namedCount) of 23 named").font(.subheadline)
            Text("Saved \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            if canResume(draft) { Label("Resume Draft", systemImage: "pencil").font(.caption).foregroundStyle(Color.accentColor) }
            else if viewModel.savedGames.contains(where: { $0.id == draft.gameID && !$0.isDrawComplete }) {
                Text("Resume this game from History to edit its draft.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Earlier setup · available to delete").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
