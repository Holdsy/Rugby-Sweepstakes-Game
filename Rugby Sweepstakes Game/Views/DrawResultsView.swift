//
//  DrawResultsView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct DrawResultsView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            List {
                ForEach(viewModel.game.sweepstakePlayers) { player in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(player.color.color)
                                    .frame(width: 24, height: 24)
                                Text(player.name)
                                    .font(.headline)
                            }
                            
                            if player.assignedTeamMemberIds.isEmpty {
                                Text("No team members assigned")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                // Group by rounds
                                let rounds = getRoundsForPlayer(player)
                                
                                ForEach(Array(rounds.keys.sorted()), id: \.self) { roundNumber in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Round \(roundNumber)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        
                                        ForEach(rounds[roundNumber] ?? [], id: \.id) { member in
                                            if let linkedSubstitute = viewModel.getLinkedSubstitute(for: member.id) {
                                                Text("• \(member.displayName(linkedSubstitute: linkedSubstitute))")
                                                    .font(.caption)
                                            } else {
                                                Text("• \(member.name)\(member.position.map { " - " + $0 } ?? "")")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Draw Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ScoringView()
                } label: {
                    Text("Start Scoring")
                }
            }
        }
    }
    
    private func getRoundsForPlayer(_ player: SweepstakePlayer) -> [Int: [TeamMember]] {
        var rounds: [Int: [TeamMember]] = [:]
        
        for (roundIndex, roundAllocations) in player.drawRounds.enumerated() {
            let roundNumber = roundIndex + 1
            var members: [TeamMember] = []
            
            for allocation in roundAllocations {
                if let member = viewModel.getTeamMember(by: allocation.teamMemberId) {
                    members.append(member)
                }
            }
            
            if !members.isEmpty {
                rounds[roundNumber] = members
            }
        }
        
        return rounds
    }
}

#Preview {
    NavigationStack {
        DrawResultsView()
            .environmentObject(GameViewModel())
    }
}

