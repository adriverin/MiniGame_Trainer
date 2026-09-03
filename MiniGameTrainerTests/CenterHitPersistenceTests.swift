import XCTest
@testable import MiniGameTrainer

@MainActor
final class CenterHitPersistenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "CenterHitPersistenceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testHigherPrecisionReplacesPersonalBestAndLowerPrecisionDoesNot() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(9_789))
        store.record(result(9_640))
        XCTAssertEqual(store.bestScore(for: "centerHit"), 9_789)
        XCTAssertEqual(store.statistics(for: "centerHit").lastScore, 9_640)
        store.record(result(9_822))
        XCTAssertEqual(store.bestScore(for: "centerHit"), 9_822)
        XCTAssertEqual(store.statistics(for: "centerHit").previousBestScore, 9_789)
    }

    func testBasisPointPrecisionPersistsWithoutAffectingDisplay() {
        let store = StatisticsStore(userDefaults: defaults)
        store.record(result(9_789))
        let reloaded = StatisticsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.bestScore(for: "centerHit"), 9_789)
        XCTAssertEqual(CenterHitGameModule.descriptor.scorePresentation.formatted(reloaded.bestScore(for: "centerHit")), "97.89%")
    }

    func testRegistryContainsAllExistingGamesAndCenterHitWithCorrectDirections() {
        XCTAssertEqual(PianoGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(TrampboxGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(ReactGameModule.descriptor.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(TowerStackGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        XCTAssertEqual(CenterHitGameModule.descriptor.scorePresentation.comparison, .higherIsBetter)
        let ids = Set(GameRegistry.modules.map { $0.descriptor.id })
        XCTAssertTrue(["piano", "trampbox", "react", "towerStack", "centerHit", "keepUp", "timesUp", "grid", "trace", "directions", "swipeFast"].allSatisfy(ids.contains))
    }

    private func result(_ score: Int) -> GameResult {
        GameResult(
            gameID: "centerHit",
            score: score,
            scorePresentation: .precisionPercent,
            duration: 10
        )
    }
}
