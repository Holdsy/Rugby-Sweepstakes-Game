//
//  GameViewModel.swift
//  Rugby Sweepstakes Game
//
//  Created by Mark Holdsworth on 03/12/2025.
//

import Foundation
import SwiftUI
import Combine

struct ScoringAction: Identifiable {
    let id = UUID()
    let teamMemberId: UUID
    let description: String
    let points: Int
    let event: ScoringEvent?
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var game: Game
    @Published var masterPlayerList: [SweepstakePlayer] = []
    @Published private(set) var lastScoringAction: ScoringAction?
    @Published private(set) var englandSquad: [EnglandSquadPlayer] = []
    @Published private(set) var englandSquadImportedAt: Date?
    @Published private(set) var savedGames: [Game] = []
    @Published var persistenceError: String?
    @Published private(set) var storageWritesBlocked = false
    private let persistenceService: GamePersistenceService

    init(persistenceService: GamePersistenceService? = nil) {
        let persistenceService = persistenceService ?? GamePersistenceService()
        self.persistenceService = persistenceService
        // Initialize game first (required before using self)
        self.game = Game()
        self.masterPlayerList = []
        let savedEnglandSquad = persistenceService.loadEnglandSquad()
        self.englandSquad = savedEnglandSquad.players
        self.englandSquadImportedAt = savedEnglandSquad.importedAt
        
        // Load master player list
        masterPlayerList = persistenceService.loadMasterPlayerList()
        
        // Initialize default players if master list is empty
        if masterPlayerList.isEmpty {
            for i in 1...6 {
                let color = ColorData.color(at: i - 1)
                masterPlayerList.append(SweepstakePlayer(name: "Player \(i)", color: color))
            }
            saveMasterPlayerList()
        } else {
            // Ensure all existing players have unique colors
            ensureUniqueColors()
        }
        
        do {
            if let state = try persistenceService.loadState() {
                self.game = state.game
                self.savedGames = state.savedGames
                if !game.isDrawComplete { syncSelectedPlayersWithMaster() }
            } else {
                initializeDefaultGame()
            }
        } catch {
            // Never replace an unreadable existing save with a fresh game.
            storageWritesBlocked = true
            persistenceError = "Your saved games could not be opened. The existing save has been preserved."
            initializeDefaultGame()
        }
        refreshLastScoringAction()
        saveGame()
    }
    
    // MARK: - Initialization
    
