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
                    availableSubstitutes: viewModel.game.substitutes,
                    onAddTry: {
                        viewModel.addTry(to: starter.id)
                    },
                    onAddPenalty: {
                        viewModel.addPenalty(to: starter.id)
                    },
                    onAddConversion: {
                        viewModel.addConversion(to: starter.id)
                    },
                    onLinkSubstitute: { substituteId in
                        viewModel.linkSubstitute(substituteId: substituteId, to: starter.id)
                    },
                    onUnlinkSubstitute: {
                        viewModel.unlinkSubstitute(from: starter.id)
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
    let availableSubstitutes: [TeamMember]
    let onAddTry: () -> Void
    let onAddPenalty: () -> Void
    let onAddConversion: () -> Void
    let onLinkSubstitute: (UUID) -> Void
    let onUnlinkSubstitute: () -> Void
    let totalPoints: Int
    
    @State private var showSubstitutePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showSubstitutePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(starter.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Image(systemName: "person.badge.plus")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if let position = starter.position {
                            Text(position)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let substitute = linkedSubstitute {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.2.squarepath")
                                    .font(.caption2)
                                Text("\(substitute.name) on")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap")
                                    .font(.caption2)
                                Text("Tap to assign substitute")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(totalPoints) pts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
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
        .sheet(isPresented: $showSubstitutePicker) {
            SubstitutePickerView(
                substitutes: availableSubstitutes,
                currentLinkedSubstituteId: starter.linkedSubstituteId,
                onSelect: { substituteId in
                    onLinkSubstitute(substituteId)
                    showSubstitutePicker = false
                },
                onUnlink: {
                    onUnlinkSubstitute()
                    showSubstitutePicker = false
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        ScoringView()
            .environmentObject(GameViewModel())
    }
}

