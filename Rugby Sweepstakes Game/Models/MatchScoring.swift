import Foundation

enum ScoringEvent: String, Codable, CaseIterable, Identifiable {
    case tryScore, penalty, conversion, dropGoal
    var id: String { rawValue }
    var description: String {
        switch self {
        case .tryScore: "Try"
        case .penalty: "Penalty"
        case .conversion: "Conversion"
        case .dropGoal: "Drop Goal"
        }
    }
    var points: Int {
        switch self {
        case .tryScore: 5
        case .penalty: 3
        case .conversion: 2
        case .dropGoal: 3
        }
    }
}

/// Immutable attribution: later substitution changes cannot transfer these points.
struct MatchScoreEntry: Codable, Identifiable {
    var id = UUID()
    var recordedAt = Date()
    let teamMemberID: UUID
    let bundleID: UUID?
    let participantID: UUID?
    let event: ScoringEvent
    let countChange: Int
    var undoneAt: Date?
    var correctionOfID: UUID?
    var points: Int { event.points * countChange }
}

/// Preserve totals from games created before event history was available.
struct ScoringBaseline: Codable {
    let bundleID: UUID
    let points: Int
}

struct MatchSubstitutionEntry: Codable, Identifiable {
    var id = UUID()
    var recordedAt = Date()
    let starterID: UUID
    let replacementID: UUID
    let isReturn: Bool
    var outgoingPlayerID: UUID?

    init(starterID: UUID, replacementID: UUID, isReturn: Bool, outgoingPlayerID: UUID? = nil) {
        self.starterID = starterID; self.replacementID = replacementID
        self.isReturn = isReturn; self.outgoingPlayerID = outgoingPlayerID
    }
}

/// A lineup correction changes the name in a shirt slot, never its allocation identity.
struct MatchTeamAmendment: Codable, Identifiable {
    var id = UUID()
    var recordedAt = Date()
    let memberID: UUID
    let shirtNumber: Int
    let previousName: String
    let newName: String
}
