import XCTest
@testable import MiniGameTrainer

@MainActor
final class TimesUpPersistenceTests: XCTestCase {
    func testTimesUpIsRegisteredAsSeventhGame() {
        XCTAssertEqual(GameRegistry.modules[5].descriptor.id, "keepUp")
        XCTAssertEqual(GameRegistry.modules[6].descriptor.id, "timesUp")
        XCTAssertEqual(GameRegistry.descriptor(for: "timesUp"), TimesUpGameModule.descriptor)
        XCTAssertEqual(TimesUpGameModule.descriptor.scorePresentation, .timingErrorSeconds)
        XCTAssertEqual(TimesUpGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
    }

    func testLowerErrorReplacesPersonalBestAndHigherErrorDoesNot() {
        let suite = "TimesUpPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(60))
        store.record(result(90))
        XCTAssertEqual(store.bestScore(for: "timesUp"), 60)
        XCTAssertEqual(store.statistics(for: "timesUp").lastScore, 90)
        store.record(result(40))
        XCTAssertEqual(store.bestScore(for: "timesUp"), 40)
        XCTAssertEqual(store.statistics(for: "timesUp").previousBestScore, 60)
        defaults.removePersistentDomain(forName: suite)
    }

    func testZeroIsAValidFirstPersonalBest() {
        let suite = "TimesUpPersistenceZero.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(0))
        XCTAssertEqual(store.bestScore(for: "timesUp"), 0)
        XCTAssertEqual(store.statistics(for: "timesUp").gamesPlayed, 1)
        store.record(result(10))
        XCTAssertEqual(store.bestScore(for: "timesUp"), 0)
        XCTAssertEqual(TimesUpGameModule.descriptor.scorePresentation.formatted(0), "0.00 s")
        defaults.removePersistentDomain(forName: suite)
    }

    func testMillisecondScoreFormatsAsSecondsWithoutChangingIntegerPersistence() {
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formatted(60), "0.06 s")
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formatted(1), "0.00 s")
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formattedAverage(64), "0.06 s")
        let suite = "TimesUpPersistenceFormat.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        StatisticsStore(userDefaults: defaults).record(result(64))
        let reloaded = StatisticsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.bestScore(for: "timesUp"), 64)
        XCTAssertEqual(
            TimesUpGameModule.descriptor.scorePresentation.formatted(reloaded.bestScore(for: "timesUp")),
            "0.06 s"
        )
        defaults.removePersistentDomain(forName: suite)
    }

    private func result(_ score: Int) -> GameResult {
        GameResult(
            gameID: "timesUp",
            score: score,
            scorePresentation: .timingErrorSeconds,
            duration: 30
        )
    }
}
