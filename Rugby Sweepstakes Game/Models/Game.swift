//
//  Game.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

struct Game: Identifiable, Codable {
    let id: UUID
    var name: String?
    var teamMembers: [TeamMember] // Exactly 23: 15 starters + 8 substitutes
    var sweepstakePlayers: [SweepstakePlayer] // Default 6 players
    var isDrawComplete: Bool
    
    init(
        id: UUID = UUID(),
        name: String? = nil,
        teamMembers: [TeamMember] = [],
        sweepstakePlayers: [SweepstakePlayer] = [],
        isDrawComplete: Bool = false
    ) {
        self.id = id
        self.name = name
        self.teamMembers = teamMembers
        self.sweepstakePlayers = sweepstakePlayers
        self.isDrawComplete = isDrawComplete
    }
    
    // Helper computed properties
    var starters: [TeamMember] {
        teamMembers.filter { $0.isStarter }
    }
    
    var substitutes: [TeamMember] {
        teamMembers.filter { $0.isSubstitute }
    }
    
    var enabledStarters: [TeamMember] {
        starters.filter { $0.isEnabledForGame }
    }
    
    // Check if game is ready for draw
    var canRunDraw: Bool {
        starters.count == 15 &&
        substitutes.count == 8 &&
        enabledStarters.count > 0 &&
        sweepstakePlayers.count == 6 &&
        sweepstakePlayers.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    // Check if all team members are set up
    var isTeamSetupComplete: Bool {
        starters.count == 15 && substitutes.count == 8
    }
}

