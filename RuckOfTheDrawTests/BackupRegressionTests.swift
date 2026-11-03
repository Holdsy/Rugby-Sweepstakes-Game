import XCTest
@testable import Rugby_Sweepstakes_Game

@MainActor final class BackupRegressionTests: XCTestCase {
    func testBackupRoundTripIncludesHistoryScoresDraftsAndPhotoPages() throws {
        let (model, defaults) = makeGame(); let root = model.game.enabledStarters[0].id
        model.adjustScoringEvent(.tryScore, for: root, by: 1); XCTAssertTrue(model.finishGame())
        let store = TeamDraftStore(defaults: defaults)
        try store.save(gameID: model.game.id, matchID: 123, fixtureName: "Draft Match", fixtureDate: nil, teamName: "Ireland", isSample: false, names: ["One name"] + Array(repeating: "", count: 22), sourceNote: "Photo")
        let file = try backup(from: model, defaults: defaults)
        let decoded = try AppBackupService.decode(AppBackupService.encode(file))
        XCTAssertEqual(decoded.state.game.pointsForBundle(root), 5)
        XCTAssertEqual(decoded.state.savedGames.first?.id, model.game.id)
        XCTAssertEqual(decoded.drafts.first?.namedCount, 1)
        XCTAssertEqual(Set(decoded.photoSources.map(\.team)), Set(["England", "Ireland"]))
    }
    func testRestorePersistsAllManagedRecordsAndPreservesUnrelatedSettings() throws {
        let (model, defaults) = makeGame(); let file = try backup(from: model, defaults: defaults)
        let (target, domain) = isolatedDefaults()
        target.set("keep", forKey: "unrelated")
        target.set(Data("old cache".utf8), forKey: "rugby_player_photo_matches_v1")
        try AppBackupService.apply(file, defaults: target, domain: domain)
        let loaded = GameViewModel(persistenceService: GamePersistenceService(defaults: target))
        XCTAssertEqual(loaded.game.id, model.game.id)
        XCTAssertEqual(loaded.game.sweepstakePlayers.map(\.assignedTeamMemberIds), model.game.sweepstakePlayers.map(\.assignedTeamMemberIds))
        XCTAssertEqual(target.string(forKey: "unrelated"), "keep")
        XCTAssertNil(target.data(forKey: "rugby_player_photo_matches_v1"))
        XCTAssertEqual(PlayerPhotoLibrary(defaults: target).sources.count, 2)
    }
    func testExportExcludesCredentialsAndUnrelatedDefaults() throws {
        let (model, defaults) = makeGame()
        defaults.set("PRIVATE_CREDENTIAL_SENTINEL", forKey: "api-key")
        let data = try AppBackupService.encode(backup(from: model, defaults: defaults))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("PRIVATE_CREDENTIAL_SENTINEL"))
    }
    func testFutureVersionAndBrokenReferencesDoNotWrite() throws {
        let (model, defaults) = makeGame(); var file = try backup(from: model, defaults: defaults)
        let (target, domain) = isolatedDefaults(); target.set("original", forKey: "sentinel")
        let original = target.persistentDomain(forName: domain)!
        file.version = 99
        XCTAssertThrowsError(try AppBackupService.apply(file, defaults: target, domain: domain))
        file.version = 1
        var broken = file.state.game; broken.sweepstakePlayers[0].assignedTeamMemberIds = [UUID()]
        file.state = SavedGameState(game: broken, savedGames: [])
        XCTAssertThrowsError(try AppBackupService.apply(file, defaults: target, domain: domain))
        XCTAssertTrue(NSDictionary(dictionary: target.persistentDomain(forName: domain)!).isEqual(to: original))
    }
    func testMalformedAndOversizedBackupsAreRejected() {
        XCTAssertThrowsError(try AppBackupService.decode(Data("wrong file".utf8)))
        XCTAssertThrowsError(try AppBackupService.decode(Data(repeating: 0, count: 20 * 1024 * 1024 + 1)))
    }
    func testRecoveryCopyCanRestorePreviousData() throws {
        let (model, defaults) = makeGame()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = try AppBackupService.recoveryFile(state: SavedGameState(game: model.game, savedGames: []), participants: model.masterPlayerList, defaults: defaults, directory: folder)
        let previous = try AppBackupService.decode(Data(contentsOf: url))
        XCTAssertEqual(previous.state.game.id, model.game.id)
    }
    func testUnreadableOriginalDataIsPreservedExactlyInRecoveryCopy() throws {
        let (defaults, _) = isolatedDefaults(); let raw = Data("unreadable original".utf8)
        defaults.set(raw, forKey: "rugby_sweepstake_state_v1")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = try AppBackupService.recoveryFile(state: nil, participants: [], defaults: defaults, directory: folder)
        let records = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
        XCTAssertEqual(records["rugby_sweepstake_state_v1"] as? Data, raw)
    }
}
