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
    var tryCount: Int
    var penaltyCount: Int
    var conversionCount: Int
    var dropGoalCount: Int

    var points: Int {
        (tryCount * 5) + (penaltyCount * 3) + (conversionCount * 2) + (dropGoalCount * 3)
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        position: String? = nil,
        isStarter: Bool,
        isSubstitute: Bool,
        isEnabledForGame: Bool = true,
        linkedSubstituteId: UUID? = nil,
        tryCount: Int = 0,
        penaltyCount: Int = 0,
        conversionCount: Int = 0,
        dropGoalCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.isStarter = isStarter
        self.isSubstitute = isSubstitute
        self.isEnabledForGame = isEnabledForGame
        self.linkedSubstituteId = linkedSubstituteId
        self.tryCount = tryCount
        self.penaltyCount = penaltyCount
        self.conversionCount = conversionCount
        self.dropGoalCount = dropGoalCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        isStarter = try container.decode(Bool.self, forKey: .isStarter)
        isSubstitute = try container.decode(Bool.self, forKey: .isSubstitute)
        isEnabledForGame = try container.decode(Bool.self, forKey: .isEnabledForGame)
        linkedSubstituteId = try container.decodeIfPresent(UUID.self, forKey: .linkedSubstituteId)
        tryCount = try container.decodeIfPresent(Int.self, forKey: .tryCount) ?? 0
        penaltyCount = try container.decodeIfPresent(Int.self, forKey: .penaltyCount) ?? 0
        conversionCount = try container.decodeIfPresent(Int.self, forKey: .conversionCount) ?? 0
        dropGoalCount = try container.decodeIfPresent(Int.self, forKey: .dropGoalCount) ?? 0
    }
    
    // Helper to get display name with linked substitute
    func displayName(linkedSubstitute: TeamMember?) -> String {
        if let substitute = linkedSubstitute {
            return "\(name) (\(substitute.name) on)"
        }
        return name
    }
}

