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
    
    var sortedPlayers: [SweepstakePlayer] {
        viewModel.getSortedSweepstakePlayers()
    }
    
    var winners: [SweepstakePlayer] {
        viewModel.getWinners()
    }
    
    var body: some View {
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
        .navigationTitle("Scoreboard")
        .navigationBarTitleDisplayMode(.inline)
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
                    .background(Color.yellow.opacity(0.1))
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
                            .background(Color(.systemGray6))
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
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Final Results")
            .navigationBarTitleDisplayMode(.inline)
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

