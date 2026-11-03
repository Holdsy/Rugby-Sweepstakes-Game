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
}
private final class FailingPersistence: GamePersistenceService {
    var fail = false
    override func saveState(game: Game, savedGames: [Game]) throws {
        if fail { throw CocoaError(.fileWriteUnknown) }
        try super.saveState(game: game, savedGames: savedGames)
    }
}
