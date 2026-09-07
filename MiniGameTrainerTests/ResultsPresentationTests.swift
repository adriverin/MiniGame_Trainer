import XCTest
@testable import MiniGameTrainer

final class ResultsPresentationTests: XCTestCase {
    func testFirstScoreIncludingZeroIsANewPersonalBest() {
        let result = GameResult(gameID: "piano", score: 0, duration: 1)
        var stats = GameStatistics(gameID: "piano")
        stats.record(result)
        XCTAssertEqual(ResultProgressFeedback.evaluate(result: result, statistics: stats), .newPersonalBest)
    }

    func testHigherIsBetterNewAndTiedPersonalBest() {
        var stats = GameStatistics(gameID: "piano")
        stats.record(GameResult(gameID: "piano", score: 20, duration: 1))
        let newBest = GameResult(gameID: "piano", score: 26, duration: 1)
        stats.record(newBest)
        XCTAssertEqual(ResultProgressFeedback.evaluate(result: newBest, statistics: stats), .newPersonalBest)

        let tied = GameResult(gameID: "piano", score: 26, duration: 1)
        stats.record(tied)
        XCTAssertEqual(ResultProgressFeedback.evaluate(result: tied, statistics: stats), .matchedBest)
    }

    func testHigherIsBetterDistanceUsesScoreFormatting() {
        var stats = GameStatistics(gameID: "piano")
        stats.record(GameResult(gameID: "piano", score: 26, duration: 1))
        let result = GameResult(gameID: "piano", score: 23, duration: 1)
        stats.record(result)
        XCTAssertEqual(
            ResultProgressFeedback.evaluate(result: result, statistics: stats),
            .distanceFromBest("3")
        )
    }

    func testLowerIsBetterDistanceUsesMilliseconds() {
        var stats = GameStatistics(gameID: "react")
        stats.record(GameResult(gameID: "react", score: 350, scorePresentation: .reactionMilliseconds, duration: 1))
        let result = GameResult(gameID: "react", score: 420, scorePresentation: .reactionMilliseconds, duration: 1)
        stats.record(result)
        XCTAssertEqual(
            ResultProgressFeedback.evaluate(result: result, statistics: stats),
            .distanceFromBest("70 ms")
        )
    }

    func testLowerIsBetterDetectsNewPersonalBest() {
        var stats = GameStatistics(gameID: "react")
        stats.record(GameResult(gameID: "react", score: 420, scorePresentation: .reactionMilliseconds, duration: 1))
        let result = GameResult(gameID: "react", score: 350, scorePresentation: .reactionMilliseconds, duration: 1)
        stats.record(result)
        XCTAssertEqual(ResultProgressFeedback.evaluate(result: result, statistics: stats), .newPersonalBest)
    }

    func testFixedPointPercentageDistanceNeverExposesStorageUnits() {
        var stats = GameStatistics(gameID: "centerHit")
        stats.record(GameResult(gameID: "centerHit", score: 9_910, scorePresentation: .precisionPercent, duration: 1))
        let result = GameResult(gameID: "centerHit", score: 9_830, scorePresentation: .precisionPercent, duration: 1)
        stats.record(result)
        XCTAssertEqual(
            ResultProgressFeedback.evaluate(result: result, statistics: stats),
            .distanceFromBest("0.80%")
        )
    }

    func testDistancePresentationPreservesDistanceUnit() {
        let presentation = ScorePresentation(label: "Distance", unit: "m")
        XCTAssertEqual(presentation.formattedDifference(125), "125 m")
    }

    func testAttemptStatusPresentationIsCompactAndAccurate() {
        XCTAssertEqual(AttemptStatusPresentation.label(for: .free(remaining: 7), freeLimit: 7), "7 / 7 attempts")
        XCTAssertEqual(AttemptStatusPresentation.label(for: .rewarded(remaining: 1), freeLimit: 7), "1 bonus attempt")
        XCTAssertEqual(AttemptStatusPresentation.label(for: .proUnlimited, freeLimit: 7), "Unlimited")
    }
}
