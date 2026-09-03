import XCTest
@testable import MiniGameTrainer

final class TracePersistenceTests: XCTestCase {
    @MainActor
    func testTraceIsRegisteredWithHigherIsBetterPoints() {
        XCTAssertEqual(GameRegistry.descriptor(for: "trace"), TraceGameModule.descriptor)
        XCTAssertEqual(TraceGameModule.descriptor.scorePresentation, .points)
        XCTAssertEqual(TraceGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testResultPersistsBestLastAverageAndGamesPlayed() {
        let suite = "TracePersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        let first = TraceResultBuilder.makeResult(
            from: TraceSessionSummary(score: 98, duration: 110, patternsCompleted: 20, patternsFailed: 1, segmentsScored: 98, accuracy: 0.95)
        )
        XCTAssertEqual(first.gameID, "trace")
        XCTAssertEqual(first.score, 98)
        _ = store.record(first)
        _ = store.record(GameResult(gameID: "trace", score: 40, duration: 50))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "trace")
        XCTAssertEqual(restored.bestScore, 98)
        XCTAssertEqual(restored.lastScore, 40)
        XCTAssertEqual(restored.averageScore, 69, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
