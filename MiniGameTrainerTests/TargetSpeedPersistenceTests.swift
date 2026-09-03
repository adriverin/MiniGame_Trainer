import XCTest
@testable import MiniGameTrainer

final class TargetSpeedPersistenceTests: XCTestCase {
    @MainActor
    func testTargetSpeedIsRegisteredLastWithHigherIsBetterScoring() {
        let ids = GameRegistry.modules.map { $0.descriptor.id }
        XCTAssertEqual(ids.filter { $0 == "targetSpeed" }.count, 1)
        XCTAssertEqual(ids.last, "targetSpeed")
        XCTAssertEqual(GameRegistry.descriptor(for: "targetSpeed"), TargetSpeedGameModule.descriptor)
        XCTAssertEqual(TargetSpeedGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(ids[11], "swipeFast")
    }

    @MainActor
    func testResultUsesHigherIsBetterPointScore() {
        let summary = TargetSpeedSessionSummary(
            score: 731,
            duration: 171.0,
            livesRemaining: 0,
            hits: 731,
            misses: 3,
            ignoredTaps: 4,
            endReason: .outOfLives,
            averageReactionTime: 0.32,
            bestReactionTime: 0.11
        )
        let result = TargetSpeedResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "targetSpeed")
        XCTAssertEqual(result.score, 731)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "TargetSpeedPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "targetSpeed", score: 731, duration: 171))
        _ = store.record(GameResult(gameID: "targetSpeed", score: 400, duration: 90))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "targetSpeed")
        XCTAssertEqual(restored.bestScore, 731)
        XCTAssertEqual(restored.lastScore, 400)
        XCTAssertEqual(restored.averageScore, 565.5, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
