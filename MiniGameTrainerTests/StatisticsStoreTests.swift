import XCTest
@testable import MiniGameTrainer

@MainActor
final class StatisticsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "StatisticsStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func result(score: Int, reaction: TimeInterval? = nil) -> GameResult {
        GameResult(gameID: "piano", score: score, duration: 10, bestReactionTime: reaction)
    }

    func testPersonalBestOnlyReplacedByHigherScore() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(score: 50))
        XCTAssertEqual(store.bestScore(for: "piano"), 50)

        store.record(result(score: 30))
        XCTAssertEqual(store.bestScore(for: "piano"), 50)
        XCTAssertEqual(store.statistics(for: "piano").lastScore, 30)

        store.record(result(score: 80))
        XCTAssertEqual(store.bestScore(for: "piano"), 80)
        XCTAssertEqual(store.statistics(for: "piano").previousBestScore, 50)
    }

    func testReactPersonalBestOnlyReplacedByLowerAverage() {
        let store = StatisticsStore(userDefaults: defaults)
        let presentation = ScorePresentation.reactionMilliseconds
        store.record(GameResult(gameID: "react", score: 288, scorePresentation: presentation, duration: 10))
        store.record(GameResult(gameID: "react", score: 310, scorePresentation: presentation, duration: 10))
        XCTAssertEqual(store.bestScore(for: "react"), 288)
        XCTAssertEqual(store.statistics(for: "react").lastScore, 310)

        store.record(GameResult(gameID: "react", score: 255, scorePresentation: presentation, duration: 10))
        XCTAssertEqual(store.bestScore(for: "react"), 255)
        XCTAssertEqual(store.statistics(for: "react").previousBestScore, 288)
    }

    @MainActor
    func testRegisteredGameScoreDirectionsDoNotRegress() {
        XCTAssertEqual(PianoGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TrampboxGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(ReactGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(TowerStackGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(KeepUpGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TimesUpGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(GridGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TraceGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(DirectionsGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TapSevenGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(SwipeFastGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TargetSpeedGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(BloopyGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        let moduleIDs = GameRegistry.modules.map { $0.descriptor.id }
        let ids = Set(moduleIDs)
        XCTAssertEqual(ids.count, moduleIDs.count)
        XCTAssertTrue(ids.contains("piano"))
        XCTAssertTrue(ids.contains("trampbox"))
        XCTAssertTrue(ids.contains("react"))
        XCTAssertTrue(ids.contains("towerStack"))
        XCTAssertTrue(ids.contains("keepUp"))
        XCTAssertTrue(ids.contains("timesUp"))
        XCTAssertTrue(ids.contains("grid"))
        XCTAssertTrue(ids.contains("trace"))
        XCTAssertTrue(ids.contains("directions"))
        XCTAssertTrue(ids.contains("tapSeven"))
        XCTAssertTrue(ids.contains("swipeFast"))
        XCTAssertTrue(ids.contains("targetSpeed"))
        XCTAssertTrue(ids.contains("bloopy"))
    }

    func testAggregatesAndBestReaction() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(score: 10, reaction: 0.4))
        store.record(result(score: 20, reaction: 0.3))
        store.record(result(score: 30, reaction: 0.5))
        let stats = store.statistics(for: "piano")
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(stats.totalScore, 60)
        XCTAssertEqual(stats.averageScore, 20, accuracy: 1e-9)
        XCTAssertEqual(stats.bestReactionTime!, 0.3, accuracy: 1e-9)
    }

    func testStatisticsPersistAcrossInstances() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(score: 157))
        store.record(GameResult(gameID: "other", score: 3, duration: 1))

        let reloaded = StatisticsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.bestScore(for: "piano"), 157)
        XCTAssertEqual(reloaded.statistics(for: "piano").gamesPlayed, 1)
        XCTAssertEqual(reloaded.bestScore(for: "other"), 3)
        XCTAssertEqual(reloaded.bestScore(for: "unknown"), 0)
    }

    func testResetClearsStatistics() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(score: 5))
        store.resetAll()
        XCTAssertEqual(store.bestScore(for: "piano"), 0)
        XCTAssertEqual(StatisticsStore(userDefaults: defaults).statistics(for: "piano").gamesPlayed, 0)
    }

    func testPreferencesPersist() {
        let preferences = UserPreferences(userDefaults: defaults)
        XCTAssertTrue(preferences.soundEnabled)
        XCTAssertTrue(preferences.hapticsEnabled)
        preferences.soundEnabled = false
        XCTAssertFalse(UserPreferences(userDefaults: defaults).soundEnabled)
    }
}
