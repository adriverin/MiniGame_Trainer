import CoreGraphics
import XCTest
@testable import MiniGameTrainer

final class SwipeFastDifficultyTests: XCTestCase {
    func testReferenceAnchors() {
        let model = SwipeFastDifficultyModel(config: .reference)
        XCTAssertEqual(model.allowedTime(forScore: 0), 2.00, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 10), 1.80, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 20), 1.60, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 30), 1.42, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 40), 1.28, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 50), 1.16, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 60), 1.08, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 70), 1.00, accuracy: 1e-12)
    }

    func testLinearInterpolationBetweenAnchors() {
        let model = SwipeFastDifficultyModel(config: .reference)
        XCTAssertEqual(model.allowedTime(forScore: 5), 1.90, accuracy: 1e-12)
        XCTAssertEqual(model.allowedTime(forScore: 35), 1.35, accuracy: 1e-12)
    }

    func testMonotonicDifficulty() {
        let model = SwipeFastDifficultyModel(config: .reference)
        var previous = model.allowedTime(forScore: 0)
        for score in 1...80 {
            let current = model.allowedTime(forScore: score)
            XCTAssertLessThanOrEqual(current, previous + 1e-12, "Score \(score)")
            previous = current
        }
    }

    func testCapDoesNotGoNegativeAtScore200() {
        let model = SwipeFastDifficultyModel(config: .reference)
        XCTAssertEqual(model.allowedTime(forScore: 200), 1.00, accuracy: 1e-12)
        XCTAssertGreaterThan(model.allowedTime(forScore: 10_000), 0)
    }

    func testCustomMinimumFloor() {
        var config = SwipeFastGameConfig.reference
        config.minimumAllowedTime = 1.25
        let model = SwipeFastDifficultyModel(config: config)
        XCTAssertEqual(model.allowedTime(forScore: 70), 1.25, accuracy: 1e-12)
    }
}

final class SwipeFastScoringTests: XCTestCase {
    func testEachCorrectSwipeAddsOnePoint() {
        let logic = SwipeFastGameLogic(
            config: .reference,
            sceneSize: CGSize(width: 390, height: 844),
            seed: 4
        )
        logic.forcedDirections = [.up, .up, .up, .up]
        logic.start(at: 0)
        XCTAssertEqual(logic.applySwipe(.up, on: .topLeft, at: 0.05).scoreValue, 1)
        XCTAssertEqual(logic.applySwipe(.up, on: .topRight, at: 0.10).scoreValue, 2)
        XCTAssertEqual(logic.applySwipe(.up, on: .bottomLeft, at: 0.15).scoreValue, 3)
        XCTAssertEqual(logic.score, 3)
    }

    func testTooShortAndWrongGesturesDoNotAddPoints() {
        let logic = SwipeFastGameLogic(
            config: .reference,
            sceneSize: CGSize(width: 390, height: 844),
            seed: 4
        )
        logic.forcedDirections = [.right, .right, .right, .right]
        logic.start(at: 0)
        let start = logic.geometry.arrowCenter(for: .topLeft)
        _ = logic.beginGesture(at: start, time: 0.1)
        _ = logic.endGesture(at: start, time: 0.11)
        _ = logic.applySwipe(.left, on: .topLeft, at: 0.2)
        XCTAssertEqual(logic.score, 0)
    }
}

private extension SwipeFastInputOutcome {
    var scoreValue: Int? {
        if case .correct(_, let score, _) = self { return score }
        return nil
    }
}

final class SwipeFastPersistenceTests: XCTestCase {
    @MainActor
    func testSwipeFastIsRegisteredWithHigherIsBetterScoring() {
        let ids = GameRegistry.modules.map { $0.descriptor.id }
        XCTAssertEqual(ids.filter { $0 == "swipeFast" }.count, 1)
        XCTAssertTrue(ids.contains("directions"))
        XCTAssertEqual(GameRegistry.descriptor(for: "swipeFast"), SwipeFastGameModule.descriptor)
        XCTAssertEqual(SwipeFastGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testResultUsesHigherIsBetterPointScore() {
        let summary = SwipeFastSessionSummary(
            score: 71,
            duration: 23.6,
            correctSwipes: 71,
            ignoredGestures: 2,
            wrongSwipes: 0,
            expiredBox: .bottomLeft,
            endReason: .expired,
            averageReactionTime: 0.4,
            bestReactionTime: 0.2
        )
        let result = SwipeFastResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "swipeFast")
        XCTAssertEqual(result.score, 71)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "SwipeFastPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "swipeFast", score: 71, duration: 24))
        _ = store.record(GameResult(gameID: "swipeFast", score: 40, duration: 18))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "swipeFast")
        XCTAssertEqual(restored.bestScore, 71)
        XCTAssertEqual(restored.lastScore, 40)
        XCTAssertEqual(restored.averageScore, 55.5, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
