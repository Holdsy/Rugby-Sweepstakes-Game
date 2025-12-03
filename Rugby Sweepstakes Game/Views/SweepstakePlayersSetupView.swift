//
//  SweepstakePlayersSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct SweepstakePlayersSetupView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPlayer = false
    @State private var newPlayerName = ""
    
    var selectedCount: Int {
        viewModel.game.sweepstakePlayers.count
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Match HomeView / TeamSetup header
                    HStack(spacing: 8) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sweepstake Players")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("Manage the master list and choose 6 players for this game.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            // Current game selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Current Game Selection")
                                    .font(.headline)
                                
                                HStack {
                                    Text("Selected for Game: \(selectedCount)/6")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(selectedCount == 6 ? .green : .orange)
                                    
                                    Spacer()
                                    
                                    Button {
                                        showAddPlayer = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Player")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                    }
                                }
                                
                                Text("Select exactly 6 players for the current game. You can add or delete players from the master list below.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // All players list
                            VStack(alignment: .leading, spacing: 12) {
                                Text("All Players")
                                    .font(.headline)
                                
                                if viewModel.masterPlayerList.isEmpty {
                                    Text("No players yet. Tap \"Add Player\" to create one.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.masterPlayerList) { player in
                                            SweepstakePlayerRow(
                                                player: player,
                                                isSelected: viewModel.isPlayerSelectedForGame(player.id),
                                                canSelect: selectedCount < 6 || viewModel.isPlayerSelectedForGame(player.id),
                                                onUpdate: { updatedPlayer in
                                                    viewModel.updateSweepstakePlayer(updatedPlayer)
                                                },
                                                onToggleSelection: {
                                                    viewModel.togglePlayerSelection(player.id)
                                                },
                                                onDelete: {
                                                    viewModel.deleteMasterPlayer(player.id)
                                                }
                                            )
                                        }
                                    }
                                }
                                
                                Text("Master list of all players. Changes persist between games.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddPlayer) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Player Name", text: $newPlayerName)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("New Player")
                    } footer: {
                        Text("Enter a name for the new player")
                    }
                }
                .navigationTitle("Add Player")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            newPlayerName = ""
                            showAddPlayer = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if !newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty {
                                viewModel.addMasterPlayer(name: newPlayerName.trimmingCharacters(in: .whitespaces))
                                newPlayerName = ""
                                showAddPlayer = false
                            }
                        }
                        .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct SweepstakePlayerRow: View {
    let player: SweepstakePlayer
    let isSelected: Bool
    let canSelect: Bool
    let onUpdate: (SweepstakePlayer) -> Void
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    
    @State private var name: String
    @State private var showDeleteConfirmation = false
    
    init(
        player: SweepstakePlayer,
        isSelected: Bool,
        canSelect: Bool,
        onUpdate: @escaping (SweepstakePlayer) -> Void,
        onToggleSelection: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.player = player
        self.isSelected = isSelected
        self.canSelect = canSelect
        self.onUpdate = onUpdate
        self.onToggleSelection = onToggleSelection
        self.onDelete = onDelete
        _name = State(initialValue: player.name)
    }
    
    var body: some View {
        HStack {
            // Selection indicator
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!canSelect && !isSelected)
            
            Circle()
                .fill(player.color.color)
                .frame(width: 30, height: 30)
            
            TextField("Player Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, newValue in
                    var updated = player
                    updated.name = newValue
                    onUpdate(updated)
                }
            
            // Selected badge
            if isSelected {
                Text("IN GAME")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            
            // Delete button
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .alert("Delete Player", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } message: {
                if isSelected {
                    Text("\(player.name) is currently selected for the game. Deleting will remove them from the game. This cannot be undone.")
                } else {
                    Text("Are you sure you want to delete \(player.name)? This cannot be undone.")
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(canSelect || isSelected ? 1.0 : 0.6)
    }
}

#Preview {
    NavigationStack {
        SweepstakePlayersSetupView()
            .environmentObject(GameViewModel())
    }
}
