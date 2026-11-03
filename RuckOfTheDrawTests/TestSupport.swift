import XCTest
@testable import Rugby_Sweepstakes_Game

@MainActor
extension XCTestCase {
    func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "RuckRegression-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return (defaults, suite)
    }
    func makeGame(people: Int = 6, draw: Bool = true) -> (GameViewModel, UserDefaults) {
        let (defaults, _) = isolatedDefaults()
        let persistence = GamePersistenceService(defaults: defaults)
        persistence.saveMasterPlayerList((0..<people).map { SweepstakePlayer(name: "Person \($0 + 1)", color: .color(at: $0)) })
        let model = GameViewModel(persistenceService: persistence)
        model.importMatchdayTeam((1...23).map { (number: Int) in ExtractedPlayer(number: number, name: "Rugby Player \(number)") }, fixtureName: "Ireland v Argentina", teamName: "Ireland", fixtureDate: "2026-11-06T20:10:00.000Z", providerMatchID: 45300365, providerName: "Highlightly")
        for person in model.masterPlayerList where !model.isPlayerSelectedForGame(person.id) { model.togglePlayerSelection(person.id) }
        if draw { model.disableRandomStartersForEvenDraw(); model.runFullDraw() }
        return (model, defaults)
    }
    func backup(from model: GameViewModel, defaults: UserDefaults) throws -> RugbyAppBackup {
        try AppBackupService.make(state: SavedGameState(game: model.game, savedGames: model.savedGames), participants: model.masterPlayerList, defaults: defaults)
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body: Data?
    nonisolated(unsafe) static var failure: URLError?
    nonisolated(unsafe) static var calls = 0
    nonisolated(unsafe) static var delay: TimeInterval = 0
    private var work: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.calls += 1
        if let failure = Self.failure { client?.urlProtocol(self, didFailWithError: failure); return }
        let id = Int(request.url?.lastPathComponent ?? "") ?? 1
        let body = Self.body ?? Data("[{\"id\":\(id),\"date\":\"2026-11-06T20:10:00.000Z\",\"homeTeam\":{\"name\":\"Ireland\"},\"awayTeam\":{\"name\":\"Argentina\"},\"state\":{\"description\":\"First half\",\"score\":\"12 - 7\"}}]".utf8)
        let status = Self.status
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        self.work = work
        if Self.delay > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: work) } else { work.perform() }
    }
    override func stopLoading() { work?.cancel() }
    static func session() -> URLSession {
        status = 200; body = nil; failure = nil; calls = 0; delay = 0
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
