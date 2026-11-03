import XCTest
@testable import Rugby_Sweepstakes_Game

@MainActor final class ScoringRegressionTests: XCTestCase {
    func testDrawAllocatesEvenlyWithoutDuplicatesForTwoSixAndFifteenPeople() {
        for count in [2, 6, 15] {
            let (model, _) = makeGame(people: count)
            XCTAssertTrue(model.game.isDrawComplete)
            let ids = model.game.sweepstakePlayers.flatMap(\.assignedTeamMemberIds)
            XCTAssertEqual(Set(ids).count, ids.count)
            XCTAssertEqual(Set(ids), Set(model.game.enabledStarters.map(\.id)))
            XCTAssertEqual(Set(model.game.sweepstakePlayers.map { $0.assignedTeamMemberIds.count }).count, 1)
        }
    }
    func testUnbalancedOrUnnamedTeamCannotDraw() {
        let (model, _) = makeGame(draw: false)
        model.runFullDraw(); XCTAssertFalse(model.game.isDrawComplete)
        model.disableRandomStartersForEvenDraw()
        let index = model.game.teamMembers.firstIndex { $0.isEnabledForGame && $0.isStarter }!
        model.game.teamMembers[index].name = ""
        model.runFullDraw(); XCTAssertFalse(model.game.isDrawComplete)
    }
    func testIncompleteImportLeavesExistingTeamIntact() {
        let (model, _) = makeGame(draw: false)
        let ids = model.game.teamMembers.map(\.id)
        model.importMatchdayTeam([ExtractedPlayer(number: 1, name: "Incomplete")])
        XCTAssertEqual(model.game.teamMembers.map(\.id), ids)
    }
    func testAllScoreTypesAndUndoPersist() {
        let (model, defaults) = makeGame()
        let root = model.game.enabledStarters[0].id
        let owner = model.participant(forBundle: root)!.id
        for event in ScoringEvent.allCases { model.adjustScoringEvent(event, for: root, by: 1) }
        XCTAssertEqual(model.game.pointsForParticipant(owner), 13)
        model.undoLastScoringAction()
        XCTAssertEqual(model.game.pointsForParticipant(owner), 10)
        let loaded = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertEqual(loaded.game.pointsForParticipant(owner), 10)
    }
    func testUndoOlderScoreKeepsLaterScore() {
        let (model, _) = makeGame()
        let roots = Array(model.game.enabledStarters.prefix(2))
        model.adjustScoringEvent(.dropGoal, for: roots[0].id, by: 1)
        let first = model.activeScoringHistory[0].id
        model.adjustScoringEvent(.tryScore, for: roots[1].id, by: 1)
        model.undoScoringEntry(first)
        XCTAssertEqual(model.game.pointsForBundle(roots[0].id), 0)
        XCTAssertEqual(model.game.pointsForBundle(roots[1].id), 5)
        XCTAssertNotNil(model.game.scoringHistory?.first?.undoneAt)
    }
    func testSuccessiveReplacementsKeepOriginalOwnerAndFieldPosition() {
        let (model, _) = makeGame()
        let starter = model.game.enabledStarters[0]
        let owner = model.participant(forBundle: starter.id)!.id
        let slot = model.onFieldMembersInPositionOrder.firstIndex { $0.id == starter.id }!
        let subs = model.game.substitutes
        model.adjustScoringEvent(.tryScore, for: starter.id, by: 1)
        model.makeSubstitution(outgoingID: starter.id, incomingID: subs[0].id)
        model.adjustScoringEvent(.tryScore, for: subs[0].id, by: 1)
        XCTAssertEqual(model.onFieldMembersInPositionOrder[slot].id, subs[0].id)
        model.makeSubstitution(outgoingID: subs[0].id, incomingID: subs[1].id)
        model.adjustScoringEvent(.dropGoal, for: subs[1].id, by: 1)
        XCTAssertEqual(model.onFieldMembersInPositionOrder[slot].id, subs[1].id)
        XCTAssertEqual(model.game.pointsForParticipant(owner), 13)
        XCTAssertEqual(model.game.allocationContributions(for: starter.id).map(\.points), [5, 5, 3])
        XCTAssertEqual(model.game.allocationContributions(for: starter.id).map(\.isOnField), [false, false, true])
    }
    func testDuplicateOnFieldReplacementIsRejected() {
        let (model, _) = makeGame()
        let roots = Array(model.game.enabledStarters.prefix(2)); let sub = model.game.substitutes[0]
        model.makeSubstitution(outgoingID: roots[0].id, incomingID: sub.id)
        model.makeSubstitution(outgoingID: roots[1].id, incomingID: sub.id)
        XCTAssertNil(model.getTeamMember(by: roots[1].id)?.linkedSubstituteId)
        XCTAssertEqual(model.game.substitutionHistory?.count, 1)
    }
    func testReplacementMovingAllocationDoesNotMoveEarlierPoints() {
        let (model, _) = makeGame()
        let roots = Array(model.game.enabledStarters.prefix(2)); let sub = model.game.substitutes[0]
        model.makeSubstitution(outgoingID: roots[0].id, incomingID: sub.id)
        model.adjustScoringEvent(.tryScore, for: sub.id, by: 1)
        model.unlinkSubstitute(from: roots[0].id)
        model.makeSubstitution(outgoingID: roots[1].id, incomingID: sub.id)
        model.adjustScoringEvent(.penalty, for: sub.id, by: 1)
        XCTAssertEqual(model.game.allocationContributions(for: roots[0].id).last?.points, 5)
        XCTAssertEqual(model.game.allocationContributions(for: roots[1].id).last?.points, 3)
        model.adjustScoringEvent(.tryScore, for: sub.id, by: -1)
        XCTAssertEqual(model.game.pointsForBundle(roots[0].id), 0)
        XCTAssertEqual(model.game.pointsForBundle(roots[1].id), 3)
    }
    func testCannotSubtractUnrecordedScore() {
        let (model, _) = makeGame(); let root = model.game.enabledStarters[0].id
        model.adjustScoringEvent(.tryScore, for: root, by: -1)
        XCTAssertEqual(model.getTeamMember(by: root)?.tryCount, 0)
        XCTAssertEqual(model.game.pointsForBundle(root), 0)
    }
    func testLegacyCombinedBaselineIsNotFalselyAssignedToOneScorer() {
        let (model, _) = makeGame(); let root = model.game.enabledStarters[0].id
        let index = model.game.teamMembers.firstIndex { $0.id == root }!
        model.game.teamMembers[index].tryCount = 2
        model.prepareScoringHistory()
        model.adjustScoringEvent(.penalty, for: root, by: 1)
        XCTAssertEqual(model.game.earlierAllocationPoints(for: root), 10)
        XCTAssertEqual(model.game.allocationContributions(for: root).first?.points, 3)
        XCTAssertEqual(model.game.pointsForBundle(root), 13)
    }
    func testOlderTeamMemberDecodesMissingDropGoals() throws {
        let member = TeamMember(name: "Legacy", isStarter: true, isSubstitute: false)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(member)) as! [String: Any]
        json.removeValue(forKey: "dropGoalCount")
        let decoded = try JSONDecoder().decode(TeamMember.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.dropGoalCount, 0)
    }
}