    private func initializeDefaultGame() {
        // Initialize with the first 6 players from the master list (or all if less than 6)
        // This is just a sensible default; the game now supports any number of players ≥ 2.
        game.sweepstakePlayers = Array(masterPlayerList.prefix(6))
        syncSelectedPlayersWithMaster()
        
        // Initialize with 15 starters and 8 substitutes (empty for user to fill)
        var members: [TeamMember] = []
        
        // Add 15 starters
        for _ in 1...15 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: true,
                isSubstitute: false,
                isEnabledForGame: true
            ))
        }
        
        // Add 8 substitutes
        for _ in 1...8 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: false,
                isSubstitute: true,
                isEnabledForGame: false
            ))
        }
        
        game.teamMembers = members
    }
    
    // MARK: - Team Management
    
    func updateTeamMember(_ member: TeamMember) {
        guard !game.isDrawComplete else { return }
        if let index = game.teamMembers.firstIndex(where: { $0.id == member.id }) {
            game.teamMembers[index] = member
            saveGame()
        }
    }
    
    func toggleEnabledForGame(_ memberId: UUID) {
        guard !game.isDrawComplete else { return }
        if let index = game.teamMembers.firstIndex(where: { $0.id == memberId && $0.isStarter }) {
            game.teamMembers[index].isEnabledForGame.toggle()
            saveGame()
        }
    }

    func disableRandomStartersForEvenDraw() {
        guard !game.isDrawComplete else { return }
        let numberToDisable = game.playersToDisableForEvenDraw
        guard numberToDisable > 0 else { return }

        let memberIds = Set(
            game.enabledStarters
                .shuffled()
                .prefix(numberToDisable)
                .map(\.id)
        )

        for index in game.teamMembers.indices where memberIds.contains(game.teamMembers[index].id) {
            game.teamMembers[index].isEnabledForGame = false
        }

        saveGame()
    }
    
    /// Compatibility entry point for replacing an original starter.
    func linkSubstitute(substituteId: UUID, to starterId: UUID) {
        guard let starter = getTeamMember(by: starterId), starter.isStarter, starter.linkedSubstituteId == nil else { return }
        makeSubstitution(outgoingID: starterId, incomingID: substituteId)
    }

    /// Follow the original allocation through a chain of replacements.
    func makeSubstitution(outgoingID: UUID, incomingID: UUID) {
        guard game.isDrawComplete, !game.isCompleted, outgoingID != incomingID,
              let outgoing = getTeamMember(by: outgoingID), isOnField(outgoing),
              let incoming = getTeamMember(by: incomingID), incoming.isSubstitute, !isOnField(incoming),
              !incoming.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let rootID = scoringBundle(for: outgoingID),
              let rootIndex = game.teamMembers.firstIndex(where: { $0.id == rootID && $0.isStarter }) else { return }
        prepareScoringHistory()
        game.teamMembers[rootIndex].linkedSubstituteId = incomingID
        game.substitutionHistory = (game.substitutionHistory ?? []) + [MatchSubstitutionEntry(starterID: rootID, replacementID: incomingID, isReturn: false, outgoingPlayerID: outgoingID)]
        saveGame()
    }

    func unlinkSubstitute(from starterId: UUID) {
        guard game.isDrawComplete, !game.isCompleted,
              let index = game.teamMembers.firstIndex(where: { $0.id == starterId && $0.isStarter }),
              let substituteID = game.teamMembers[index].linkedSubstituteId else { return }
        prepareScoringHistory()
        game.teamMembers[index].linkedSubstituteId = nil
        game.substitutionHistory = (game.substitutionHistory ?? []) + [MatchSubstitutionEntry(starterID: starterId, replacementID: substituteID, isReturn: true, outgoingPlayerID: substituteID)]
        saveGame()
    }

    func getTeamMember(by id: UUID) -> TeamMember? {
        game.teamMembers.first { $0.id == id }
    }
    
    func setSelectedTeamName(_ name: String) {
        guard !game.isDrawComplete else { return }
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        game.selectedTeamName = value.isEmpty ? nil : name
        saveGame()
    }

    // MARK: - Team Import

    func importEnglandSquad() async throws {
        let players = try await EnglandTeamImporter.currentSeniorSquad()
        let importedAt = Date()
        englandSquad = players
        englandSquadImportedAt = importedAt
        persistenceService.saveEnglandSquad(players, importedAt: importedAt)
    }

    func englandSquadPlayer(named name: String) -> EnglandSquadPlayer? {
        guard let index = EnglandPlayerNameMatcher.index(named: name, in: englandSquad.map(\.name)) else { return nil }
        return englandSquad[index]
    }

    func availableEnglandSquadPlayers(excluding memberID: UUID) -> [EnglandSquadPlayer] {
        if let team = game.selectedTeamName,
           !team.isEmpty && team.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("England") != .orderedSame { return [] }
        let assignedNames = Set(game.teamMembers
            .filter { $0.id != memberID && !$0.name.isEmpty }
            .map { EnglandPlayerNameMatcher.key($0.name) })
        return englandSquad.filter { !assignedNames.contains(EnglandPlayerNameMatcher.key($0.name)) }
    }

    func assignEnglandPlayer(_ player: EnglandSquadPlayer?, to memberID: UUID) {
        guard !game.isDrawComplete else { return }
        guard let index = game.teamMembers.firstIndex(where: { $0.id == memberID }) else {
            return
        }
        game.teamMembers[index].name = player?.name ?? ""
        saveGame()
    }
    
    /// A reviewed complete matchday team starts a fresh draw with fresh scores.
    func importMatchdayTeam(_ players: [ExtractedPlayer], fixtureName: String? = nil, teamName: String? = nil, fixtureDate: String? = nil, providerMatchID: Int? = nil, providerName: String? = nil) {
        guard !game.isDrawComplete else { return }
        guard players.count == 23,
              Set(players.compactMap(\.number)) == Set(1...23),
              players.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return }
        resetTeam()
        game.isDrawComplete = false
        for index in game.sweepstakePlayers.indices {
            game.sweepstakePlayers[index].assignedTeamMemberIds = []
            game.sweepstakePlayers[index].drawRounds = []
        }
        lastScoringAction = nil
        game.fixtureName = fixtureName
        game.selectedTeamName = teamName
        game.fixtureDate = fixtureDate
        game.providerMatchID = providerMatchID
        game.providerName = providerName
        game.lineupImportedAt = Date()
        importPlayers(players)
    }

    func importPlayers(_ players: [ExtractedPlayer]) {
        guard !game.isDrawComplete else { return }
        // Sort players by number (if available)
        let sortedPlayers = players.sorted { p1, p2 in
            let num1 = p1.number ?? 999
            let num2 = p2.number ?? 999
            return num1 < num2
        }
        
        // Create a mutable copy of team members array
        var updatedTeamMembers = game.teamMembers
        var playerIndex = 0
        
        // Fill in empty starter slots first
        let starterSlots = updatedTeamMembers.enumerated().filter { $0.element.isStarter }
        
        for (index, _) in starterSlots {
            if playerIndex >= sortedPlayers.count {
                break
            }
            
            if playerIndex >= 15 {
                break
            }
            
            var member = updatedTeamMembers[index]
            // Convert name to Title Case
            member.name = sortedPlayers[playerIndex].name.toTitleCase()
            
            // Store jersey number in position field if available
            if let number = sortedPlayers[playerIndex].number {
                member.position = "Jersey #\(number)"
            }
            
            updatedTeamMembers[index] = member
            playerIndex += 1
        }
        
        // Fill in empty substitute slots if there are more players
        let substituteSlots = updatedTeamMembers.enumerated().filter { $0.element.isSubstitute }
        
        for (index, _) in substituteSlots {
            if playerIndex >= sortedPlayers.count {
                break
            }
            
            if playerIndex >= (15 + 8) {
                break
            }
            
            var member = updatedTeamMembers[index]
            // Convert name to Title Case
            member.name = sortedPlayers[playerIndex].name.toTitleCase()
            
            if let number = sortedPlayers[playerIndex].number {
                member.position = "Jersey #\(number)"
            }
            
            updatedTeamMembers[index] = member
            playerIndex += 1
        }
        
        // Update the entire array to trigger @Published refresh
        game.teamMembers = updatedTeamMembers
        saveGame()
    }
    
    // MARK: - Sweepstake Players Management
    
    func updateSweepstakePlayer(_ player: SweepstakePlayer) {
        // Update in master list
        if let index = masterPlayerList.firstIndex(where: { $0.id == player.id }) {
            masterPlayerList[index] = player
            saveMasterPlayerList()
        }
        
        // Update in current game if selected
        if !game.isCompleted, let index = game.sweepstakePlayers.firstIndex(where: { $0.id == player.id }) {
            game.sweepstakePlayers[index].name = player.name
            game.sweepstakePlayers[index].color = player.color
            saveGame()
        }
    }
    
    @discardableResult
    func addMasterPlayer(name: String) -> UUID {
        let uniqueColor = getNextAvailableColor()
        let newPlayer = SweepstakePlayer(name: name, color: uniqueColor)
        masterPlayerList.append(newPlayer)
        saveMasterPlayerList()
        return newPlayer.id
    }
    
    // MARK: - Color Management
    
    private func getNextAvailableColor() -> ColorData {
        let usedColors = Set(masterPlayerList.map { colorToString($0.color) })
        return getNextAvailableColor(excluding: usedColors)
    }
    
    private func ensureUniqueColors() {
        var assignedColorStrings: Set<String> = []
        var changed = false
        
        // Go through each player and ensure they have a unique color
        for index in masterPlayerList.indices {
            let currentColorString = colorToString(masterPlayerList[index].color)
            
            if assignedColorStrings.contains(currentColorString) {
                // This color is already used, assign a new unique one
                let newColor = getNextAvailableColor(excluding: assignedColorStrings)
                masterPlayerList[index].color = newColor
                let newColorString = colorToString(newColor)
                assignedColorStrings.insert(newColorString)
                changed = true
            } else {
                // This color is unique, keep it
                assignedColorStrings.insert(currentColorString)
            }
        }
        
        if changed {
            saveMasterPlayerList()
        }
    }
    
    private func colorToString(_ color: ColorData) -> String {
        // Round to avoid floating point precision issues
        String(format: "%.2f,%.2f,%.2f", color.red, color.green, color.blue)
    }
    
    private func getNextAvailableColor(excluding usedColors: Set<String>) -> ColorData {
        // Try each available color in order
        for colorTuple in ColorData.allAvailableColors {
            let colorString = String(format: "%.2f,%.2f,%.2f", colorTuple.0, colorTuple.1, colorTuple.2)
            if !usedColors.contains(colorString) {
                return ColorData(red: colorTuple.0, green: colorTuple.1, blue: colorTuple.2)
            }
        }
        
        // If all colors are used, cycle through them based on count
        let colorIndex = usedColors.count % ColorData.allAvailableColors.count
        return ColorData.color(at: colorIndex)
    }
    
    func deleteMasterPlayer(_ playerId: UUID) {
        guard canDeletePlayer(playerId) else { return }
        // Remove from current game first if selected
        if !game.isCompleted && isPlayerSelectedForGame(playerId) {
            game.sweepstakePlayers.removeAll { $0.id == playerId }
            saveGame()
        }
        
        // Remove from master list
        masterPlayerList.removeAll { $0.id == playerId }
        saveMasterPlayerList()
    }
    
    func canDeletePlayer(_ playerId: UUID) -> Bool {
        !(game.isDrawComplete && !game.isCompleted && isPlayerSelectedForGame(playerId))
    }
    
    func isPlayerSelectedForGame(_ playerId: UUID) -> Bool {
        game.sweepstakePlayers.contains { $0.id == playerId }
    }
    
    func togglePlayerSelection(_ playerId: UUID) {
        guard !game.isDrawComplete else { return }
        if isPlayerSelectedForGame(playerId) {
            // Deselect - remove from game
            game.sweepstakePlayers.removeAll { $0.id == playerId }
        } else if let player = masterPlayerList.first(where: { $0.id == playerId }) {
            // Select - add to game (no upper limit; draw logic now only requires a minimum count)
            let newPlayer = SweepstakePlayer(
                id: player.id,
                name: player.name,
                color: player.color,
                assignedTeamMemberIds: [],
                drawRounds: []
            )
            game.sweepstakePlayers.append(newPlayer)
        }
        saveGame()
    }
    
    private func syncSelectedPlayersWithMaster() {
        // Update selected players to match master list (by ID)
        var updatedSelected: [SweepstakePlayer] = []
        for selectedPlayer in game.sweepstakePlayers {
            if let masterPlayer = masterPlayerList.first(where: { $0.id == selectedPlayer.id }) {
                // Keep game-specific data but update name/color from master
                var updated = selectedPlayer
                updated.name = masterPlayer.name
                updated.color = masterPlayer.color
                updatedSelected.append(updated)
            }
        }
        game.sweepstakePlayers = updatedSelected
    }
    
    // MARK: - Draw Logic
    
    func runFullDraw() {
        // Only require that the game is in a valid state; always allow re-running.
        guard game.canRunDraw && !game.isDrawComplete else { return }
        
        // Reset previous draw (if any) so each run starts fresh
        for i in game.sweepstakePlayers.indices {
            game.sweepstakePlayers[i].assignedTeamMemberIds = []
            game.sweepstakePlayers[i].drawRounds = []
        }
        
        var remainingTeamMembers = game.enabledStarters.map { $0.id }
        var roundNumber = 1
        var currentRoundAllocations: [Allocation] = []
        
        while !remainingTeamMembers.isEmpty {
            // Shuffle sweepstake players for this round
            let shuffledPlayers = game.sweepstakePlayers.shuffled()
            var playerIndex = 0
            
            while !remainingTeamMembers.isEmpty && playerIndex < shuffledPlayers.count {
                // Pick a random team member
                guard let randomMemberId = remainingTeamMembers.randomElement() else { break }
                
                // Remove from remaining list
                remainingTeamMembers.removeAll { $0 == randomMemberId }
                
                // Create allocation
                let allocation = Allocation(
                    roundNumber: roundNumber,
                    sweepstakePlayerId: shuffledPlayers[playerIndex].id,
                    teamMemberId: randomMemberId
                )
                
                // Find the sweepstake player and add allocation
                if let playerIndexInGame = game.sweepstakePlayers.firstIndex(where: { $0.id == shuffledPlayers[playerIndex].id }) {
                    game.sweepstakePlayers[playerIndexInGame].assignedTeamMemberIds.append(randomMemberId)
                    currentRoundAllocations.append(allocation)
                }
                
                playerIndex += 1
            }
            
            // Store round allocations in each player's drawRounds
            for allocation in currentRoundAllocations {
                if let playerIndex = game.sweepstakePlayers.firstIndex(where: { $0.id == allocation.sweepstakePlayerId }) {
                    // Find or create the round array for this player
                    if game.sweepstakePlayers[playerIndex].drawRounds.count < roundNumber {
                        // Add new round arrays up to the current round
                        while game.sweepstakePlayers[playerIndex].drawRounds.count < roundNumber {
                            game.sweepstakePlayers[playerIndex].drawRounds.append([])
                        }
                    }
                    game.sweepstakePlayers[playerIndex].drawRounds[roundNumber - 1].append(allocation)
                }
            }
            
            currentRoundAllocations = []
            roundNumber += 1
        }
        
        game.isDrawComplete = true
        saveGame()
    }
    
    // MARK: - Scoring
    
    /// Run once for an existing game, before its first new score or substitution.
    func prepareScoringHistory() {
        guard !game.isCompleted, game.scoringBaseline == nil else { return }
        game.scoringBaseline = game.starters.map { starter in
            ScoringBaseline(bundleID: starter.id, points: starter.points + (getLinkedSubstitute(for: starter.id)?.points ?? 0))
        }
        game.scoringHistory = game.scoringHistory ?? []
        saveGame()
    }

    var activeScoringHistory: [MatchScoreEntry] {
        (game.scoringHistory ?? []).filter { $0.undoneAt == nil }
    }

    func scoringBundle(for memberID: UUID) -> UUID? {
        guard let member = getTeamMember(by: memberID) else { return nil }
        return member.isStarter ? memberID : game.starters.first(where: { $0.linkedSubstituteId == memberID })?.id
    }

    func participant(forBundle bundleID: UUID?) -> SweepstakePlayer? {
        guard let bundleID else { return nil }
        return game.sweepstakePlayers.first { $0.assignedTeamMemberIds.contains(bundleID) }
    }

    func isOnField(_ member: TeamMember) -> Bool {
        member.isStarter ? member.linkedSubstituteId == nil : game.starters.contains { $0.linkedSubstituteId == member.id }
    }

    func adjustScoringEvent(_ event: ScoringEvent, for teamMemberId: UUID, by amount: Int) {
        guard game.isDrawComplete, !game.isCompleted,
              let index = game.teamMembers.firstIndex(where: { $0.id == teamMemberId }),
              amount == 1 || amount == -1 else { return }
        // An unlinked bench player must enter the field before they can receive points.
        guard game.teamMembers[index].isStarter || scoringBundle(for: teamMemberId) != nil else { return }
        let current = count(for: event, member: game.teamMembers[index])
        guard current + amount >= 0 else { return }
        prepareScoringHistory()
        var bundle = scoringBundle(for: teamMemberId)
        var ownerID = participant(forBundle: bundle)?.id
        var correctionOfID: UUID?
        if amount < 0 {
            let correctedIDs = Set(activeScoringHistory.compactMap(\.correctionOfID))
            var legacyRemovals: [UUID?: Int] = [:]
            var source: MatchScoreEntry?
            for candidate in activeScoringHistory.reversed() where candidate.teamMemberID == teamMemberId && candidate.event == event {
                if candidate.countChange < 0 {
                    if candidate.correctionOfID == nil { legacyRemovals[candidate.bundleID, default: 0] += 1 }
                } else if !correctedIDs.contains(candidate.id) {
                    if legacyRemovals[candidate.bundleID, default: 0] > 0 { legacyRemovals[candidate.bundleID, default: 0] -= 1 }
                    else { source = candidate; break }
                }
            }
            if let source {
                bundle = source.bundleID; ownerID = source.participantID; correctionOfID = source.id
            } else if game.teamMembers[index].isSubstitute {
                // Old substitute totals without attribution cannot safely be reassigned.
                return
            }
            if let bundle, game.pointsForBundle(bundle) < event.points { return }
        }
        let entry = MatchScoreEntry(teamMemberID: teamMemberId, bundleID: bundle,
                                   participantID: ownerID, event: event, countChange: amount, correctionOfID: correctionOfID)
        changeCount(event, index: index, by: amount)
        game.scoringHistory = (game.scoringHistory ?? []) + [entry]
        refreshLastScoringAction()
        saveGame()
    }

    private func count(for event: ScoringEvent, member: TeamMember) -> Int {
        switch event {
        case .tryScore: member.tryCount
        case .penalty: member.penaltyCount
        case .conversion: member.conversionCount
        case .dropGoal: member.dropGoalCount
        }
    }

    private func changeCount(_ event: ScoringEvent, index: Int, by amount: Int) {
        switch event {
        case .tryScore: game.teamMembers[index].tryCount += amount
        case .penalty: game.teamMembers[index].penaltyCount += amount
        case .conversion: game.teamMembers[index].conversionCount += amount
        case .dropGoal: game.teamMembers[index].dropGoalCount += amount
        }
    }

    private func refreshLastScoringAction() {
        guard let entry = activeScoringHistory.last else { lastScoringAction = nil; return }
        lastScoringAction = ScoringAction(teamMemberId: entry.teamMemberID,
            description: "\(entry.event.description) for \(getTeamMember(by: entry.teamMemberID)?.name ?? "Rugby player")",
            points: entry.points, event: entry.event)
    }

    func addTry(to teamMemberId: UUID) { adjustScoringEvent(.tryScore, for: teamMemberId, by: 1) }
    func addPenalty(to teamMemberId: UUID) { adjustScoringEvent(.penalty, for: teamMemberId, by: 1) }
    func addConversion(to teamMemberId: UUID) { adjustScoringEvent(.conversion, for: teamMemberId, by: 1) }

    func canUndoScoringEntry(_ id: UUID) -> Bool {
        guard !game.isCompleted,
              !activeScoringHistory.contains(where: { $0.correctionOfID == id }),
              let entry = activeScoringHistory.first(where: { $0.id == id }),
              let member = getTeamMember(by: entry.teamMemberID),
              count(for: entry.event, member: member) - entry.countChange >= 0 else { return false }
        if let bundle = entry.bundleID, game.pointsForBundle(bundle) - entry.points < 0 { return false }
        return true
    }

    /// Remove a specific recorded score using its original attribution, not current substitutions.
    func undoScoringEntry(_ id: UUID) {
        guard canUndoScoringEntry(id),
              let historyIndex = game.scoringHistory?.firstIndex(where: { $0.id == id }),
              let entry = game.scoringHistory?[historyIndex],
              let memberIndex = game.teamMembers.firstIndex(where: { $0.id == entry.teamMemberID }) else { return }
        changeCount(entry.event, index: memberIndex, by: -entry.countChange)
        game.scoringHistory?[historyIndex].undoneAt = Date()
        refreshLastScoringAction()
        saveGame()
    }

    func undoLastScoringAction() {
        guard let entry = activeScoringHistory.last else { return }
        undoScoringEntry(entry.id)
    }

    func rank(for participantID: UUID) -> Int { game.participantRank(participantID) }
    func getTotalPointsForTeamMember(_ id: UUID) -> Int { game.pointsForBundle(id) }
    func getTotalPoints(for id: UUID) -> Int { game.pointsForParticipant(id) }
    func getSortedSweepstakePlayers() -> [SweepstakePlayer] { game.rankedParticipants }

    // Get winners (handles ties)
    func getWinners() -> [SweepstakePlayer] {
        let sorted = getSortedSweepstakePlayers()
        guard let highestScore = sorted.first.map({ getTotalPoints(for: $0.id) }) else {
            return []
        }
        
        return sorted.filter { getTotalPoints(for: $0.id) == highestScore }
    }
    
    // MARK: - Helper Methods
    
    func getLinkedSubstitute(for starterId: UUID) -> TeamMember? {
        guard let starter = getTeamMember(by: starterId),
              let substituteId = starter.linkedSubstituteId else {
            return nil
        }
        return getTeamMember(by: substituteId)
    }
    
    /// Completed and unfinished games are preserved before starting another.
    @discardableResult
    func resetGame() -> Bool {
        guard !storageWritesBlocked else { return false }
        let previousGame = game, previousHistory = savedGames
        if game.hasGameContent { storeSnapshot(game) }
        game = Game()
        lastScoringAction = nil
        initializeDefaultGame()
        guard saveGame() else {
            game = previousGame; savedGames = previousHistory; refreshLastScoringAction()
            return false
        }
        return true
    }

    private func storeSnapshot(_ value: Game) {
        var snapshot = value
        snapshot.savedToHistoryAt = Date()
        savedGames.removeAll { $0.id == snapshot.id }
        savedGames.insert(snapshot, at: 0)
    }

    @discardableResult
    func finishGame() -> Bool {
        guard game.isDrawComplete, !game.isCompleted, !storageWritesBlocked else { return false }
        let previousGame = game, previousHistory = savedGames
        game.completedAt = Date()
        storeSnapshot(game)
        guard saveGame() else { game = previousGame; savedGames = previousHistory; return false }
        return true
    }

    /// Preserve the other current game before restoring a saved game for correction.
    @discardableResult
    func reopenGame(_ id: UUID) -> Bool {
        guard !storageWritesBlocked,
              var restored = savedGames.first(where: { $0.id == id }) ?? (game.id == id ? game : nil) else { return false }
        let previousGame = game, previousHistory = savedGames
        if game.id != id && game.hasGameContent { storeSnapshot(game) }
        savedGames.removeAll { $0.id == id }
        restored.completedAt = nil
        restored.savedToHistoryAt = nil
        game = restored
        refreshLastScoringAction()
        guard saveGame() else {
            game = previousGame; savedGames = previousHistory; refreshLastScoringAction()
            return false
        }
        return true
    }

    func resetTeam() {
        guard !game.isDrawComplete else { return }
        // Clear all team member information (starters and substitutes)
        var members: [TeamMember] = []
        
        // Add 15 empty starters
        for _ in 1...15 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: true,
                isSubstitute: false,
                isEnabledForGame: true
            ))
        }
        
        // Add 8 empty substitutes
        for _ in 1...8 {
            members.append(TeamMember(
                name: "",
                position: nil,
                isStarter: false,
                isSubstitute: true,
                isEnabledForGame: false
            ))
        }
        
        game.teamMembers = members
        saveGame()
    }
    
    // MARK: - Persistence
    
    @discardableResult
    private func saveGame() -> Bool {
        guard !storageWritesBlocked else { return false }
        do {
            try persistenceService.saveState(game: game, savedGames: savedGames)
            return true
        } catch {
            persistenceError = "Changes could not be saved. Your previous saved game has been kept. Please try again."
            return false
        }
    }
    
    private func saveMasterPlayerList() {
        persistenceService.saveMasterPlayerList(masterPlayerList)
    }
}
