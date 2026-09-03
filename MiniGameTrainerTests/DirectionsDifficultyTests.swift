import XCTest
@testable import MiniGameTrainer

final class DirectionsDifficultyTests: XCTestCase {
    func testReferenceSequenceLengthSchedule() {
        let model = DirectionsDifficultyModel(config: .reference)
        let expected = [1: 3, 2: 4, 3: 5, 4: 6, 5: 7, 6: 8, 7: 9, 8: 10, 9: 11, 10: 12, 11: 13, 12: 14]
        for (level, length) in expected {
            XCTAssertEqual(model.sequenceLength(forLevel: level), length, "Level \(level)")
        }
    }

    func testLengthCapsBeyondReference() {
        let model = DirectionsDifficultyModel(config: .reference)
        XCTAssertEqual(model.sequenceLength(forLevel: 14), 16)
        XCTAssertEqual(model.sequenceLength(forLevel: 50), 16)
    }

    func testPresentationTimingIsConstantAcrossLevels() {
        let model = DirectionsDifficultyModel(config: .reference)
        XCTAssertEqual(model.arrowOnDuration(forLevel: 1), 0.600, accuracy: 1e-12)
        XCTAssertEqual(model.arrowOnDuration(forLevel: 12), 0.600, accuracy: 1e-12)
        XCTAssertEqual(model.interArrowGap(forLevel: 1), 0.266, accuracy: 1e-12)
        XCTAssertEqual(model.interArrowGap(forLevel: 12), 0.266, accuracy: 1e-12)
    }

    func testTotalPresentationMatchesOnPlusGapsPlusTransition() {
        let config = DirectionsGameConfig.reference
        let length = 8
        let expected = 8 * config.arrowOnDuration + 7 * config.interArrowGap + config.transitionToRecallDuration
        XCTAssertEqual(config.presentationDuration(forSequenceLength: length), expected, accuracy: 1e-12)
        XCTAssertEqual(expected, 7.012, accuracy: 0.001)
    }

    func testMonotonicPresentationClock() {
        var config = DirectionsGameConfig.reference
        config.arrowOnDuration = 0.600
        config.interArrowGap = 0.266
        config.transitionToRecallDuration = 0.350
        let logic = DirectionsGameLogic(config: config, seed: 1)
        logic.forcedSequence = [.up, .right, .down, .left]
        logic.start(at: 10)
        XCTAssertEqual(logic.state, .presenting)
        XCTAssertEqual(logic.visibleDirection, .up)
        logic.update(at: 10.599)
        XCTAssertEqual(logic.visibleDirection, .up)
        logic.update(at: 10.600)
        XCTAssertNil(logic.visibleDirection)
        logic.update(at: 10.866)
        XCTAssertEqual(logic.visibleDirection, .right)
        logic.update(at: 10 + 3 * (0.600 + 0.266) + 0.600)
        XCTAssertEqual(logic.state, .transitionToRecall)
        logic.update(at: 10 + config.presentationDuration(forSequenceLength: 4))
        XCTAssertEqual(logic.state, .recalling)
        XCTAssertNil(logic.visibleDirection)
    }
}

final class DirectionsPersistenceTests: XCTestCase {
    @MainActor
    func testDirectionsIsRegisteredAsSeventhGame() {
        XCTAssertEqual(GameRegistry.modules[5].descriptor.id, "keepUp")
        XCTAssertEqual(GameRegistry.modules[9].descriptor.id, "directions")
        XCTAssertEqual(GameRegistry.descriptor(for: "directions"), DirectionsGameModule.descriptor)
    }

    @MainActor
    func testStatisticsPersistBestLastAverageAndGamesPlayed() {
        let suite = "DirectionsPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        _ = store.record(GameResult(gameID: "directions", score: 88, duration: 170))
        _ = store.record(GameResult(gameID: "directions", score: 42, duration: 90))
        let restored = StatisticsStore(userDefaults: defaults).statistics(for: "directions")
        XCTAssertEqual(restored.bestScore, 88)
        XCTAssertEqual(restored.lastScore, 42)
        XCTAssertEqual(restored.averageScore, 65, accuracy: 1e-9)
        XCTAssertEqual(restored.gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }
}
