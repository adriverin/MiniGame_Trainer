import XCTest
@testable import MiniGameTrainer

@MainActor
final class ColorReflexPersistenceTests: XCTestCase {
    func testColorReflexIsRegisteredWithHigherIsBetterPoints() {
        let ids = GameRegistry.modules.map { $0.descriptor.id }
        XCTAssertEqual(ids.filter { $0 == "colorReflex" }.count, 1)
        XCTAssertEqual(ids.last, "colorReflex")
        XCTAssertEqual(GameRegistry.descriptor(for: "colorReflex"), ColorReflexGameModule.descriptor)
        XCTAssertEqual(ColorReflexGameModule.descriptor.scorePresentation, .points)
        XCTAssertEqual(ColorReflexGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertNotEqual(ColorReflexGameModule.descriptor.scorePresentation, .reactionMilliseconds)
    }

    func testResultUsesIntegerPointScore() throws {
        let summary = ColorReflexSessionSummary(
            score: 16,
            duration: 41.4,
            reactionTimes: [0.218, 0.219, 0.214],
            prematureTapCount: 0,
            endReason: .timeExpired
        )
        let result = ColorReflexResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "colorReflex")
        XCTAssertEqual(result.score, 16)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(result.averageReactionTime ?? 0, (0.218 + 0.219 + 0.214) / 3, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(result.bestReactionTime), 0.214, accuracy: 1e-12)
        XCTAssertEqual(result.metrics.first { $0.key == "premature" }?.value, "0")
    }

    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "ColorReflexPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "colorReflex", score: 16, duration: 41))
        _ = store.record(GameResult(gameID: "colorReflex", score: 9, duration: 41))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "colorReflex")
        XCTAssertEqual(restored.bestScore, 16)
        XCTAssertEqual(restored.lastScore, 9)
        XCTAssertEqual(restored.averageScore, 12.5, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }

    func testLowerScoreDoesNotReplacePersonalBest() {
        let suite = "ColorReflexPersistenceBest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "colorReflex", score: 12, duration: 41))
        _ = store.record(GameResult(gameID: "colorReflex", score: 8, duration: 41))
        XCTAssertEqual(store.bestScore(for: "colorReflex"), 12)
        XCTAssertEqual(store.statistics(for: "colorReflex").lastScore, 8)
        defaults.removePersistentDomain(forName: suite)
    }
}
