import Foundation

struct MatchdayFixture: Decodable, Identifiable {
    struct Team: Decodable { let name: String }
    struct League: Decodable { let id: Int; let name: String }
    struct MatchState: Decodable { let description: String?; let score: String? }
    struct Player: Decodable {
        let name: String
        let shirtNumber: Int
        init(name: String, shirtNumber: Int) { self.name = name; self.shirtNumber = shirtNumber }
        private enum CodingKeys: String, CodingKey { case name, shirtNumber }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
            shirtNumber = try values.decodeIfPresent(Int.self, forKey: .shirtNumber) ?? 0
        }
    }
    struct TeamSheet: Decodable {
        let initialLineup: [Player]
        let substitutions: [Player]
        init(initialLineup: [Player], substitutions: [Player]) {
            self.initialLineup = initialLineup; self.substitutions = substitutions
        }
        private enum CodingKeys: String, CodingKey { case initialLineup, substitutions }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            initialLineup = try values.decodeIfPresent([Player].self, forKey: .initialLineup) ?? []
            substitutions = try values.decodeIfPresent([Player].self, forKey: .substitutions) ?? []
        }
        var players: [Player] { initialLineup + substitutions }
        var issues: [String] {
            let numbers = players.map(\.shirtNumber)
            var result: [String] = []
            let missing = (1...23).filter { !numbers.contains($0) }
            if !missing.isEmpty { result.append("Missing shirt numbers: " + missing.map(String.init).joined(separator: ", ")) }
            if Set(numbers).count != numbers.count { result.append("Duplicate shirt numbers") }
            if players.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { result.append("Missing player names") }
            if initialLineup.count != 15 || substitutions.count != 8 { result.append("A complete team needs 15 starters and 8 replacements") }
            if !initialLineup.allSatisfy({ (1...15).contains($0.shirtNumber) }) || !substitutions.allSatisfy({ (16...23).contains($0.shirtNumber) }) { result.append("Check starter and replacement shirt numbers") }
            return result
        }
    }
    struct Lineups: Decodable { let home: TeamSheet?; let away: TeamSheet? }
    let id: Int
    let date: String
    let homeTeam: Team
    let awayTeam: Team
    let lineups: Lineups?
    let league: League?
    let state: MatchState?
    var title: String { "\(homeTeam.name) v \(awayTeam.name)" }

    static func samples() throws -> [Self] {
        guard let url = Bundle.main.url(forResource: "MatchdaySamples", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
    }
}

