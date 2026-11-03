import Foundation
import Combine

struct LiveMatchSnapshot: Codable {
    let matchID: Int
    let home: String
    let away: String
    let score: String?
    let status: String?
    let fetchedAt: Date
    var scorePair: [String]? {
        guard let score else { return nil }
        let parts = score.components(separatedBy: CharacterSet(charactersIn: "-–—:"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        return parts
    }
    var statusText: String {
        let value = status?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Status unavailable" : value
    }
    func isStale(at now: Date) -> Bool { now.timeIntervalSince(fetchedAt) > 120 }
}

/// Provider scores are kept separate from the sweepstake's manually recorded player points.
@MainActor
final class LiveMatchScoreModel: ObservableObject {
    @Published private(set) var snapshot: LiveMatchSnapshot?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    private let client: HighlightlyClient
    private let defaults: UserDefaults
    private var matchID: Int?
    private var requestID = UUID()
    init(client: HighlightlyClient? = nil, defaults: UserDefaults = .standard) {
        self.client = client ?? HighlightlyClient(); self.defaults = defaults
    }
    func configure(matchID: Int?) {
        guard self.matchID != matchID else { return }
        self.matchID = matchID; requestID = UUID(); loading = false; error = nil; snapshot = nil
        if let matchID, let data = defaults.data(forKey: cacheKey(matchID)),
           let saved = try? JSONDecoder().decode(LiveMatchSnapshot.self, from: data), saved.matchID == matchID {
            snapshot = saved
        }
    }
    func refresh(key: String, force: Bool = true) async {
        guard let matchID, !loading else { return }
        let token = UUID(); requestID = token; loading = true; error = nil
        defer { if requestID == token { loading = false } }
        do {
            let fixture = try await client.fixture(id: matchID, key: key, refresh: force)
            try Task.checkCancellation()
            guard self.matchID == matchID, requestID == token else { return }
            let value = LiveMatchSnapshot(matchID: fixture.id, home: fixture.homeTeam.name, away: fixture.awayTeam.name,
                score: fixture.state?.score, status: fixture.state?.description, fetchedAt: Date())
            snapshot = value
            if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: cacheKey(matchID)) }
        } catch is CancellationError { }
        catch {
            guard self.matchID == matchID, requestID == token, !Task.isCancelled else { return }
            if let apiError = error as? HighlightlyClient.APIError {
                switch apiError {
                case .missingKey: self.error = "Connect Highlightly to load the match score."
                case .invalidKey: self.error = "Highlightly rejected this key or Rugby API access. Check your connection settings."
                case .quota: self.error = "Highlightly’s request limit has been reached. Try again after your allowance resets."
                case .server: self.error = "Highlightly is unavailable right now. Try refreshing again later."
                case .invalidResponse: self.error = "The match score response could not be read. Try refreshing again."
                }
            } else { self.error = "Couldn’t refresh the match score. Check your connection and try again." }
        }
    }
    private func cacheKey(_ id: Int) -> String { "rugby_match_score_cache_\(id)" }
}
