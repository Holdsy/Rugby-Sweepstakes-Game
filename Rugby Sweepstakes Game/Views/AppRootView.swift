import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var selection = AppTab.current
    @State private var currentNavigationID = UUID()
    private enum AppTab { case current, people, history }

    var body: some View {
        TabView(selection: $selection) {
            HomeView().id(currentNavigationID).tabItem { Label("Current Game", systemImage: "sportscourt") }.tag(AppTab.current)
            ParticipantsLibraryView().tabItem { Label("People", systemImage: "person.2") }.tag(AppTab.people)
            GameHistoryView { currentNavigationID = UUID(); selection = .current }
                .tabItem { Label("History", systemImage: "clock") }.tag(AppTab.history)
        }
        .disabled(viewModel.storageWritesBlocked)
        .overlay {
            if viewModel.storageWritesBlocked {
                ContentUnavailableView("Saved Games Unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text("Your existing save has been preserved. Close the app and investigate the saved data before making changes."))
                    .padding().background(.regularMaterial)
            }
        }
        .alert("Saved Games", isPresented: Binding(get: { viewModel.persistenceError != nil }, set: { if !$0 { viewModel.persistenceError = nil } })) {
            Button("OK") { viewModel.persistenceError = nil }
        } message: { Text(viewModel.persistenceError ?? "") }
    }
}

private struct ParticipantsLibraryView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var showAdd = false
    @State private var name = ""
    @State private var pendingDelete: SweepstakePlayer?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Save people for future sweepstakes. Choose who is playing when setting up a game.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if viewModel.game.isDrawComplete && !viewModel.game.isCompleted {
                        Text("People in the current draw can be renamed, but cannot be removed until the game is finished.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Saved people") {
                    ForEach(viewModel.masterPlayerList) { person in
                        HStack(spacing: 12) {
                            Circle().fill(person.color.color).frame(width: 14, height: 14)
                            TextField("Participant name", text: Binding(
                                get: { viewModel.masterPlayerList.first { $0.id == person.id }?.name ?? person.name },
                                set: { value in var updated = person; updated.name = value; viewModel.updateSweepstakePlayer(updated) }
                            ))
                            .accessibilityLabel("Name for \(person.name)")
                            if viewModel.isPlayerSelectedForGame(person.id) && !viewModel.game.isCompleted {
                                Text("In game").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            if viewModel.canDeletePlayer(person.id) {
                                Button(role: .destructive) { pendingDelete = person } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
                if viewModel.masterPlayerList.isEmpty { Text("Add a participant to get started.").foregroundStyle(.secondary) }
            }
            .navigationTitle("People")
            .toolbar { Button { showAdd = true } label: { Label("Add Participant", systemImage: "plus") } }
            .alert("Add Participant", isPresented: $showAdd) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) { name = "" }
                Button("Add") {
                    let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { viewModel.addMasterPlayer(name: value) }
                    name = ""
                }
            }
            .alert("Delete Participant?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    if let person = pendingDelete { viewModel.deleteMasterPlayer(person.id) }
                    pendingDelete = nil
                }
            } message: { Text("This removes them from your saved people. Past results are kept.") }
        }
    }
}
