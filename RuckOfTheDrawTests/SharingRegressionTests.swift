import XCTest
import SwiftUI
@testable import Rugby_Sweepstakes_Game

@MainActor final class SharingRegressionTests: XCTestCase {
    func testDrawPosterRendersEveryAllocationForTwoSixAndFifteenPeople() throws {
        for count in [2, 6, 15] {
            let (model, _) = makeGame(people: count)
            model.game.sweepstakePlayers[0].name = "A Participant With A Very Long Name"
            let root = model.game.enabledStarters[0].id
            model.makeSubstitution(outgoingID: root, incomingID: model.game.substitutes[0].id)
            let game = model.game, text = DrawSharePoster.text(for: model.game)
            XCTAssertTrue(text.contains("Ireland v Argentina")); XCTAssertTrue(text.contains("6 Nov 2026"))
            for person in game.sweepstakePlayers { XCTAssertTrue(text.contains(person.name)) }
            for member in DrawSharePoster.members(in: game) { XCTAssertTrue(text.contains(member.name)) }
            let renderer = ImageRenderer(content: DrawSharePoster(game: game, photos: [:]).environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(width: 1080, height: nil); renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, 1080); XCTAssertGreaterThan(image.size.height, 500); XCTAssertLessThan(image.size.height, 6000)
        }
    }
    func testFinalResultsRenderSingleJointAndAllZeroWinners() throws {
        for (count, scored) in [(2, 1), (6, 2), (15, 0)] {
            let (model, _) = makeGame(people: count)
            for participant in model.game.sweepstakePlayers.prefix(scored) {
                model.adjustScoringEvent(.tryScore, for: participant.assignedTeamMemberIds[0], by: 1)
            }
            XCTAssertTrue(model.finishGame())
            let game = model.game
            XCTAssertEqual(game.winningParticipants.count, scored == 0 ? count : scored)
            if scored == 2 {
                let loser = game.rankedParticipants[2]
                XCTAssertEqual(game.participantRank(loser.id), 3)
            }
            let renderer = ImageRenderer(content: ResultsSharePoster(game: game).environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(width: 1080, height: nil); renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, 1080); XCTAssertLessThan(image.size.height, 6000)
            for person in game.sweepstakePlayers { XCTAssertTrue(game.resultsShareText.contains(person.name)) }
        }
    }
    func testGameTitleUsesFixtureDateNotCompletionDate() {
        let (model, _) = makeGame()
        XCTAssertTrue(model.finishGame())
        XCTAssertEqual(model.game.displayTitle, "Ireland v Argentina · 6 Nov 2026")
        XCTAssertTrue(model.game.resultsShareText.contains("Ruck of the Draw"))
    }
    func testDisplayNameAndBundledIconAreConfigured() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Ruck of the Draw")
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons"))
    }
    func testHalfTimePosterRendersActiveStandingsWithoutCompletingGame() throws {
        for count in [2, 6, 15] {
            let (model, _) = makeGame(people: count)
            model.game.sweepstakePlayers[0].name = "A Participant With A Very Long Half-Time Name"
            let person = model.game.sweepstakePlayers[0]
            model.adjustScoringEvent(.tryScore, for: person.assignedTeamMemberIds[0], by: 1)
            let before = model.game.pointsForParticipant(person.id)
            let text = ResultsShareKind.halfTime.text(for: model.game)
            XCTAssertTrue(text.contains("Half-Time Update")); XCTAssertFalse(text.contains("WINNER"))
            for participant in model.game.sweepstakePlayers { XCTAssertTrue(text.contains(participant.name)) }
            let renderer = ImageRenderer(content: ResultsSharePoster(game: model.game, kind: .halfTime).environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(width: 1080, height: nil); renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, 1080); XCTAssertLessThan(image.size.height, 6000)
            XCTAssertFalse(model.game.isCompleted); XCTAssertEqual(model.game.pointsForParticipant(person.id), before)
            model.adjustScoringEvent(.conversion, for: person.assignedTeamMemberIds[0], by: 1)
            XCTAssertEqual(model.game.pointsForParticipant(person.id), before + 2)
        }
    }
    func testHalfTimeScoreExcludesStaleWrongFixtureAndFinishedScores() throws {
        let now = Date()
        func snapshot(_ status: String, age: TimeInterval = 0, id: Int = 10, score: String = "12-7") -> LiveMatchSnapshot {
            LiveMatchSnapshot(matchID: id, home: "Ireland", away: "Argentina", score: score, status: status, fetchedAt: now.addingTimeInterval(-age))
        }
        XCTAssertNotNil(ResultsShareKind.halfTimeScore(snapshot("Half-time"), matchID: 10, now: now))
        XCTAssertNotNil(ResultsShareKind.halfTimeScore(snapshot("HT"), matchID: 10, now: now))
        XCTAssertNil(ResultsShareKind.halfTimeScore(snapshot("Finished"), matchID: 10, now: now))
        XCTAssertNil(ResultsShareKind.halfTimeScore(snapshot("HT", age: 121), matchID: 10, now: now))
        XCTAssertNil(ResultsShareKind.halfTimeScore(snapshot("HT", id: 11), matchID: 10, now: now))
        XCTAssertNil(ResultsShareKind.halfTimeScore(snapshot("HT", score: ""), matchID: 10, now: now))
        XCTAssertNil(ResultsShareKind.halfTimeScore(nil, matchID: nil, now: now))
        let (model, _) = makeGame()
        let renderer = ImageRenderer(content: ResultsSharePoster(game: model.game, kind: .halfTime, matchScore: snapshot("HT")))
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        XCTAssertNotNil(renderer.uiImage)
    }

}
