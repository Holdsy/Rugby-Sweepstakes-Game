import Foundation
import Combine

struct PhotoSquadSource: Identifiable, Codable {
    let id: UUID
    var team: String
    var url: URL
    var players: [EnglandSquadPlayer] = []
    var updatedAt: Date?
    init(id: UUID = UUID(), team: String, url: URL) { self.id = id; self.team = team; self.url = url }
}

@MainActor
final class PlayerPhotoLibrary: ObservableObject {
    static let shared = PlayerPhotoLibrary()
    @Published private(set) var sources: [PhotoSquadSource]
    @Published private(set) var revision = 0
    private let defaults: UserDefaults
    private let session: URLSession
    private struct CachedPhoto: Codable {
        let playerID: String?
        let url: URL?
        let checkedAt: Date
    }
    private var photos: [String: CachedPhoto]
    private var pending: [String: Task<URL?, Never>] = [:]
    private var nextRequest = Date.distantPast
    private var cooldownUntil = Date.distantPast

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults; self.session = session
        sources = defaults.data(forKey: "rugby_photo_sources_v1").flatMap { try? JSONDecoder().decode([PhotoSquadSource].self, from: $0) } ?? [
            PhotoSquadSource(team: "England", url: EnglandTeamImporter.seniorSquadPage),
            PhotoSquadSource(team: "Ireland", url: URL(string: "https://www.irishrugby.ie/squad/91")!)
        ]
        photos = defaults.data(forKey: "rugby_player_photo_matches_v1").flatMap { try? JSONDecoder().decode([String: CachedPhoto].self, from: $0) } ?? [:]
    }
    func players(for team: String?) -> [EnglandSquadPlayer] {
        guard let team, !team.isEmpty else { return [] }
        let matching = sources.filter { Self.key($0.team) == Self.key(team) }
        var grouped: [String: [EnglandSquadPlayer]] = [:]
        for player in matching.flatMap(\.players) { grouped[Self.key(player.name), default: []].append(player) }
        return grouped.values.compactMap { group in
            let urls = Set(group.compactMap(\.photoURL))
            return urls.count <= 1 ? group.first : nil
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    func officialPhoto(name: String, team: String?) -> URL? {
        let players = players(for: team)
        return EnglandPlayerNameMatcher.index(named: name, in: players.map(\.name)).flatMap { players[$0].photoURL }
    }
    func add(team: String, urlString: String) throws {
        let team = team.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !team.isEmpty, let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, host.contains("."), url.user == nil, url.password == nil else { throw PhotoError.invalidPage }
        guard !sources.contains(where: { Self.key($0.team) == Self.key(team) && $0.url == url }) else { throw PhotoError.duplicatePage }
        sources.append(PhotoSquadSource(team: team, url: url)); saveSources()
    }
    func remove(id: UUID) { sources.removeAll { $0.id == id }; saveSources() }
    func refresh(id: UUID) async throws {
        guard let source = sources.first(where: { $0.id == id }) else { return }
        let players: [EnglandSquadPlayer]
        if source.url.host?.hasSuffix("englandrugby.com") == true {
            players = try await EnglandTeamImporter.currentSeniorSquad()
        } else {
            let reader = URL(string: "https://r.jina.ai/" + source.url.absoluteString)!
            var request = URLRequest(url: reader); request.timeoutInterval = 45
            request.setValue("text/plain", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let page = String(data: data, encoding: .utf8) else { throw PhotoError.download }
            players = Self.players(from: page)
        }
        guard players.count >= 3 else { throw PhotoError.noPlayers }
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].players = players; sources[index].updatedAt = Date(); saveSources()
    }
    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) { defaults.set(data, forKey: "rugby_photo_sources_v1") }
        revision += 1
    }
    static func key(_ value: String) -> String { EnglandPlayerNameMatcher.key(value) }

    /// Extract named portrait cards from readable squad pages; ignore logos and ambiguous cards.
    static func players(from page: String) -> [EnglandSquadPlayer] {
        let lines = page.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let pattern = #"!\[([^\]]*)\]\((https://[^\s\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var result: [EnglandSquadPlayer] = []
        for (index, line) in lines.enumerated() {
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let altRange = Range(match.range(at: 1), in: line), let urlRange = Range(match.range(at: 2), in: line),
                  let url = URL(string: String(line[urlRange])), url.scheme == "https" else { continue }
            var nameParts: [String] = []
            for next in lines.dropFirst(index + 1).prefix(3) {
                guard next.range(of: #"^[\p{L}][\p{L}\p{M}'’ .\-]+$"#, options: .regularExpression) != nil else { break }
                nameParts.append(next)
                if nameParts.joined(separator: " ").split(separator: " ").count >= 2 { break }
            }
            let alt = String(line[altRange]).replacingOccurrences(of: #"^Image\s*\d*:\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let name = nameParts.joined(separator: " ")
            // Require the image label to corroborate at least the first name or surname.
            let words = name.split(separator: " ")
            guard words.count >= 2, words.count <= 5,
                  words.contains(where: { Self.key(alt).contains(Self.key(String($0))) && $0.count >= 3 }),
                  !["logo", "sponsor", "partner", "banner", "news"].contains(where: { alt.lowercased().contains($0) }),
                  !result.contains(where: { Self.key($0.name) == Self.key(name) }) else { continue }
            result.append(EnglandSquadPlayer(name: name, photoURL: url, age: nil, caps: nil))
        }
        return result
    }

    struct SportsPlayer: Decodable {
        let idPlayer: String?
        let strPlayer: String?
        let strSport: String?
        let strTeam: String?
        let strNationality: String?
        let strThumb: String?
        let strCutout: String?
    }
    static func match(name: String, team: String, players: [SportsPlayer]) -> SportsPlayer? {
        let matches = players.filter {
            Self.key($0.strSport ?? "") == "rugby" && Self.key($0.strPlayer ?? "") == Self.key(name)
            && (Self.key($0.strTeam ?? "") == Self.key(team) || Self.key($0.strNationality ?? "") == Self.key(team))
        }
        return matches.count == 1 ? matches[0] : nil
    }
    func sportsPhoto(name: String, team: String?) async -> URL? {
        guard let team, !team.isEmpty, !Self.key(name).isEmpty else { return nil }
        let cacheKey = Self.key(team) + ":" + Self.key(name)
        if let cached = photos[cacheKey], Date().timeIntervalSince(cached.checkedAt) < (cached.url == nil ? 86400 : 604800) { return cached.url }
        if let task = pending[cacheKey] { return await task.value }
        guard Date() >= cooldownUntil else { return nil }
        let task = Task<URL?, Never> {
            // Reserve a slot before suspending: stay under the public API's 30/minute limit.
            let slot = max(Date(), self.nextRequest)
            self.nextRequest = slot.addingTimeInterval(2.1)
            let delay = slot.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard Date() >= self.cooldownUntil else { return nil }
            var components = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/123/searchplayers.php")!
            components.queryItems = [URLQueryItem(name: "p", value: name)]
            do {
                var request = URLRequest(url: components.url!); request.timeoutInterval = 15
                let (data, response) = try await self.session.data(for: request)
                guard let http = response as? HTTPURLResponse else { return nil }
                if http.statusCode == 429 { self.cooldownUntil = Date().addingTimeInterval(60); return nil }
                guard (200...299).contains(http.statusCode) else { return nil }
                struct Response: Decodable { let player: [SportsPlayer]? }
                let values = try JSONDecoder().decode(Response.self, from: data)
                let player = Self.match(name: name, team: team, players: values.player ?? [])
                let url = [player?.strCutout, player?.strThumb].compactMap { $0 }.compactMap(URL.init(string:)).first { $0.scheme == "https" }
                self.photos[cacheKey] = CachedPhoto(playerID: player?.idPlayer, url: url, checkedAt: Date())
                if let data = try? JSONEncoder().encode(self.photos) { self.defaults.set(data, forKey: "rugby_player_photo_matches_v1") }
                return url
            } catch { return nil }
        }
        pending[cacheKey] = task
        let url = await task.value
        pending[cacheKey] = nil
        return url
    }
    enum PhotoError: LocalizedError {
        case invalidPage, duplicatePage, download, noPlayers
        var errorDescription: String? {
            switch self {
            case .invalidPage: "Enter a team name and a public HTTPS squad-page link."
            case .duplicatePage: "This team photo page is already saved."
            case .download: "The squad page could not be loaded. Your existing photos have been kept."
            case .noPlayers: "This page format could not be matched to player portraits. Your existing photos have been kept. Try another squad page."
            }
        }
    }
}
