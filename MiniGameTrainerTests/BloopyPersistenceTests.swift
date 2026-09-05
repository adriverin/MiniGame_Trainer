import XCTest
@testable import MiniGameTrainer

final class BloopyPersistenceTests: XCTestCase {
    @MainActor
    func testBloopyIsRegisteredWithHigherIsBetterScoring() {
        let ids = GameRegistry.modules.map { $0.descriptor.id }
        XCTAssertEqual(ids.filter { $0 == "bloopy" }.count, 1)
        XCTAssertTrue(ids.contains("swipeFast"))
        XCTAssertTrue(ids.contains("bloopy"))
        XCTAssertEqual(GameRegistry.descriptor(for: "bloopy"), BloopyGameModule.descriptor)
        XCTAssertEqual(BloopyGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testResultUsesHigherIsBetterPointScore() {
        let summary = BloopySessionSummary(
            score: 554,
            duration: 72,
            landings: 99,
            maxWorldY: 18_000,
            redPlatformCount: 12
        )
        let result = BloopyResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "bloopy")
        XCTAssertEqual(result.score, 554)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "BloopyPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "bloopy", score: 120, duration: 20))
        _ = store.record(GameResult(gameID: "bloopy", score: 80, duration: 14))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "bloopy")
        XCTAssertEqual(restored.bestScore, 120)
        XCTAssertEqual(restored.lastScore, 80)
        XCTAssertEqual(restored.averageScore, 100, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
