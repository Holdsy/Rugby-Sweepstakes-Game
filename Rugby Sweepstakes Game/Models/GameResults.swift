import Foundation

/// Shared calculations for the current game and read-only saved results.
extension Game {
    func recordedPlayerName(_ id: UUID, at date: Date) -> String {
        (teamAmendments ?? []).filter { $0.memberID == id && $0.recordedAt >= date }
            .sorted { $0.recordedAt < $1.recordedAt }.first?.previousName
            ?? teamMembers.first { $0.id == id }?.name ?? "Player"
    }

    var isCompleted: Bool { completedAt != nil }
    var hasGameContent: Bool { isDrawComplete || teamMembers.contains { !$0.name.isEmpty || $0.points != 0 } }
    var displayTitle: String {
        let title = [fixtureName, name, selectedTeamName].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.first { !$0.isEmpty } ?? "Ruck of the Draw"
        guard let fixtureDate, !fixtureDate.isEmpty else { return title }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date: Date?
        if let timestamp = parser.date(from: fixtureDate) ?? ISO8601DateFormatter().date(from: fixtureDate) {
            date = timestamp
        } else {
            let dayParser = DateFormatter()
            dayParser.locale = Locale(identifier: "en_US_POSIX")
            dayParser.dateFormat = "yyyy-MM-dd"
            dayParser.isLenient = false
            date = dayParser.date(from: fixtureDate)
        }
        guard let date else { return title }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy"
        return "\(title) · \(formatter.string(from: date))"
    }

    func pointsForBundle(_ id: UUID) -> Int {
        if let scoringBaseline {
            return (scoringBaseline.first { $0.bundleID == id }?.points ?? 0)
                + (scoringHistory ?? []).filter { $0.bundleID == id && $0.undoneAt == nil }.reduce(0) { $0 + $1.points }
        }
        guard let member = teamMembers.first(where: { $0.id == id }) else { return 0 }
        return member.points + (teamMembers.first { $0.id == member.linkedSubstituteId }?.points ?? 0)
    }

    func pointsForParticipant(_ id: UUID) -> Int {
        sweepstakePlayers.first { $0.id == id }?.assignedTeamMemberIds.reduce(0) { $0 + pointsForBundle($1) } ?? 0
    }

    var rankedParticipants: [SweepstakePlayer] {
        sweepstakePlayers.sorted {
            let lhs = pointsForParticipant($0.id), rhs = pointsForParticipant($1.id)
            if lhs != rhs { return lhs > rhs }
            let order = $0.name.localizedCaseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }

    func participantRank(_ id: UUID) -> Int {
        1 + sweepstakePlayers.filter { pointsForParticipant($0.id) > pointsForParticipant(id) }.count
    }

    var winningParticipants: [SweepstakePlayer] {
        guard let first = rankedParticipants.first else { return [] }
        return rankedParticipants.filter { pointsForParticipant($0.id) == pointsForParticipant(first.id) }
    }

    var resultsShareText: String {
        var lines = ["Ruck of the Draw — \(isCompleted ? "Final Results" : "Current Standings")", displayTitle]
        if let selectedTeamName { lines.append("Following \(selectedTeamName)") }
        if isCompleted, !winningParticipants.isEmpty {
            lines.append("\(winningParticipants.count == 1 ? "Winner" : "Joint winners"): \(winningParticipants.map(\.name).joined(separator: ", "))")
        }
        for participant in rankedParticipants {
            lines.append("\(participantRank(participant.id)). \(participant.name): \(pointsForParticipant(participant.id)) pts")
        }
        return lines.joined(separator: "\n")
    }
}

struct SavedGameState: Codable {
    var version = 1
    let game: Game
    let savedGames: [Game]
}

struct AllocationScoreContribution: Identifiable {
    var id: UUID { member.id }
    let member: TeamMember
    let points: Int
    let isReplacement: Bool
    let isOnField: Bool
}

extension Game {
    /// Use the score receipt's allocation, not the player's lifetime counters: a substitute can move between allocations.
    func allocationContributions(for bundleID: UUID) -> [AllocationScoreContribution] {
        guard let starter = teamMembers.first(where: { $0.id == bundleID }) else { return [] }
        var ids = [bundleID]
        if scoringBaseline != nil {
            ids += (substitutionHistory ?? []).filter { $0.starterID == bundleID }.map(\.replacementID)
            ids += (scoringHistory ?? []).filter { $0.bundleID == bundleID }.map(\.teamMemberID)
        }
        if let current = starter.linkedSubstituteId { ids.append(current) }
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }.compactMap { id in
            guard let member = teamMembers.first(where: { $0.id == id }) else { return nil }
            let points = scoringBaseline == nil ? member.points : (scoringHistory ?? [])
                .filter { $0.bundleID == bundleID && $0.teamMemberID == id && $0.undoneAt == nil }
                .reduce(0) { $0 + $1.points }
            return AllocationScoreContribution(member: member, points: points, isReplacement: id != bundleID,
                isOnField: id == bundleID ? starter.linkedSubstituteId == nil : starter.linkedSubstituteId == id)
        }
    }
    func earlierAllocationPoints(for bundleID: UUID) -> Int {
        scoringBaseline?.first { $0.bundleID == bundleID }?.points ?? 0
    }
}
