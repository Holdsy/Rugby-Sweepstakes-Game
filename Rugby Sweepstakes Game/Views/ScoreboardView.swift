//
//  ScoreboardView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct ScoreboardView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showFinalResults = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var sortedPlayers: [SweepstakePlayer] {
        viewModel.getSortedSweepstakePlayers()
    }
    
    var winners: [SweepstakePlayer] {
        viewModel.getWinners()
    }
    
    var shareText: String {
        var text = "🏆 Rugby Sweepstakes - Final Scoreboard\n\n"
        
        if winners.count == 1 {
            text += "🏆 Winner: \(winners[0].name) - \(viewModel.getTotalPoints(for: winners[0].id)) points\n\n"
        } else if winners.count > 1 {
            text += "🏆 Tied Winners:\n"
            for winner in winners {
                text += "• \(winner.name) - \(viewModel.getTotalPoints(for: winner.id)) points\n"
            }
            text += "\n"
        }
        
        text += "Final Standings:\n"
        for (index, player) in sortedPlayers.enumerated() {
            let rank = index + 1
            let points = viewModel.getTotalPoints(for: player.id)
            text += "\(rank). \(player.name): \(points) pts\n"
        }
        
        text += "\nDetailed Breakdown:\n"
        for player in sortedPlayers {
            let points = viewModel.getTotalPoints(for: player.id)
            text += "\n\(player.name) (\(points) pts):\n"
            
            for teamMemberId in player.assignedTeamMemberIds {
                if let member = viewModel.getTeamMember(by: teamMemberId) {
                    let linkedSubstitute = viewModel.getLinkedSubstitute(for: member.id)
                    let memberPoints = viewModel.getTotalPointsForTeamMember(member.id)
                    
                    if let substitute = linkedSubstitute {
                        text += "  • \(member.displayName(linkedSubstitute: substitute)): \(memberPoints) pts\n"
                    } else {
                        let positionText = member.position.map { " - \($0)" } ?? ""
                        text += "  • \(member.name)\(positionText): \(memberPoints) pts\n"
                    }
                }
            }
        }
        
        return text
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 16) {
                GlassCard {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        
                        Text("Scoreboard")
                            .font(.title2.weight(.bold))
                        
                        Spacer()
                        
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                List {
                    ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                        Section {
                            ScoreboardPlayerRow(
                                player: player,
                                rank: index + 1,
                                totalPoints: viewModel.getTotalPoints(for: player.id),
                                isWinner: winners.contains { $0.id == player.id },
                                viewModel: viewModel
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFinalResults = true
                } label: {
                    Text("Finish Game")
                }
            }
        }
        .sheet(isPresented: $showFinalResults) {
            FinalResultsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
}

struct ScoreboardPlayerRow: View {
    let player: SweepstakePlayer
    let rank: Int
    let totalPoints: Int
    let isWinner: Bool
    let viewModel: GameViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isWinner {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                }
                
                Text("#\(rank)")
                    .font(.headline)
                    .foregroundColor(isWinner ? .yellow : .primary)
                
                Circle()
                    .fill(player.color.color)
                    .frame(width: 30, height: 30)
                
                Text(player.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(totalPoints) pts")
                    .font(isWinner ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(isWinner ? .yellow : .blue)
            }
            
            if isWinner {
                Text("WINNER")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Team Members:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(player.assignedTeamMemberIds.compactMap { viewModel.getTeamMember(by: $0) }, id: \.id) { member in
                    let linkedSubstitute = viewModel.getLinkedSubstitute(for: member.id)
                    let memberPoints = viewModel.getTotalPointsForTeamMember(member.id)
                    
                    HStack {
                        if let substitute = linkedSubstitute {
                            Text("• \(member.displayName(linkedSubstitute: substitute))")
                                .font(.caption)
                        } else {
                            Text("• \(member.name)\(member.position.map { " - \($0)" } ?? "")")
                                .font(.caption)
                        }
                        Spacer()
                        Text("\(memberPoints) pts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(isWinner ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct FinalResultsView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.dismiss) var dismiss
    
    var sortedPlayers: [SweepstakePlayer] {
        viewModel.getSortedSweepstakePlayers()
    }
    
    var winners: [SweepstakePlayer] {
        viewModel.getWinners()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Winner section
                    VStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        if winners.count == 1 {
                            Text("Winner")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text(winners[0].name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("\(viewModel.getTotalPoints(for: winners[0].id)) points")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Tie!")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            ForEach(winners) { winner in
                                Text(winner.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            if let firstWinner = winners.first {
                                Text("\(viewModel.getTotalPoints(for: firstWinner.id)) points each")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(12)
                    
                    // Final standings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Final Standings")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 40)
                                
                                Circle()
                                    .fill(player.color.color)
                                    .frame(width: 24, height: 24)
                                
                                Text(player.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(viewModel.getTotalPoints(for: player.id)) pts")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Detailed breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Point Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(sortedPlayers) { player in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(player.color.color)
                                        .frame(width: 20, height: 20)
                                    Text(player.name)
                                        .font(.headline)
                                }
                                
                                ForEach(player.assignedTeamMemberIds.compactMap { viewModel.getTeamMember(by: $0) }, id: \.id) { member in
                                    let linkedSubstitute = viewModel.getLinkedSubstitute(for: member.id)
                                    let memberPoints = viewModel.getTotalPointsForTeamMember(member.id)
                                    
                                    HStack {
                                        if let substitute = linkedSubstitute {
                                            Text("• \(member.displayName(linkedSubstitute: substitute))")
                                                .font(.caption)
                                        } else {
                                            Text("• \(member.name)\(member.position.map { " - \($0)" } ?? "")")
                                                .font(.caption)
                                        }
                                        Spacer()
                                        Text("\(memberPoints) pts")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Final Results")
            .navigationBarTitleDisplayMode(.inline)
            .background(LiquidGlassBackground())
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScoreboardView()
            .environmentObject(GameViewModel())
    }
}

