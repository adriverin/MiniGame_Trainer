import XCTest
@testable import MiniGameTrainer

final class KeepUpPersistenceTests: XCTestCase {
    @MainActor
    func testKeepUpIsRegisteredAsSixthGame() {
        XCTAssertEqual(GameRegistry.modules.count, 6)
        XCTAssertEqual(GameRegistry.modules.last?.descriptor.id, "keepUp")
        XCTAssertEqual(GameRegistry.descriptor(for: "keepUp"), KeepUpGameModule.descriptor)
    }

    @MainActor
    func testResultUsesHigherIsBetterPointScore() {
        let summary = KeepUpSessionSummary(score: 41, duration: 30, bounces: [], peakBallSpeed: 900, platformTravel: 2_000)
        let result = KeepUpResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "keepUp")
        XCTAssertEqual(result.score, 41)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "KeepUpPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "keepUp", score: 12, duration: 10))
        _ = store.record(GameResult(gameID: "keepUp", score: 8, duration: 7))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "keepUp")
        XCTAssertEqual(restored.bestScore, 12)
        XCTAssertEqual(restored.lastScore, 8)
        XCTAssertEqual(restored.averageScore, 10, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
