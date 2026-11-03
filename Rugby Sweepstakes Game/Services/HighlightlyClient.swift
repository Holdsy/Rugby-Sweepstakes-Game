import Foundation

@MainActor
final class HighlightlyClient {
    enum APIError: LocalizedError {
        case missingKey, invalidKey, quota, server, invalidResponse
        var errorDescription: String? {
            switch self {
            case .missingKey: "Connect your Highlightly account to load fixtures."
            case .invalidKey: "Highlightly rejected this API key or rugby access. Check your key and Rugby API subscription."
            case .quota: "Highlightly’s request limit has been reached. Try again after your allowance resets, or use manual/photo import."
            case .server: "Highlightly is unavailable right now. Try again later or use manual/photo import."
            case .invalidResponse: "The provider response could not be read. Your current team has not been changed."
            }
        }
    }
    struct FixturePage: Decodable {
        struct Pagination: Decodable { let totalCount: Int }
        let data: [MatchdayFixture]
        let pagination: Pagination?
    }
    private let session: URLSession
    private var fixturesCache: [String: (Date, FixturePage)] = [:]
    private var detailsCache: [Int: (Date, MatchdayFixture)] = [:]
    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration)
        }
    }
    func clearCache() { fixturesCache = [:]; detailsCache = [:] }

    func fixtures(date: String, offset: Int = 0, key: String, refresh: Bool = false) async throws -> FixturePage {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.missingKey }
        let cacheKey = "\(date)-\(offset)"
        if !refresh, let (time, value) = fixturesCache[cacheKey], Date().timeIntervalSince(time) < 60 { return value }
        let data = try await request(path: "matches", query: [URLQueryItem(name: "date", value: date), URLQueryItem(name: "timezone", value: "Europe/London"), URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(offset))], key: key)
        let value: FixturePage
        do { value = try JSONDecoder().decode(FixturePage.self, from: data) }
        catch { throw APIError.invalidResponse }
        fixturesCache[cacheKey] = (Date(), value)
        return value
    }

    func fixture(id: Int, key: String, refresh: Bool = false) async throws -> MatchdayFixture {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.missingKey }
        if !refresh, let (time, value) = detailsCache[id], Date().timeIntervalSince(time) < 60 { return value }
        let data = try await request(path: "matches/\(id)", query: [], key: key)
        let values: [MatchdayFixture]
        do { values = try JSONDecoder().decode([MatchdayFixture].self, from: data) }
        catch { throw APIError.invalidResponse }
        guard let fixture = values.first(where: { $0.id == id }) else { throw APIError.invalidResponse }
        detailsCache[id] = (Date(), fixture)
        return fixture
    }

    private func request(path: String, query: [URLQueryItem], key: String) async throws -> Data {
        var components = URLComponents(string: "https://rugby.highlightly.net/\(path)")!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-rapidapi-key")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch response.statusCode {
        case 200...299: return data
        case 401, 403: throw APIError.invalidKey
        case 429: throw APIError.quota
        default: throw APIError.server
        }
    }
}
