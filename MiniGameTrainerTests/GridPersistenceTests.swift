import XCTest
@testable import MiniGameTrainer

final class GridPersistenceTests: XCTestCase {
    @MainActor
    func testGridIsRegisteredAfterKeepUp() {
        XCTAssertEqual(GameRegistry.modules[5].descriptor.id, "keepUp")
        XCTAssertEqual(GameRegistry.modules[6].descriptor.id, "timesUp")
        XCTAssertEqual(GameRegistry.modules[7].descriptor.id, "grid")
        XCTAssertEqual(GameRegistry.descriptor(for: "grid"), GridGameModule.descriptor)
        XCTAssertEqual(GridGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(GridGameModule.descriptor.scorePresentation.formatted(120), "120")
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "GridPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "grid", score: 120, duration: 40))
        _ = store.record(GameResult(gameID: "grid", score: 77, duration: 30))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "grid")
        XCTAssertEqual(restored.bestScore, 120)
        XCTAssertEqual(restored.lastScore, 77)
        XCTAssertEqual(restored.averageScore, 98.5, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
