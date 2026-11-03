import Foundation

struct RugbyAppBackup: Codable {
    var format = "RugbySweepstakesBackup"
    var version = 1
    var createdAt = Date()
    var state: SavedGameState
    var participants: [SweepstakePlayer]
    var englandSquad: [EnglandSquadPlayer]
    var englandSquadImportedAt: Date?
    var drafts: [TeamLineupDraft]
    var photoSources: [PhotoSquadSource]
}

/// Only these app records are backed up; credentials and transient image caches are excluded.
enum AppBackupService {
    static let managedKeys = ["rugby_sweepstake_state_v1", "rugby_sweepstake_game", "rugby_sweepstake_master_players", "rugby_sweepstake_england_squad", "rugby_sweepstake_england_squad_import_date", "rugby_team_lineup_drafts_v1", "rugby_photo_sources_v1", "rugby_player_photo_matches_v1"]
    static func make(state: SavedGameState, participants: [SweepstakePlayer], defaults: UserDefaults = .standard) throws -> RugbyAppBackup {
        func read<T: Decodable>(_ type: T.Type, key: String, fallback: T) throws -> T {
            guard let data = defaults.data(forKey: key) else { return fallback }
            return try JSONDecoder().decode(type, from: data)
        }
        let backup = RugbyAppBackup(state: state, participants: participants,
            englandSquad: try read([EnglandSquadPlayer].self, key: "rugby_sweepstake_england_squad", fallback: []),
            englandSquadImportedAt: defaults.object(forKey: "rugby_sweepstake_england_squad_import_date") as? Date,
            drafts: try read([TeamLineupDraft].self, key: "rugby_team_lineup_drafts_v1", fallback: []),
            photoSources: try read([PhotoSquadSource].self, key: "rugby_photo_sources_v1", fallback: [PhotoSquadSource(team: "England", url: EnglandTeamImporter.seniorSquadPage), PhotoSquadSource(team: "Ireland", url: URL(string: "https://www.irishrugby.ie/squad/91")!)]))
        try validate(backup)
        return backup
    }
    static func encode(_ backup: RugbyAppBackup) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
    static func decode(_ data: Data) throws -> RugbyAppBackup {
        guard data.count <= 20 * 1024 * 1024 else { throw BackupError.tooLarge }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup: RugbyAppBackup
        do { backup = try decoder.decode(RugbyAppBackup.self, from: data) }
        catch { throw BackupError.invalid }
        try validate(backup)
        return backup
    }
    static func validate(_ backup: RugbyAppBackup) throws {
        guard backup.format == "RugbySweepstakesBackup" else { throw BackupError.invalid }
        guard backup.version == 1, backup.state.version == 1 else { throw BackupError.version }
        func unique<T: Hashable>(_ ids: [T]) -> Bool { Set(ids).count == ids.count }
        guard unique(backup.participants.map(\.id)), unique(backup.state.savedGames.map(\.id)),
              unique(backup.drafts.map(\.id)), unique(backup.photoSources.map(\.id)), backup.state.savedGames.count <= 5000 else { throw BackupError.invalid }
        for game in [backup.state.game] + backup.state.savedGames {
            let members = Set(game.teamMembers.map(\.id)), people = Set(game.sweepstakePlayers.map(\.id))
            guard game.teamMembers.count <= 23, game.sweepstakePlayers.count <= 15,
                  unique(game.teamMembers.map(\.id)), unique(game.sweepstakePlayers.map(\.id)) else { throw BackupError.invalid }
            if game.isDrawComplete {
                guard game.teamMembers.count == 23, game.starters.count == 15, game.substitutes.count == 8,
                      game.sweepstakePlayers.count >= 2 else { throw BackupError.invalid }
            }
            var allocations = Set<UUID>()
            for player in game.sweepstakePlayers {
                for id in player.assignedTeamMemberIds {
                    guard members.contains(id), allocations.insert(id).inserted else { throw BackupError.invalid }
                }
                for round in player.drawRounds {
                    guard round.allSatisfy({ members.contains($0.teamMemberId) && $0.sweepstakePlayerId == player.id }) else { throw BackupError.invalid }
                }
            }
            for member in game.teamMembers {
                guard [member.tryCount, member.penaltyCount, member.conversionCount, member.dropGoalCount].allSatisfy({ (0...1_000_000).contains($0) }),
                      member.linkedSubstituteId.map({ members.contains($0) && $0 != member.id }) ?? true else { throw BackupError.invalid }
            }
            for baseline in game.scoringBaseline ?? [] {
                guard members.contains(baseline.bundleID), (0...100_000_000).contains(baseline.points) else { throw BackupError.invalid }
            }
            let scores = game.scoringHistory ?? []
            guard unique(scores.map(\.id)) else { throw BackupError.invalid }
            let scoreIDs = Set(scores.map(\.id))
            for score in scores {
                guard members.contains(score.teamMemberID), (-1_000_000...1_000_000).contains(score.countChange),
                      score.bundleID.map(members.contains) ?? true, score.participantID.map(people.contains) ?? true,
                      score.correctionOfID.map(scoreIDs.contains) ?? true else { throw BackupError.invalid }
            }
            for sub in game.substitutionHistory ?? [] {
                guard members.contains(sub.starterID), members.contains(sub.replacementID), sub.outgoingPlayerID.map(members.contains) ?? true else { throw BackupError.invalid }
            }
        }
        guard backup.drafts.allSatisfy({ $0.names.count == 23 }) else { throw BackupError.invalid }
        for source in backup.photoSources {
            guard source.url.scheme == "https", source.url.host != nil, source.url.user == nil, source.url.password == nil,
                  source.players.allSatisfy({ $0.photoURL.map { $0.scheme == "https" && $0.host != nil } ?? true }) else { throw BackupError.invalid }
        }
    }
    /// Encode every record before writing; replace the managed set in a single defaults-domain update.
    static func apply(_ backup: RugbyAppBackup, defaults: UserDefaults = .standard, domain: String? = Bundle.main.bundleIdentifier) throws {
        try validate(backup)
        guard let domain else { throw BackupError.storage }
        let encoder = JSONEncoder()
        let records: [String: Any] = [
            "rugby_sweepstake_state_v1": try encoder.encode(backup.state),
            "rugby_sweepstake_master_players": try encoder.encode(backup.participants),
            "rugby_sweepstake_england_squad": try encoder.encode(backup.englandSquad),
            "rugby_team_lineup_drafts_v1": try encoder.encode(backup.drafts),
            "rugby_photo_sources_v1": try encoder.encode(backup.photoSources)
        ]
        var merged = defaults.persistentDomain(forName: domain) ?? [:]
        for key in managedKeys { merged.removeValue(forKey: key) }
        merged.merge(records) { _, restored in restored }
        if let date = backup.englandSquadImportedAt { merged["rugby_sweepstake_england_squad_import_date"] = date }
        defaults.setPersistentDomain(merged, forName: domain)
    }
    static func recoveryFile(state: SavedGameState?, participants: [SweepstakePlayer], defaults: UserDefaults = .standard, directory: URL = recoveryDirectory) throws -> URL {
        let data: Data
        let suffix: String
        if let state, let backup = try? make(state: state, participants: participants, defaults: defaults), let json = try? encode(backup) {
            data = json; suffix = "json"
        } else {
            // Preserve unreadable records exactly so restoring a valid backup never destroys the original evidence.
            let records = Dictionary(uniqueKeysWithValues: managedKeys.compactMap { key in defaults.object(forKey: key).map { (key, $0) } })
            data = try PropertyListSerialization.data(fromPropertyList: records, format: .binary, options: 0); suffix = "plist"
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("Before Restore \(stamp) \(UUID().uuidString.prefix(6)).\(suffix)")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
    static var recoveryDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recovery Backups", isDirectory: true)
    }
    static func recoveryFiles() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    enum BackupError: LocalizedError {
        case invalid, version, tooLarge, storage
        var errorDescription: String? {
            switch self {
            case .invalid: "This file is not a valid Rugby Sweepstakes backup. Your current data has not been changed."
            case .version: "This backup uses an unsupported version. Update the app before trying again. Your current data has not been changed."
            case .tooLarge: "This backup is larger than the supported 20 MB limit. Your current data has not been changed."
            case .storage: "The app’s saved-data location is unavailable. Your current data has not been changed."
            }
        }
    }
}
