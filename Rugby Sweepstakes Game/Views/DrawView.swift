//
//  DrawView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct DrawView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isRunningDraw = false
    @State private var showResults = false
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            ScrollView {
                VStack(spacing: 30) {
                    if viewModel.game.isDrawComplete {
                        GlassCard {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                
                                Text("Draw Complete!")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("\(viewModel.game.enabledStarters.count) team members allocated to \(viewModel.game.sweepstakePlayers.count) players")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                NavigationLink {
                                    DrawResultsView()
                                } label: {
                                    Label("View Draw Results", systemImage: "list.bullet.clipboard")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 20)
                    } else {
                        GlassCard {
                            VStack(spacing: 20) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                
                                Text("Random Draw")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("Ready to allocate \(viewModel.game.enabledStarters.count) enabled team members to 6 sweepstake players")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                if !viewModel.game.canRunDraw {
                                    VStack(spacing: 8) {
                                        Text("Cannot run draw yet:")
                                            .font(.headline)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            if viewModel.game.starters.count != 15 {
                                                Label("Need exactly 15 starters", systemImage: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                            if viewModel.game.substitutes.count != 8 {
                                                Label("Need exactly 8 substitutes", systemImage: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                            if viewModel.game.enabledStarters.isEmpty {
                                                Label("Need at least 1 enabled starter", systemImage: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                            if viewModel.game.sweepstakePlayers.count != 6 {
                                                Label("Need exactly 6 sweepstake players", systemImage: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(10)
                                }
                                
                                Button {
                                    runDraw()
                                } label: {
                                    if isRunningDraw {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                    } else {
                                        Label("Run Full Draw", systemImage: "shuffle")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(viewModel.game.canRunDraw ? Color.blue : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                                .disabled(!viewModel.game.canRunDraw || isRunningDraw)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
        }
        .navigationTitle("Draw")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func runDraw() {
        isRunningDraw = true
        
        // Add a small delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.runFullDraw()
            isRunningDraw = false
        }
    }
}

#Preview {
    NavigationStack {
        DrawView()
            .environmentObject(GameViewModel())
    }
}

