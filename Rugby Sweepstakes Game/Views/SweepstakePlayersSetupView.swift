//
//  SweepstakePlayersSetupView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct SweepstakePlayersSetupView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        Form {
            Section {
                Text("Sweepstake Players: \(viewModel.game.sweepstakePlayers.count)/6")
                    .font(.caption)
                    .foregroundColor(viewModel.game.sweepstakePlayers.count == 6 ? .green : .orange)
            } header: {
                Text("Players")
            } footer: {
                Text("Enter names for all 6 sweepstake players. Each player will be assigned team members through the draw.")
            }
            
            ForEach(viewModel.game.sweepstakePlayers) { player in
                SweepstakePlayerRow(
                    player: player,
                    onUpdate: { updatedPlayer in
                        viewModel.updateSweepstakePlayer(updatedPlayer)
                    }
                )
            }
        }
        .navigationTitle("Sweepstake Players")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SweepstakePlayerRow: View {
    let player: SweepstakePlayer
    let onUpdate: (SweepstakePlayer) -> Void
    
    @State private var name: String
    
    init(player: SweepstakePlayer, onUpdate: @escaping (SweepstakePlayer) -> Void) {
        self.player = player
        self.onUpdate = onUpdate
        _name = State(initialValue: player.name)
    }
    
    var body: some View {
        HStack {
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SweepstakePlayersSetupView()
            .environmentObject(GameViewModel())
    }
}

