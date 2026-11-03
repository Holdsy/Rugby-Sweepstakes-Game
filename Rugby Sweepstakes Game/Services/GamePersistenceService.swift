//
//  GamePersistenceService.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

class GamePersistenceService {
    private let stateKey = "rugby_sweepstake_state_v1"
    private let gameKey = "rugby_sweepstake_game"
    private let masterPlayersKey = "rugby_sweepstake_master_players"
    private let englandSquadKey = "rugby_sweepstake_england_squad"
    private let englandSquadImportDateKey = "rugby_sweepstake_england_squad_import_date"
    
    /// One encoded value keeps current game and history together when switching games.
    func saveState(game: Game, savedGames: [Game]) throws {
        let data = try JSONEncoder().encode(SavedGameState(game: game, savedGames: savedGames))
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    func loadState() throws -> SavedGameState? {
        if let data = UserDefaults.standard.data(forKey: stateKey) {
            let state = try JSONDecoder().decode(SavedGameState.self, from: data)
            guard state.version == 1 else { throw CocoaError(.coderReadCorrupt) }
            return state
        }
        // Keep the original legacy save intact during migration.
        if let data = UserDefaults.standard.data(forKey: gameKey) {
            return SavedGameState(game: try JSONDecoder().decode(Game.self, from: data), savedGames: [])
        }
        return nil
    }

    func saveGame(_ game: Game) {
        if let encoded = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(encoded, forKey: gameKey)
        }
    }
    
    func loadGame() -> Game? {
        guard let data = UserDefaults.standard.data(forKey: gameKey),
              let game = try? JSONDecoder().decode(Game.self, from: data) else {
            return nil
        }
        return game
    }
    
    func clearGame() {
        UserDefaults.standard.removeObject(forKey: gameKey)
    }
    
    // MARK: - Master Player List Persistence
    
    func saveMasterPlayerList(_ players: [SweepstakePlayer]) {
        if let encoded = try? JSONEncoder().encode(players) {
            UserDefaults.standard.set(encoded, forKey: masterPlayersKey)
        }
    }
    
    func loadMasterPlayerList() -> [SweepstakePlayer] {
        guard let data = UserDefaults.standard.data(forKey: masterPlayersKey),
              let players = try? JSONDecoder().decode([SweepstakePlayer].self, from: data) else {
            return []
        }
        return players
    }

    func saveEnglandSquad(_ players: [EnglandSquadPlayer], importedAt: Date) {
        if let encoded = try? JSONEncoder().encode(players) {
            UserDefaults.standard.set(encoded, forKey: englandSquadKey)
            UserDefaults.standard.set(importedAt, forKey: englandSquadImportDateKey)
        }
    }

    func loadEnglandSquad() -> (players: [EnglandSquadPlayer], importedAt: Date?) {
        guard let data = UserDefaults.standard.data(forKey: englandSquadKey),
              let players = try? JSONDecoder().decode([EnglandSquadPlayer].self, from: data) else {
            return ([], nil)
        }
        return (players, UserDefaults.standard.object(forKey: englandSquadImportDateKey) as? Date)
    }
}
