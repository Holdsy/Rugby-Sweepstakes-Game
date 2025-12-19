//
//  TeamMember.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation

struct TeamMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var position: String?
    var isStarter: Bool
    var isSubstitute: Bool
    var isEnabledForGame: Bool // Only meaningful for starters
    var linkedSubstituteId: UUID? // The substitute associated with this starter
    var points: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        position: String? = nil,
        isStarter: Bool,
        isSubstitute: Bool,
        isEnabledForGame: Bool = true,
        linkedSubstituteId: UUID? = nil,
        points: Int = 0
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.isStarter = isStarter
        self.isSubstitute = isSubstitute
        self.isEnabledForGame = isEnabledForGame
        self.linkedSubstituteId = linkedSubstituteId
        self.points = points
    }
    
    // Helper to get display name with linked substitute
    func displayName(linkedSubstitute: TeamMember?) -> String {
        if let substitute = linkedSubstitute {
            return "\(name) (\(substitute.name) on)"
        }
        return name
    }
}



