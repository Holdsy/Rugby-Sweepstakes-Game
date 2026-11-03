import Foundation
import Combine

struct TeamLineupDraft: Identifiable, Codable {
    let id: UUID
    let gameID: UUID
    let matchID: Int?
    let fixtureName: String?
    let fixtureDate: String?
    let teamName: String
    let isSample: Bool
    var names: [String]
    var sourceNote: String?
    var updatedAt: Date
    var namedCount: Int { names.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    func matches(gameID: UUID, matchID: Int?, fixtureName: String?, fixtureDate: String?, teamName: String, isSample: Bool) -> Bool {
        self.gameID == gameID && self.matchID == matchID && self.fixtureName == fixtureName
        && self.fixtureDate == fixtureDate && EnglandPlayerNameMatcher.key(self.teamName) == EnglandPlayerNameMatcher.key(teamName)
        && self.isSample == isSample
    }
}

@MainActor
final class TeamDraftStore: ObservableObject {
    static let shared = TeamDraftStore()
    @Published private(set) var drafts: [TeamLineupDraft] = []
    private let defaults: UserDefaults
    private let key = "rugby_team_lineup_drafts_v1"
    private var unreadable = false
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do {
                let saved = try JSONDecoder().decode([TeamLineupDraft].self, from: data)
                guard saved.allSatisfy({ $0.names.count == 23 }) else { throw DraftError.invalid }
                drafts = saved
            } catch { unreadable = true }
        }
    }
    func drafts(for gameID: UUID) -> [TeamLineupDraft] {
        drafts.filter { $0.gameID == gameID }.sorted { $0.updatedAt > $1.updatedAt }
    }
    func find(gameID: UUID, matchID: Int?, fixtureName: String?, fixtureDate: String?, teamName: String, isSample: Bool) -> TeamLineupDraft? {
        drafts.first { $0.matches(gameID: gameID, matchID: matchID, fixtureName: fixtureName, fixtureDate: fixtureDate, teamName: teamName, isSample: isSample) }
    }
    @discardableResult
    func save(gameID: UUID, matchID: Int?, fixtureName: String?, fixtureDate: String?, teamName: String, isSample: Bool, names: [String], sourceNote: String?) throws -> TeamLineupDraft {
        guard !unreadable else { throw DraftError.unreadable }
        guard names.count == 23 else { throw DraftError.invalid }
        let existing = find(gameID: gameID, matchID: matchID, fixtureName: fixtureName, fixtureDate: fixtureDate, teamName: teamName, isSample: isSample)
        let draft = TeamLineupDraft(id: existing?.id ?? UUID(), gameID: gameID, matchID: matchID, fixtureName: fixtureName, fixtureDate: fixtureDate, teamName: teamName, isSample: isSample, names: names, sourceNote: sourceNote, updatedAt: Date())
        var updated = drafts.filter { $0.id != draft.id }; updated.append(draft)
        try persist(updated)
        return draft
    }
    func remove(id: UUID) throws { try persist(drafts.filter { $0.id != id }) }
    private func persist(_ value: [TeamLineupDraft]) throws {
        guard !unreadable else { throw DraftError.unreadable }
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key); drafts = value
    }
    enum DraftError: LocalizedError {
        case unreadable, invalid
        var errorDescription: String? {
            switch self {
            case .unreadable: "Saved team drafts could not be read. Existing data has been preserved; this draft cannot be saved."
            case .invalid: "The team draft must contain 23 shirt slots."
            }
        }
    }
}
