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
            List {
                Section {
                    NavigationLink {
                        TeamSetupView()
                    } label: {
                        Label("Set Up Team", systemImage: "person.3.fill")
                    }
                    
                    NavigationLink {
                        SweepstakePlayersSetupView()
                    } label: {
                        Label("Set Up Players", systemImage: "person.2.fill")
                    }
                } header: {
                    Text("Setup")
                }
                
                Section {
                    NavigationLink {
                        DrawView()
                    } label: {
                        Label("Run Draw", systemImage: "shuffle")
                    }
                    .disabled(!viewModel.game.canRunDraw)
                    
                    if viewModel.game.isDrawComplete {
                        NavigationLink {
                            DrawResultsView()
                        } label: {
                            Label("View Draw Results", systemImage: "list.bullet.clipboard")
                        }
                        
                        NavigationLink {
                            ScoringView()
                        } label: {
                            Label("Scoring / Live Game", systemImage: "sportscourt.fill")
                        }
                    }
                } header: {
                    Text("Game")
                }
                
                Section {
                    if viewModel.game.isDrawComplete {
                        NavigationLink {
                            ScoreboardView()
                        } label: {
                            Label("Scoreboard / Results", systemImage: "trophy.fill")
                        }
                    }
                } header: {
                    Text("Results")
                }
                
                Section {
                    Button(role: .destructive) {
                        viewModel.resetGame()
                    } label: {
                        Label("Reset Game", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Rugby Sweepstake")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(GameViewModel())
}

