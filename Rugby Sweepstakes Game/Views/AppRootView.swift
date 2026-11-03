import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var selection = AppTab.current
    @State private var currentNavigationID = UUID()
    @State private var showRecovery = false
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
                VStack {
                    ContentUnavailableView("Saved Games Unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text("Your existing save has been preserved. You can restore a previously exported backup."))
                    Button("Backup & Restore") { showRecovery = true }.buttonStyle(AppPrimaryButtonStyle())
                }.padding().background(AppTheme.card)
            }
        }
        .sheet(isPresented: $showRecovery) { BackupRestoreView().environmentObject(viewModel) }
        .alert("Saved Games", isPresented: Binding(get: { viewModel.persistenceError != nil }, set: { if !$0 { viewModel.persistenceError = nil } })) {
            Button("OK") { viewModel.persistenceError = nil }
        } message: { Text(viewModel.persistenceError ?? "") }
    }
}

private struct ParticipantsLibraryView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var showAdd = false
    @State private var pendingDelete: SweepstakePlayer?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your saved people stay in this list. Turn on Playing this game for everyone taking part.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LabeledContent("Saved people", value: "\(viewModel.masterPlayerList.count)")
                    LabeledContent(viewModel.game.isCompleted ? "In completed game" : "Playing this game", value: "\(viewModel.game.sweepstakePlayers.count)")
                    if viewModel.game.isDrawComplete {
                        Text("The draw has been made, so this game’s participants are locked. You can still save people for the next game.")
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
                            Toggle("Playing this game", isOn: Binding(
                                get: { viewModel.isPlayerSelectedForGame(person.id) },
                                set: { _ in viewModel.togglePlayerSelection(person.id) }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("\(person.name), playing this game")
                            .disabled(viewModel.game.isDrawComplete || (!viewModel.isPlayerSelectedForGame(person.id) && viewModel.game.sweepstakePlayers.count >= 15))
                        }
                        .swipeActions {
                            if viewModel.canDeletePlayer(person.id) {
                                Button(role: .destructive) { pendingDelete = person } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
                if viewModel.masterPlayerList.isEmpty { Text("Add a participant to get started.").foregroundStyle(.secondary) }
            }.appListSurface()
            .navigationTitle("People")
            .toolbar { Button { showAdd = true } label: { Label("Add Participant", systemImage: "plus") } }
            .sheet(isPresented: $showAdd) { AddParticipantSheet().environmentObject(viewModel) }
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

/// Shared by the saved people list and game setup so saving and selecting are explicit.
struct AddParticipantSheet: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var playing = true
    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicate: Bool {
        viewModel.masterPlayerList.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(cleanName) == .orderedSame }
    }
    private var canSelect: Bool { !viewModel.game.isDrawComplete && viewModel.game.sweepstakePlayers.count < 15 }
    var body: some View {
        NavigationStack {
            Form {
                Section("Save a person") {
                    TextField("Name", text: $name).textContentType(.name).autocorrectionDisabled()
                    Text("They will stay in your People list for future games.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Playing this game", isOn: $playing).disabled(!canSelect)
                    if viewModel.game.isDrawComplete {
                        Text("This draw is locked. The new person will be saved for future games.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if !canSelect {
                        Text("This game already has 15 people. Save this person, then turn someone else off to include them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if duplicate && !cleanName.isEmpty {
                        Text("This name is already in People. Use their existing switch, or enter a distinct name.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }.appListSurface()
            .navigationTitle("Add Person").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard !cleanName.isEmpty, cleanName.count <= 120, !duplicate else { return }
                    let id = viewModel.addMasterPlayer(name: cleanName)
                    if playing && canSelect { viewModel.togglePlayerSelection(id) }
                    dismiss()
                } label: {
                    Text(playing && canSelect ? "Save & Add to Game" : "Save Person").frame(maxWidth: .infinity)
                }.buttonStyle(AppPrimaryButtonStyle()).disabled(cleanName.isEmpty || cleanName.count > 120 || duplicate)
                    .padding().background(AppTheme.card)
            }
            .onAppear { playing = canSelect }
        }
    }
}
