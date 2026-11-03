import XCTest
@testable import Rugby_Sweepstakes_Game

@MainActor final class HistoryAndDraftRegressionTests: XCTestCase {
    func testCompletedGameLocksScoringAndSubstitutions() {
        let (model, _) = makeGame(); let root = model.game.enabledStarters[0].id
        model.adjustScoringEvent(.tryScore, for: root, by: 1)
        XCTAssertTrue(model.finishGame())
        model.adjustScoringEvent(.penalty, for: root, by: 1)
        model.undoLastScoringAction()
        model.makeSubstitution(outgoingID: root, incomingID: model.game.substitutes[0].id)
        XCTAssertEqual(model.game.pointsForBundle(root), 5)
        XCTAssertNil(model.getTeamMember(by: root)?.linkedSubstituteId)
        XCTAssertFalse(model.finishGame())
    }
    func testStartingNewGameArchivesAndReopeningKeepsScores() {
        let (model, _) = makeGame(); let id = model.game.id, root = model.game.enabledStarters[0].id
        model.adjustScoringEvent(.tryScore, for: root, by: 1)
        XCTAssertTrue(model.finishGame()); XCTAssertTrue(model.resetGame())
        XCTAssertNotEqual(model.game.id, id)
        XCTAssertEqual(model.savedGames.filter { $0.id == id }.count, 1)
        XCTAssertTrue(model.reopenGame(id))
        XCTAssertFalse(model.game.isCompleted)
        XCTAssertEqual(model.game.pointsForBundle(root), 5)
    }
    func testSavedResultsKeepNamesWhenPeopleAreRenamed() {
        let (model, _) = makeGame(); let original = model.game.sweepstakePlayers[0]
        XCTAssertTrue(model.finishGame())
        var renamed = model.masterPlayerList.first { $0.id == original.id }!; renamed.name = "New Name"
        model.updateSweepstakePlayer(renamed)
        XCTAssertEqual(model.savedGames.first?.sweepstakePlayers.first { $0.id == original.id }?.name, original.name)
    }
    func testCorruptSaveIsPreservedAndBlocksWrites() {
        let (defaults, _) = isolatedDefaults(); let corrupt = Data("broken save".utf8)
        defaults.set(corrupt, forKey: "rugby_sweepstake_state_v1")
        let model = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertTrue(model.storageWritesBlocked)
        XCTAssertFalse(model.resetGame())
        XCTAssertEqual(defaults.data(forKey: "rugby_sweepstake_state_v1"), corrupt)
    }
    func testLegacyGameMigratesWithoutDeletingOriginal() throws {
        let (model, _) = makeGame(); let (defaults, _) = isolatedDefaults()
        let data = try JSONEncoder().encode(model.game)
        defaults.set(data, forKey: "rugby_sweepstake_game")
        let loaded = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertEqual(loaded.game.id, model.game.id)
        XCTAssertEqual(defaults.data(forKey: "rugby_sweepstake_game"), data)
        XCTAssertNotNil(defaults.data(forKey: "rugby_sweepstake_state_v1"))
    }
    func testFailedSaveRollsBackGameSwitch() {
        let (model, _) = makeGame(); let (defaults, _) = isolatedDefaults()
        let persistence = FailingPersistence(defaults: defaults)
        try! persistence.saveState(game: model.game, savedGames: [])
        let other = GameViewModel(persistenceService: persistence); let id = other.game.id
        persistence.fail = true
        XCTAssertFalse(other.resetGame()); XCTAssertEqual(other.game.id, id); XCTAssertTrue(other.savedGames.isEmpty)
    }
    func testPartialDraftPersistsAndContextsStaySeparate() throws {
        let (defaults, _) = isolatedDefaults(); let store = TeamDraftStore(defaults: defaults), game = UUID()
        let first = try store.save(gameID: game, matchID: 1, fixtureName: "Match", fixtureDate: nil, teamName: "Ireland", isSample: false, names: ["Tadhg Furlong"] + Array(repeating: "", count: 22), sourceNote: "From photo")
        let loaded = TeamDraftStore(defaults: defaults)
        XCTAssertEqual(loaded.drafts(for: game).first?.namedCount, 1)
        XCTAssertEqual(loaded.drafts.first?.sourceNote, "From photo")
        XCTAssertNil(loaded.find(gameID: UUID(), matchID: 1, fixtureName: "Match", fixtureDate: nil, teamName: "Ireland", isSample: false))
        XCTAssertNil(loaded.find(gameID: game, matchID: 1, fixtureName: "Match", fixtureDate: nil, teamName: "Argentina", isSample: false))
        XCTAssertNil(loaded.find(gameID: game, matchID: 1, fixtureName: "Match", fixtureDate: nil, teamName: "Ireland", isSample: true))
        let updated = try loaded.save(gameID: game, matchID: 1, fixtureName: "Match", fixtureDate: nil, teamName: "Ireland", isSample: false, names: Array(repeating: "Name", count: 23), sourceNote: nil)
        XCTAssertEqual(updated.id, first.id); XCTAssertEqual(loaded.drafts.count, 1)
    }
    func testDeletingDraftLeavesOtherDraftsAndSavedGameUntouched() throws {
        let (model, defaults) = makeGame(); let before = defaults.data(forKey: "rugby_sweepstake_state_v1")
        let store = TeamDraftStore(defaults: defaults)
        let names = Array(repeating: "", count: 23)
        let a = try store.save(gameID: model.game.id, matchID: 1, fixtureName: nil, fixtureDate: nil, teamName: "Ireland", isSample: false, names: names, sourceNote: nil)
        let b = try store.save(gameID: model.game.id, matchID: 2, fixtureName: nil, fixtureDate: nil, teamName: "England", isSample: false, names: names, sourceNote: nil)
        try store.remove(id: a.id)
        XCTAssertEqual(TeamDraftStore(defaults: defaults).drafts.map(\.id), [b.id])
        XCTAssertEqual(defaults.data(forKey: "rugby_sweepstake_state_v1"), before)
    }
    func testCorruptDraftCannotBeOverwritten() {
        let (defaults, _) = isolatedDefaults(); let data = Data("bad draft".utf8)
        defaults.set(data, forKey: "rugby_team_lineup_drafts_v1")
        let store = TeamDraftStore(defaults: defaults)
        XCTAssertThrowsError(try store.save(gameID: UUID(), matchID: nil, fixtureName: nil, fixtureDate: nil, teamName: "Ireland", isSample: false, names: Array(repeating: "", count: 23), sourceNote: nil))
        XCTAssertEqual(defaults.data(forKey: "rugby_team_lineup_drafts_v1"), data)
    }
    func testAmendStarterAndBenchPreservesDrawScoresLinksAndPersistsAudit() throws {
        let (model, defaults) = makeGame()
        let root = model.game.enabledStarters[0], bench = model.game.substitutes[0]
        model.adjustScoringEvent(.tryScore, for: root.id, by: 1)
        let score = try XCTUnwrap(model.game.scoringHistory?.last)
        model.makeSubstitution(outgoingID: root.id, incomingID: bench.id)
        let ids = model.game.teamMembers.map(\.id)
        let allocations = model.game.sweepstakePlayers.map(\.assignedTeamMemberIds)
        var names = Dictionary(uniqueKeysWithValues: model.game.teamMembers.map { ($0.id, $0.name) })
        names[root.id] = "Late Starting Player"; names[bench.id] = "Late Bench Player"
        XCTAssertTrue(model.amendMatchDayTeam(names: names))
        XCTAssertEqual(model.game.teamMembers.map(\.id), ids)
        XCTAssertEqual(model.game.sweepstakePlayers.map(\.assignedTeamMemberIds), allocations)
        XCTAssertEqual(model.game.pointsForBundle(root.id), 5)
        XCTAssertEqual(model.getTeamMember(by: root.id)?.linkedSubstituteId, bench.id)
        XCTAssertEqual(model.game.recordedPlayerName(root.id, at: score.recordedAt), root.name)
        XCTAssertEqual(model.game.teamAmendments?.count, 2)
        let loaded = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertEqual(loaded.getTeamMember(by: root.id)?.name, "Late Starting Player")
        XCTAssertEqual(loaded.game.teamAmendments?.count, 2)
        model.adjustScoringEvent(.conversion, for: bench.id, by: 1)
        XCTAssertEqual(model.game.pointsForBundle(root.id), 7)
        model.undoScoringEntry(score.id)
        XCTAssertEqual(model.game.pointsForBundle(root.id), 2)
        let backup = try backup(from: model, defaults: defaults)
        let data = try JSONEncoder().encode(backup)
        XCTAssertNotNil(String(data: data, encoding: .utf8)?.range(of: "Late Starting Player"))
    }
    func testAmendAllowsStarterBenchSwapAndKeepsExcludedSlotsExcluded() {
        let (model, _) = makeGame()
        let starter = model.game.starters[0], bench = model.game.substitutes[0]
        let flags = model.game.teamMembers.map(\.isEnabledForGame)
        var names = Dictionary(uniqueKeysWithValues: model.game.teamMembers.map { ($0.id, $0.name) })
        names[starter.id] = bench.name; names[bench.id] = starter.name
        XCTAssertTrue(model.amendMatchDayTeam(names: names))
        XCTAssertEqual(model.getTeamMember(by: starter.id)?.name, bench.name)
        XCTAssertEqual(model.getTeamMember(by: bench.id)?.name, starter.name)
        XCTAssertEqual(model.game.teamMembers.map(\.isEnabledForGame), flags)
        XCTAssertTrue(model.amendMatchDayTeam(names: names))
        XCTAssertEqual(model.game.teamAmendments?.count, 2)
    }
    func testAmendRejectsInvalidNamesWrongSlotsBeforeDrawAndCompletedGame() {
        let (model, _) = makeGame()
        let original = Dictionary(uniqueKeysWithValues: model.game.teamMembers.map { ($0.id, $0.name) })
        var names = original; let id = model.game.starters[0].id
        names[id] = "  "
        XCTAssertFalse(model.amendMatchDayTeam(names: names))
        names[id] = model.game.substitutes[0].name.uppercased()
        XCTAssertFalse(model.amendMatchDayTeam(names: names))
        names = original; names.removeValue(forKey: id); names[UUID()] = "Wrong ID"
        XCTAssertFalse(model.amendMatchDayTeam(names: names))
        XCTAssertNil(model.game.teamAmendments)
        let (beforeDraw, _) = makeGame(draw: false)
        XCTAssertFalse(beforeDraw.amendMatchDayTeam(names: Dictionary(uniqueKeysWithValues: beforeDraw.game.teamMembers.map { ($0.id, $0.name) })))
        XCTAssertTrue(model.finishGame())
        names = original; names[id] = "New Player"
        XCTAssertFalse(model.amendMatchDayTeam(names: names))
        XCTAssertEqual(model.getTeamMember(by: id)?.name, original[id])
    }
    func testAmendFailedSaveRollsBackNamesAndAudit() throws {
        let (model, _) = makeGame(); let (defaults, _) = isolatedDefaults()
        let persistence = FailingPersistence(defaults: defaults)
        try persistence.saveState(game: model.game, savedGames: [])
        let other = GameViewModel(persistenceService: persistence)
        let member = other.game.starters[0]
        var names = Dictionary(uniqueKeysWithValues: other.game.teamMembers.map { ($0.id, $0.name) })
        names[member.id] = "Replacement Name"; persistence.fail = true
        XCTAssertFalse(other.amendMatchDayTeam(names: names))
        XCTAssertEqual(other.getTeamMember(by: member.id)?.name, member.name)
        XCTAssertNil(other.game.teamAmendments)
    }
    func testLegacyGameWithoutAmendmentsDecodesAndRepeatedAmendmentsKeepHistoricalNames() throws {
        let (model, _) = makeGame(); let member = model.game.enabledStarters[0]
        let oldDate = Date().addingTimeInterval(-10)
        var names = Dictionary(uniqueKeysWithValues: model.game.teamMembers.map { ($0.id, $0.name) })
        names[member.id] = "First Correction"; XCTAssertTrue(model.amendMatchDayTeam(names: names))
        let middle = Date()
        names[member.id] = "Second Correction"; XCTAssertTrue(model.amendMatchDayTeam(names: names))
        XCTAssertEqual(model.game.recordedPlayerName(member.id, at: oldDate), member.name)
        XCTAssertEqual(model.game.recordedPlayerName(member.id, at: middle), "First Correction")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(model.game)) as? [String: Any])
        json.removeValue(forKey: "teamAmendments")
        let legacy = try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.teamAmendments)
    }

    func testSeventhSavedPersonAndGameSelectionSurviveRelaunchIndependently() {
        let (model, defaults) = makeGame(draw: false)
        let id = model.addMasterPlayer(name: "Seventh Person")
        XCTAssertEqual(model.masterPlayerList.count, 7)
        XCTAssertFalse(model.isPlayerSelectedForGame(id))
        model.togglePlayerSelection(id)
        let loaded = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertEqual(loaded.masterPlayerList.count, 7)
        XCTAssertTrue(loaded.isPlayerSelectedForGame(id))
        loaded.togglePlayerSelection(id)
        let again = GameViewModel(persistenceService: GamePersistenceService(defaults: defaults))
        XCTAssertEqual(again.masterPlayerList.count, 7)
        XCTAssertFalse(again.isPlayerSelectedForGame(id))
        XCTAssertEqual(again.game.sweepstakePlayers.count, 6)
    }
    func testSavedPeopleCanBeAddedAfterDrawWithoutChangingAllocation() {
        let (model, defaults) = makeGame()
        let allocations = model.game.sweepstakePlayers.map(\.assignedTeamMemberIds)
        let id = model.addMasterPlayer(name: "Next Game Person")
        model.togglePlayerSelection(id)
        XCTAssertFalse(model.isPlayerSelectedForGame(id))
        XCTAssertEqual(model.game.sweepstakePlayers.map(\.assignedTeamMemberIds), allocations)
        XCTAssertTrue(GameViewModel(persistenceService: GamePersistenceService(defaults: defaults)).masterPlayerList.contains { $0.id == id })
    }
    func testGameSelectionLimitDoesNotLimitSavedPeople() {
        let (model, _) = makeGame(people: 15, draw: false)
        let id = model.addMasterPlayer(name: "Sixteenth Person")
        model.togglePlayerSelection(id)
        XCTAssertEqual(model.masterPlayerList.count, 16)
        XCTAssertFalse(model.isPlayerSelectedForGame(id))
        model.togglePlayerSelection(model.game.sweepstakePlayers[0].id)
        model.togglePlayerSelection(id)
        XCTAssertTrue(model.isPlayerSelectedForGame(id))
        XCTAssertEqual(model.game.sweepstakePlayers.count, 15)
    }
    func testFailedSelectionSaveRollsBackSwitchState() throws {
        let (model, _) = makeGame(draw: false); let (defaults, _) = isolatedDefaults()
        let persistence = FailingPersistence(defaults: defaults)
        persistence.saveMasterPlayerList(model.masterPlayerList)
        try persistence.saveState(game: model.game, savedGames: [])
        let other = GameViewModel(persistenceService: persistence)
        let id = other.game.sweepstakePlayers[0].id
        persistence.fail = true; other.togglePlayerSelection(id)
        XCTAssertTrue(other.isPlayerSelectedForGame(id))
        XCTAssertNotNil(other.persistenceError)
    }

}
private final class FailingPersistence: GamePersistenceService {
    var fail = false
    override func saveState(game: Game, savedGames: [Game]) throws {
        if fail { throw CocoaError(.fileWriteUnknown) }
        try super.saveState(game: game, savedGames: savedGames)
    }
}
