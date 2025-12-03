//
//  Rugby_Sweepstakes_GameApp.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import SwiftUI

@main
struct Rugby_Sweepstakes_GameApp: App {
    @StateObject private var gameViewModel = GameViewModel()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(gameViewModel)
        }
    }
}
