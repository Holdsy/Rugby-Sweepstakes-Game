//
//  GamePersistenceService.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

class GamePersistenceService {
    private let gameKey = "rugby_sweepstake_game"
    
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
}

