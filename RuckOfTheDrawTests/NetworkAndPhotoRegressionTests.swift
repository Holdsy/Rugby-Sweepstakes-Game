import XCTest
@testable import Rugby_Sweepstakes_Game

@MainActor final class NetworkAndPhotoRegressionTests: XCTestCase {
    func testScoreAndStatusLoadAndLastKnownScoreSurvivesReload() async {
        let (defaults, _) = isolatedDefaults(); let client = HighlightlyClient(session: StubURLProtocol.session())
        let model = LiveMatchScoreModel(client: client, defaults: defaults); model.configure(matchID: 123)
        await model.refresh(key: "test-only")
        XCTAssertEqual(model.snapshot?.scorePair, ["12", "7"]); XCTAssertEqual(model.snapshot?.statusText, "First half")
        let reloaded = LiveMatchScoreModel(client: client, defaults: defaults); reloaded.configure(matchID: 123)
        XCTAssertEqual(reloaded.snapshot?.scorePair, ["12", "7"])
    }
    func testOfflineAuthQuotaServerAndInvalidResponsesKeepPreviousScore() async {
        let (defaults, _) = isolatedDefaults(); let client = HighlightlyClient(session: StubURLProtocol.session())
        let model = LiveMatchScoreModel(client: client, defaults: defaults); model.configure(matchID: 123)
        await model.refresh(key: "test-only"); let fetched = model.snapshot?.fetchedAt
        for status in [403, 429, 500] {
            StubURLProtocol.status = status; await model.refresh(key: "test-only")
            XCTAssertNotNil(model.error); XCTAssertEqual(model.snapshot?.fetchedAt, fetched); XCTAssertFalse(model.loading)
        }
        StubURLProtocol.status = 200; StubURLProtocol.failure = URLError(.notConnectedToInternet)
        await model.refresh(key: "test-only"); XCTAssertEqual(model.snapshot?.fetchedAt, fetched)
        StubURLProtocol.failure = nil; StubURLProtocol.body = Data("invalid".utf8)
        await model.refresh(key: "test-only"); XCTAssertNotNil(model.error); XCTAssertEqual(model.snapshot?.fetchedAt, fetched)
    }
    func testMissingScoreIsNotReportedAsZeroZeroAndStalenessIsDetected() {
        let missing = LiveMatchSnapshot(matchID: 1, home: "A", away: "B", score: nil, status: "Not started", fetchedAt: Date())
        XCTAssertNil(missing.scorePair)
        let malformed = LiveMatchSnapshot(matchID: 1, home: "A", away: "B", score: "12 -", status: nil, fetchedAt: Date(timeIntervalSinceNow: -121))
        XCTAssertNil(malformed.scorePair); XCTAssertEqual(malformed.statusText, "Status unavailable"); XCTAssertTrue(malformed.isStale(at: Date()))
    }
    func testSwitchingFixtureDropsAnOlderInFlightResponse() async {
        let (defaults, _) = isolatedDefaults(); let client = HighlightlyClient(session: StubURLProtocol.session())
        StubURLProtocol.delay = 0.2
        let model = LiveMatchScoreModel(client: client, defaults: defaults); model.configure(matchID: 123)
        let load = Task { await model.refresh(key: "test-only") }
        // Let the task enter refresh before changing its target.
        try? await Task.sleep(for: .milliseconds(30))
        model.configure(matchID: 456); await load.value
        XCTAssertNil(model.snapshot); XCTAssertFalse(model.loading)
    }
    func testUnlinkedGameMakesNoNetworkRequest() async {
        let (defaults, _) = isolatedDefaults(); let client = HighlightlyClient(session: StubURLProtocol.session())
        let model = LiveMatchScoreModel(client: client, defaults: defaults)
        model.configure(matchID: nil); await model.refresh(key: "test-only")
        XCTAssertEqual(StubURLProtocol.calls, 0)
    }
    func testHighlightlyCacheCanBeExplicitlyRefreshed() async throws {
        let client = HighlightlyClient(session: StubURLProtocol.session())
        _ = try await client.fixture(id: 123, key: "test-only")
        _ = try await client.fixture(id: 123, key: "test-only")
        XCTAssertEqual(StubURLProtocol.calls, 1)
        _ = try await client.fixture(id: 123, key: "test-only", refresh: true)
        XCTAssertEqual(StubURLProtocol.calls, 2)
    }
    func testPhotoMatchingRejectsWrongSportPartialNamesAndAmbiguity() throws {
        let data = Data(#"[{"idPlayer":"1","strPlayer":"Caelan Doris","strSport":"Rugby","strTeam":"Leinster","strNationality":"Ireland"}]"#.utf8)
        let players = try JSONDecoder().decode([PlayerPhotoLibrary.SportsPlayer].self, from: data)
        XCTAssertEqual(PlayerPhotoLibrary.match(name: "Caelan Doris", team: "Ireland", players: players)?.idPlayer, "1")
        XCTAssertNil(PlayerPhotoLibrary.match(name: "Doris", team: "Ireland", players: players))
        XCTAssertNil(PlayerPhotoLibrary.match(name: "Caelan Doris", team: "Bath Rugby", players: players))
        XCTAssertNil(PlayerPhotoLibrary.match(name: "Caelan Doris", team: "Ireland", players: players + players))
        let football = try JSONDecoder().decode([PlayerPhotoLibrary.SportsPlayer].self, from: Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "Rugby", with: "Soccer").utf8))
        XCTAssertNil(PlayerPhotoLibrary.match(name: "Caelan Doris", team: "Ireland", players: football))
    }
    func testTransparentPhotoPreferredAndConfirmedMatchCached() async {
        let session = StubURLProtocol.session(); let (defaults, _) = isolatedDefaults()
        StubURLProtocol.body = Data(#"{"player":[{"idPlayer":"1","strPlayer":"Caelan Doris","strSport":"Rugby","strTeam":"Leinster","strNationality":"Ireland","strThumb":"https://example.com/photo.jpg","strCutout":"https://example.com/cutout.png"}]}"#.utf8)
        let library = PlayerPhotoLibrary(defaults: defaults, session: session)
        let url = await library.sportsPhoto(name: "Caelan Doris", team: "Ireland")
        XCTAssertEqual(url?.lastPathComponent, "cutout.png")
        let cached = await PlayerPhotoLibrary(defaults: defaults, session: session).sportsPhoto(name: "Caelan Doris", team: "Ireland")
        XCTAssertEqual(cached, url); XCTAssertEqual(StubURLProtocol.calls, 1)
    }
    func testSquadPageParserHandlesMultiwordNamesAndIgnoresLogo() {
        let page = """
        ![Image 1: Josh Vanderflier](https://example.com/josh.png)
        Josh
        van der Flier
        ## Prop
        ![Image 2: Tadhg Furlong](https://example.com/tadhg.png)
        Tadhg
        Furlong
        ![Image 3: Sponsor Logo](https://example.com/logo.png)
        Sponsor
        Logo
        """
        XCTAssertEqual(PlayerPhotoLibrary.players(from: page).map(\.name), ["Josh van der Flier", "Tadhg Furlong"])
        XCTAssertEqual(EnglandPlayerNameMatcher.key("Tom O’Toole"), EnglandPlayerNameMatcher.key("Tom O'Toole"))
        XCTAssertEqual(EnglandPlayerNameMatcher.key("Oliver Chessum"), EnglandPlayerNameMatcher.key("Ollie Chessum"))
    }
    func testPhotoPageSettingsPersistAndRejectInvalidLinks() throws {
        let (defaults, _) = isolatedDefaults(); let library = PlayerPhotoLibrary(defaults: defaults)
        try library.add(team: "Bath Rugby", urlString: "https://www.bathrugby.com/teams/men")
        XCTAssertEqual(PlayerPhotoLibrary(defaults: defaults).sources.count, 3)
        XCTAssertThrowsError(try library.add(team: "Unsafe", urlString: "http://example.com"))
        XCTAssertThrowsError(try library.add(team: "Bath Rugby", urlString: "https://www.bathrugby.com/teams/men"))
    }
}
