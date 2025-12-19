//
//  Allocation.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

struct Allocation: Identifiable, Codable, Hashable {
    let id: UUID
    var roundNumber: Int
    var sweepstakePlayerId: UUID
    var teamMemberId: UUID
    
    init(
        id: UUID = UUID(),
        roundNumber: Int,
        sweepstakePlayerId: UUID,
        teamMemberId: UUID
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.sweepstakePlayerId = sweepstakePlayerId
        self.teamMemberId = teamMemberId
    }
}



