//
//  HomeView.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rugby Sweepstakes")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("Set up your team and players, run the draw, and track the action live.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                            
                            VStack(alignment: .leading, spacing: 24) {
                                // Setup
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Setup")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    VStack(spacing: 8) {
                                        NavigationLink {
                                            TeamSetupView()
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "person.3.fill")
                                                    .frame(width: 26, alignment: .leading)
                                                Text("Set Up Team")
                                            }
                                            .font(.body.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        NavigationLink {
                                            SweepstakePlayersSetupView()
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "person.2.fill")
                                                    .frame(width: 26, alignment: .leading)
                                                Text("Set Up Players")
                                            }
                                            .font(.body.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                Divider()
                                
                                // Game
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Game")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    VStack(spacing: 8) {
                                        NavigationLink {
                                            DrawView()
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "shuffle")
                                                    .frame(width: 26, alignment: .leading)
                                                Text("Run Draw")
                                            }
                                            .font(.body.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        .opacity(viewModel.game.canRunDraw ? 1.0 : 0.4)
                                        .disabled(!viewModel.game.canRunDraw)
                                        
                                        if viewModel.game.isDrawComplete {
                                            NavigationLink {
                                                DrawResultsView()
                                            } label: {
                                                HStack(spacing: 16) {
                                                    Image(systemName: "list.bullet.clipboard")
                                                        .frame(width: 26, alignment: .leading)
                                                    Text("View Draw Results")
                                                }
                                                .font(.body.weight(.semibold))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            NavigationLink {
                                                ScoringView()
                                            } label: {
                                                HStack(spacing: 16) {
                                                    Image(systemName: "sportscourt.fill")
                                                        .frame(width: 26, alignment: .leading)
                                                    Text("Scoring / Live Game")
                                                }
                                                .font(.body.weight(.semibold))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Text("Complete setup to unlock live scoring.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                // Results
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Results")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if viewModel.game.isDrawComplete {
                                        NavigationLink {
                                            ScoreboardView()
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "trophy.fill")
                                                    .frame(width: 26, alignment: .leading)
                                                Text("Scoreboard / Results")
                                            }
                                            .font(.body.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text("Run the draw to view the scoreboard and final results.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Divider()
                                
                                // Admin
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Admin")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Button(role: .destructive) {
                                        viewModel.resetGame()
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .frame(width: 26, alignment: .leading)
                                            Text("Reset Game")
                                        }
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(GameViewModel())
}

