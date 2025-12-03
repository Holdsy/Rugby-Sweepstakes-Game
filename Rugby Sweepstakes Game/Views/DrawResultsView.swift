//
//  DrawResultsView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct DrawResultsView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    
    // Build a simple text summary of the draw that can be shared
    private var shareText: String {
        var lines: [String] = []
        lines.append("Rugby Sweepstakes – Draw Results")
        lines.append("")
        
        for player in viewModel.game.sweepstakePlayers {
            lines.append("\(player.name):")
            let rounds = getRoundsForPlayer(player)
            
            if rounds.isEmpty {
                lines.append("  No team members assigned")
            } else {
                for round in rounds.keys.sorted() {
                    lines.append("  Round \(round):")
                    for member in rounds[round] ?? [] {
                        if let linkedSubstitute = viewModel.getLinkedSubstitute(for: member.id) {
                            lines.append("    • \(member.displayName(linkedSubstitute: linkedSubstitute))")
                        } else {
                            let extra = member.position.map { " (\($0))" } ?? ""
                            lines.append("    • \(member.name)\(extra)")
                        }
                    }
                }
            }
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header matching HomeView style
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
                            Text("Draw Results")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("See which sweepstake players drew which team members.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Button {
                            isSharing = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Player result cards
                    VStack(spacing: 16) {
                        ForEach(viewModel.game.sweepstakePlayers) { player in
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(player.color.color)
                                            .frame(width: 28, height: 28)
                                        
                                        Text(player.name)
                                            .font(.headline)
                                        
                                        Spacer()
                                    }
                                    
                                    if player.assignedTeamMemberIds.isEmpty {
                                        Text("No team members assigned")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        let rounds = getRoundsForPlayer(player)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(Array(rounds.keys.sorted()), id: \.self) { roundNumber in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Round \(roundNumber)")
                                                        .font(.subheadline.weight(.semibold))
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
                                            }
                                        }
                                        .padding(.leading, 2)
                                    }
                                }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ScoringView()
                } label: {
                    Text("Start Scoring")
                }
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(activityItems: [shareText])
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

