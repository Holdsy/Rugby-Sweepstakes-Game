//
//  GameViewModel.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    @Published var game: Game
    private let persistenceService = GamePersistenceService()
    
    init() {
        // Try to load existing game, or create a new one
        if let savedGame = persistenceService.loadGame() {
            self.game = savedGame
        } else {
            self.game = Game()
            initializeDefaultGame()
        }
        saveGame()
    }
    
    // MARK: - Initialization
    
    private func initializeDefaultGame() {
        // Initialize with default 6 sweepstake players
        var players: [SweepstakePlayer] = []
        for i in 1...6 {
            players.append(SweepstakePlayer(name: "Player \(i)"))
        }
        game.sweepstakePlayers = players
        
        // Initialize with 15 starters and 8 substitutes (empty for user to fill)
        var members: [TeamMember] = []
        
        // Add 15 starters
        for _ in 1...15 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: true,
                isSubstitute: false,
                isEnabledForGame: true
            ))
        }
        
        // Add 8 substitutes
        for _ in 1...8 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: false,
                isSubstitute: true,
                isEnabledForGame: false
            ))
        }
        
        game.teamMembers = members
    }
    
    // MARK: - Team Management
    
    func updateTeamMember(_ member: TeamMember) {
        if let index = game.teamMembers.firstIndex(where: { $0.id == member.id }) {
            game.teamMembers[index] = member
            saveGame()
        }
    }
    
    func toggleEnabledForGame(_ memberId: UUID) {
        if let index = game.teamMembers.firstIndex(where: { $0.id == memberId && $0.isStarter }) {
            game.teamMembers[index].isEnabledForGame.toggle()
            saveGame()
        }
    }
    
    func linkSubstitute(substituteId: UUID, to starterId: UUID) {
        // Unlink substitute from any other starter first
        for i in game.teamMembers.indices {
            if game.teamMembers[i].isStarter && game.teamMembers[i].linkedSubstituteId == substituteId {
                game.teamMembers[i].linkedSubstituteId = nil
            }
        }
        
        // Link to the new starter
        if let starterIndex = game.teamMembers.firstIndex(where: { $0.id == starterId && $0.isStarter }) {
            game.teamMembers[starterIndex].linkedSubstituteId = substituteId
            saveGame()
        }
    }
    
    func unlinkSubstitute(from starterId: UUID) {
        if let starterIndex = game.teamMembers.firstIndex(where: { $0.id == starterId && $0.isStarter }) {
            game.teamMembers[starterIndex].linkedSubstituteId = nil
            saveGame()
        }
    }
    
    func getTeamMember(by id: UUID) -> TeamMember? {
        game.teamMembers.first { $0.id == id }
    }
    
    // MARK: - Sweepstake Players Management
    
    func updateSweepstakePlayer(_ player: SweepstakePlayer) {
        if let index = game.sweepstakePlayers.firstIndex(where: { $0.id == player.id }) {
            game.sweepstakePlayers[index] = player
            saveGame()
        }
    }
    
    // MARK: - Draw Logic
    
    func runFullDraw() {
        guard game.canRunDraw && !game.isDrawComplete else { return }
        
        // Reset previous draw if any
        for i in game.sweepstakePlayers.indices {
            game.sweepstakePlayers[i].assignedTeamMemberIds = []
            game.sweepstakePlayers[i].drawRounds = []
        }
        
        var remainingTeamMembers = game.enabledStarters.map { $0.id }
        var roundNumber = 1
        var currentRoundAllocations: [Allocation] = []
        
        while !remainingTeamMembers.isEmpty {
            // Shuffle sweepstake players for this round
            let shuffledPlayers = game.sweepstakePlayers.shuffled()
            var playerIndex = 0
            
            while !remainingTeamMembers.isEmpty && playerIndex < shuffledPlayers.count {
                // Pick a random team member
                guard let randomMemberId = remainingTeamMembers.randomElement() else { break }
                
                // Remove from remaining list
                remainingTeamMembers.removeAll { $0 == randomMemberId }
                
                // Create allocation
                let allocation = Allocation(
                    roundNumber: roundNumber,
                    sweepstakePlayerId: shuffledPlayers[playerIndex].id,
                    teamMemberId: randomMemberId
                )
                
                // Find the sweepstake player and add allocation
                if let playerIndexInGame = game.sweepstakePlayers.firstIndex(where: { $0.id == shuffledPlayers[playerIndex].id }) {
                    game.sweepstakePlayers[playerIndexInGame].assignedTeamMemberIds.append(randomMemberId)
                    currentRoundAllocations.append(allocation)
                }
                
                playerIndex += 1
            }
            
            // Store round allocations in each player's drawRounds
            for allocation in currentRoundAllocations {
                if let playerIndex = game.sweepstakePlayers.firstIndex(where: { $0.id == allocation.sweepstakePlayerId }) {
                    // Find or create the round array for this player
                    if game.sweepstakePlayers[playerIndex].drawRounds.count < roundNumber {
                        // Add new round arrays up to the current round
                        while game.sweepstakePlayers[playerIndex].drawRounds.count < roundNumber {
                            game.sweepstakePlayers[playerIndex].drawRounds.append([])
                        }
                    }
                    game.sweepstakePlayers[playerIndex].drawRounds[roundNumber - 1].append(allocation)
                }
            }
            
            currentRoundAllocations = []
            roundNumber += 1
        }
        
        game.isDrawComplete = true
        saveGame()
    }
    
    // MARK: - Scoring
    
    func addPoints(to teamMemberId: UUID, points: Int) {
        if let index = game.teamMembers.firstIndex(where: { $0.id == teamMemberId }) {
            game.teamMembers[index].points += points
            saveGame()
        }
    }
    
    func addTry(to teamMemberId: UUID) {
        addPoints(to: teamMemberId, points: 5)
    }
    
    func addPenalty(to teamMemberId: UUID) {
        addPoints(to: teamMemberId, points: 3)
    }
    
    func addConversion(to teamMemberId: UUID) {
        addPoints(to: teamMemberId, points: 2)
    }
    
    // Get total points for a team member bundle (starter + linked substitute)
    func getTotalPointsForTeamMember(_ teamMemberId: UUID) -> Int {
        guard let member = getTeamMember(by: teamMemberId) else { return 0 }
        
        var total = member.points
        
        // Add points from linked substitute if exists
        if let substituteId = member.linkedSubstituteId,
           let substitute = getTeamMember(by: substituteId) {
            total += substitute.points
        }
        
        return total
    }
    
    // Get total points for a sweepstake player
    func getTotalPoints(for sweepstakePlayerId: UUID) -> Int {
        guard let player = game.sweepstakePlayers.first(where: { $0.id == sweepstakePlayerId }) else {
            return 0
        }
        
        var total = 0
        for teamMemberId in player.assignedTeamMemberIds {
            total += getTotalPointsForTeamMember(teamMemberId)
        }
        
        return total
    }
    
    // Get sorted sweepstake players by points (descending)
    func getSortedSweepstakePlayers() -> [SweepstakePlayer] {
        game.sweepstakePlayers.sorted { getTotalPoints(for: $0.id) > getTotalPoints(for: $1.id) }
    }
    
    // Get winners (handles ties)
    func getWinners() -> [SweepstakePlayer] {
        let sorted = getSortedSweepstakePlayers()
        guard let highestScore = sorted.first.map({ getTotalPoints(for: $0.id) }) else {
            return []
        }
        
        return sorted.filter { getTotalPoints(for: $0.id) == highestScore }
    }
    
    // MARK: - Helper Methods
    
    func getLinkedSubstitute(for starterId: UUID) -> TeamMember? {
        guard let starter = getTeamMember(by: starterId),
              let substituteId = starter.linkedSubstituteId else {
            return nil
        }
        return getTeamMember(by: substituteId)
    }
    
    func resetGame() {
        persistenceService.clearGame()
        game = Game()
        initializeDefaultGame()
        saveGame()
    }
    
    // MARK: - Persistence
    
    private func saveGame() {
        persistenceService.saveGame(game)
    }
}

