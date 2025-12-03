//
//  ScoringView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct ScoringView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.game.enabledStarters) { starter in
                ScoringRow(
                    starter: starter,
                    linkedSubstitute: viewModel.getLinkedSubstitute(for: starter.id),
                    onAddTry: {
                        viewModel.addTry(to: starter.id)
                    },
                    onAddPenalty: {
                        viewModel.addPenalty(to: starter.id)
                    },
                    onAddConversion: {
                        viewModel.addConversion(to: starter.id)
                    },
                    totalPoints: viewModel.getTotalPointsForTeamMember(starter.id)
                )
            }
        }
        .navigationTitle("Scoring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ScoreboardView()) {
                    Image(systemName: "trophy.fill")
                }
            }
        }
    }
}

struct ScoringRow: View {
    let starter: TeamMember
    let linkedSubstitute: TeamMember?
    let onAddTry: () -> Void
    let onAddPenalty: () -> Void
    let onAddConversion: () -> Void
    let totalPoints: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(starter.name)
                        .font(.headline)
                    
                    if let position = starter.position {
                        Text(position)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let substitute = linkedSubstitute {
                        Text("(\(substitute.name) on)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Text("\(totalPoints) pts")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button {
                    onAddTry()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.run")
                        Text("Try")
                            .font(.caption)
                        Text("5")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Button {
                    onAddPenalty()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "target")
                        Text("Penalty")
                            .font(.caption)
                        Text("3")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Button {
                    onAddConversion()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text("Conversion")
                            .font(.caption)
                        Text("2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ScoringView()
            .environmentObject(GameViewModel())
    }
}

