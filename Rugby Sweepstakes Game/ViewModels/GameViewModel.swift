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
    @Published var masterPlayerList: [SweepstakePlayer] = []
    private let persistenceService = GamePersistenceService()
    
    init() {
        // Initialize game first (required before using self)
        self.game = Game()
        self.masterPlayerList = []
        
        // Load master player list
        masterPlayerList = persistenceService.loadMasterPlayerList()
        
        // Initialize default players if master list is empty
        if masterPlayerList.isEmpty {
            for i in 1...6 {
                let color = ColorData.color(at: i - 1)
                masterPlayerList.append(SweepstakePlayer(name: "Player \(i)", color: color))
            }
            saveMasterPlayerList()
        } else {
            // Ensure all existing players have unique colors
            ensureUniqueColors()
        }
        
        // Try to load existing game, or create a new one
        if let savedGame = persistenceService.loadGame() {
            self.game = savedGame
            // Sync selected players with master list (in case master list was updated)
            syncSelectedPlayersWithMaster()
        } else {
            initializeDefaultGame()
        }
        saveGame()
    }
    
    // MARK: - Initialization
    
    private func initializeDefaultGame() {
        // Initialize with first 6 players from master list (or all if less than 6)
        game.sweepstakePlayers = Array(masterPlayerList.prefix(6))
        syncSelectedPlayersWithMaster()
        
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
        // Update in master list
        if let index = masterPlayerList.firstIndex(where: { $0.id == player.id }) {
            masterPlayerList[index] = player
            saveMasterPlayerList()
        }
        
        // Update in current game if selected
        if let index = game.sweepstakePlayers.firstIndex(where: { $0.id == player.id }) {
            game.sweepstakePlayers[index] = player
            saveGame()
        }
    }
    
    func addMasterPlayer(name: String) {
        let uniqueColor = getNextAvailableColor()
        let newPlayer = SweepstakePlayer(name: name, color: uniqueColor)
        masterPlayerList.append(newPlayer)
        saveMasterPlayerList()
    }
    
    // MARK: - Color Management
    
    private func getNextAvailableColor() -> ColorData {
        let usedColors = Set(masterPlayerList.map { colorToString($0.color) })
        return getNextAvailableColor(excluding: usedColors)
    }
    
    private func ensureUniqueColors() {
        var assignedColorStrings: Set<String> = []
        var changed = false
        
        // Go through each player and ensure they have a unique color
        for index in masterPlayerList.indices {
            let currentColorString = colorToString(masterPlayerList[index].color)
            
            if assignedColorStrings.contains(currentColorString) {
                // This color is already used, assign a new unique one
                let newColor = getNextAvailableColor(excluding: assignedColorStrings)
                masterPlayerList[index].color = newColor
                let newColorString = colorToString(newColor)
                assignedColorStrings.insert(newColorString)
                changed = true
            } else {
                // This color is unique, keep it
                assignedColorStrings.insert(currentColorString)
            }
        }
        
        if changed {
            saveMasterPlayerList()
        }
    }
    
    private func colorToString(_ color: ColorData) -> String {
        // Round to avoid floating point precision issues
        String(format: "%.2f,%.2f,%.2f", color.red, color.green, color.blue)
    }
    
    private func getNextAvailableColor(excluding usedColors: Set<String>) -> ColorData {
        // Try each available color in order
        for colorTuple in ColorData.allAvailableColors {
            let colorString = String(format: "%.2f,%.2f,%.2f", colorTuple.0, colorTuple.1, colorTuple.2)
            if !usedColors.contains(colorString) {
                return ColorData(red: colorTuple.0, green: colorTuple.1, blue: colorTuple.2)
            }
        }
        
        // If all colors are used, cycle through them based on count
        let colorIndex = usedColors.count % ColorData.allAvailableColors.count
        return ColorData.color(at: colorIndex)
    }
    
    func deleteMasterPlayer(_ playerId: UUID) {
        // Remove from current game first if selected
        if isPlayerSelectedForGame(playerId) {
            game.sweepstakePlayers.removeAll { $0.id == playerId }
            saveGame()
        }
        
        // Remove from master list
        masterPlayerList.removeAll { $0.id == playerId }
        saveMasterPlayerList()
    }
    
    func canDeletePlayer(_ playerId: UUID) -> Bool {
        // Can always delete, but if in game, it will be removed from game first
        return true
    }
    
    func isPlayerSelectedForGame(_ playerId: UUID) -> Bool {
        game.sweepstakePlayers.contains { $0.id == playerId }
    }
    
    func togglePlayerSelection(_ playerId: UUID) {
        if isPlayerSelectedForGame(playerId) {
            // Deselect - remove from game
            game.sweepstakePlayers.removeAll { $0.id == playerId }
        } else {
            // Select - add to game (only if less than 6)
            if game.sweepstakePlayers.count < 6 {
                if let player = masterPlayerList.first(where: { $0.id == playerId }) {
                    // Create a fresh copy without game-specific data
                    let newPlayer = SweepstakePlayer(
                        id: player.id,
                        name: player.name,
                        color: player.color,
                        assignedTeamMemberIds: [],
                        drawRounds: []
                    )
                    game.sweepstakePlayers.append(newPlayer)
                }
            }
        }
        saveGame()
    }
    
    private func syncSelectedPlayersWithMaster() {
        // Update selected players to match master list (by ID)
        var updatedSelected: [SweepstakePlayer] = []
        for selectedPlayer in game.sweepstakePlayers {
            if let masterPlayer = masterPlayerList.first(where: { $0.id == selectedPlayer.id }) {
                // Keep game-specific data but update name/color from master
                var updated = selectedPlayer
                updated.name = masterPlayer.name
                updated.color = masterPlayer.color
                updatedSelected.append(updated)
            }
        }
        game.sweepstakePlayers = updatedSelected
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
        // Keep master player list, just reset game selection
        initializeDefaultGame()
        saveGame()
    }
    
    // MARK: - Persistence
    
    private func saveGame() {
        persistenceService.saveGame(game)
    }
    
    private func saveMasterPlayerList() {
        persistenceService.saveMasterPlayerList(masterPlayerList)
    }
}

