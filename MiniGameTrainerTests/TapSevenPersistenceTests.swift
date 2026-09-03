import XCTest
@testable import MiniGameTrainer

@MainActor
final class TapSevenPersistenceTests: XCTestCase {
    func testTapSevenIsRegisteredAfterExistingGames() {
        XCTAssertEqual(GameRegistry.modules[5].descriptor.id, "keepUp")
        XCTAssertEqual(GameRegistry.modules[6].descriptor.id, "timesUp")
        XCTAssertEqual(GameRegistry.descriptor(for: "tapSeven"), TapSevenGameModule.descriptor)
        XCTAssertEqual(TapSevenGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(TapSevenGameModule.descriptor.scorePresentation.formatted(0), "0.00 s")
        XCTAssertTrue(GameRegistry.modules.contains { $0.descriptor.id == "tapSeven" })
        XCTAssertNotEqual(TapSevenGameModule.descriptor.id, TimesUpGameModule.descriptor.id)
    }

    func testLowerErrorReplacesPersonalBestAndHigherErrorDoesNot() {
        let suite = "TapSevenPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(40))
        store.record(result(80))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 40)
        XCTAssertEqual(store.statistics(for: "tapSeven").lastScore, 80)
        store.record(result(20))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 20)
        XCTAssertEqual(store.statistics(for: "tapSeven").previousBestScore, 40)
        defaults.removePersistentDomain(forName: suite)
    }

    func testZeroIsAValidFirstPersonalBest() {
        let suite = "TapSevenPersistenceZero.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(0))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 0)
        XCTAssertEqual(store.statistics(for: "tapSeven").gamesPlayed, 1)
        store.record(result(10))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 0)
        XCTAssertEqual(TapSevenGameModule.descriptor.scorePresentation.formatted(0), "0.00 s")
        defaults.removePersistentDomain(forName: suite)
    }

    func testExistingFourHundredthsBeatsEightHundredthsAndLosesToTwoAndZero() {
        let suite = "TapSevenPersistenceCompare.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(40))
        store.record(result(80))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 40)
        store.record(result(20))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 20)
        store.record(result(0))
        XCTAssertEqual(store.bestScore(for: "tapSeven"), 0)
        defaults.removePersistentDomain(forName: suite)
    }

    private func result(_ score: Int) -> GameResult {
        GameResult(
            gameID: "tapSeven",
            score: score,
            scorePresentation: TapSevenGameConfig.scorePresentation,
            duration: 7
        )
    }
}
