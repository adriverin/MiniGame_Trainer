import XCTest
@testable import MiniGameTrainer

final class TimesUpGameLogicTests: XCTestCase {
    private func logic(_ mutate: (inout TimesUpGameConfig) -> Void = { _ in }) -> TimesUpGameLogic {
        var config = TimesUpGameConfig.reference
        mutate(&config)
        return TimesUpGameLogic(config: config)
    }

    func testExactHitProducesZeroError() {
        let logic = logic {
            $0.levelCount = 1
            $0.targetDurations = [5]
        }
        logic.start(at: 0)
        guard case .finished(let result) = logic.handleTap(at: 5) else {
            return XCTFail("Expected finished tap")
        }
        XCTAssertEqual(result.signedError, 0, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .exact)
        XCTAssertEqual(logic.state, .finished)
    }

    func testEarlyTapIsNegativeAndMarkedEarly() {
        let logic = logic {
            $0.levelCount = 1
            $0.targetDurations = [5]
        }
        logic.start(at: 0)
        guard case .finished(let result) = logic.handleTap(at: 4.97) else {
            return XCTFail("Expected finished tap")
        }
        XCTAssertEqual(result.signedError, -0.03, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0.03, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .early)
    }

    func testLateTapIsPositiveAndMarkedLate() {
        let logic = logic {
            $0.levelCount = 1
            $0.targetDurations = [5]
        }
        logic.start(at: 0)
        guard case .finished(let result) = logic.handleTap(at: 5.01) else {
            return XCTFail("Expected finished tap")
        }
        XCTAssertEqual(result.signedError, 0.01, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0.01, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .late)
    }

    func testBarVisibilityBoundaryIsHalfDuration() {
        let logic = logic {
            $0.targetDurations = [10]
            $0.visibilityFraction = 0.5
        }
        logic.start(at: 0)
        logic.update(at: 4.999)
        XCTAssertEqual(logic.state, .visible(level: 1))
        XCTAssertTrue(logic.isBarVisible(at: 4.999))
        logic.update(at: 5)
        XCTAssertEqual(logic.state, .hidden(level: 1))
        XCTAssertFalse(logic.isBarVisible(at: 5))
        XCTAssertFalse(TimesUpScoring.isBarVisible(elapsed: 5, target: 10, visibilityFraction: 0.5))
        XCTAssertTrue(TimesUpScoring.isBarVisible(elapsed: 4.999, target: 10, visibilityFraction: 0.5))
    }

    func testLinearProgressDuringVisiblePhase() {
        XCTAssertEqual(TimesUpScoring.progress(elapsed: 0, target: 8), 1, accuracy: 1e-12)
        XCTAssertEqual(TimesUpScoring.progress(elapsed: 2, target: 8), 0.75, accuracy: 1e-12)
        XCTAssertEqual(TimesUpScoring.progress(elapsed: 4, target: 8), 0.5, accuracy: 1e-12)
        XCTAssertEqual(TimesUpScoring.progress(elapsed: 8, target: 8), 0, accuracy: 1e-12)
    }

    func testThreeLevelsThenFinishedWithNoFourth() {
        let logic = logic { $0.targetDurations = [10, 10, 10] }
        XCTAssertEqual(logic.handleTap(at: 0), .started)
        guard case .scored(let first) = logic.handleTap(at: 10) else { return XCTFail("Level 1") }
        XCTAssertEqual(first.levelIndex, 1)
        logic.startNextLevel(at: 12)
        guard case .scored(let second) = logic.handleTap(at: 22) else { return XCTFail("Level 2") }
        XCTAssertEqual(second.levelIndex, 2)
        logic.startNextLevel(at: 24)
        guard case .finished(let third) = logic.handleTap(at: 34) else { return XCTFail("Level 3") }
        XCTAssertEqual(third.levelIndex, 3)
        XCTAssertEqual(logic.state, .finished)
        XCTAssertEqual(logic.handleTap(at: 35), .ignored)
        XCTAssertEqual(logic.results.count, 3)
    }

    func testStartTapIsNotScoredAsAnEstimate() {
        let logic = logic()
        XCTAssertEqual(logic.handleTap(at: 1), .started)
        XCTAssertTrue(logic.results.isEmpty)
        XCTAssertEqual(logic.state, .visible(level: 1))
        XCTAssertEqual(logic.elapsed(at: 1), 0, accuracy: 1e-12)
    }

    func testEarlyTapBeforeDisappearanceIsAccepted() {
        let logic = logic {
            $0.levelCount = 1
            $0.targetDurations = [10]
        }
        logic.start(at: 0)
        logic.update(at: 3)
        XCTAssertEqual(logic.state, .visible(level: 1))
        guard case .finished(let result) = logic.handleTap(at: 3) else {
            return XCTFail("Early visible tap should score")
        }
        XCTAssertEqual(result.signedError, -7, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .early)
    }

    func testSecondTapAfterEstimateIsIgnored() {
        let logic = logic { $0.levelCount = 3 }
        logic.start(at: 0)
        XCTAssertNotEqual(logic.handleTap(at: 10), .ignored)
        XCTAssertEqual(logic.handleTap(at: 10.01), .ignored)
        XCTAssertEqual(logic.results.count, 1)
    }

    func testPauseDuringTimingRestartsLevelInsteadOfScoring() {
        let logic = logic {
            $0.levelCount = 1
            $0.targetDurations = [10]
        }
        logic.start(at: 0)
        logic.update(at: 4)
        logic.pause(at: 4)
        XCTAssertEqual(logic.state, .paused)
        logic.update(at: 20)
        XCTAssertEqual(logic.elapsed(at: 20), 0, accuracy: 1e-12)
        logic.resume(at: 20)
        XCTAssertEqual(logic.state, .ready)
        XCTAssertTrue(logic.results.isEmpty)
        logic.start(at: 21)
        guard case .finished(let result) = logic.handleTap(at: 31) else {
            return XCTFail("Restarted level should score from the new start")
        }
        XCTAssertEqual(result.actualElapsed, 10, accuracy: 1e-12)
        XCTAssertEqual(result.signedError, 0, accuracy: 1e-12)
    }

    func testReadyStateSurvivesPauseWithoutResettingLevelIndex() {
        let logic = logic()
        logic.start(at: 0)
        _ = logic.handleTap(at: 10)
        logic.startNextLevel(at: 11)
        logic.pause(at: 12)
        logic.resume(at: 40)
        logic.start(at: 41)
        XCTAssertEqual(logic.currentLevelNumber, 2)
        XCTAssertEqual(logic.results.count, 1)
    }
}

final class TimesUpTimingTests: XCTestCase {
    func testProgressIsIndependentOfUpdateFrequency() {
        let at60 = simulatedProgress(framesPerSecond: 60, duration: 4)
        let at120 = simulatedProgress(framesPerSecond: 120, duration: 4)
        XCTAssertEqual(at60, at120, accuracy: 1e-12)
        XCTAssertEqual(at60, 0.6, accuracy: 1e-12)
    }

    func testElapsedUsesTimestampsNotFrameCount() {
        let logic = TimesUpGameLogic(config: {
            var config = TimesUpGameConfig.reference
            config.targetDurations = [10]
            return config
        }())
        logic.start(at: 100)
        logic.update(at: 100.016)
        logic.update(at: 103)
        XCTAssertEqual(logic.elapsed(at: 103), 3, accuracy: 1e-12)
        XCTAssertEqual(logic.progress(at: 103), 0.7, accuracy: 1e-12)
    }

    func testAutoPlaySignedErrorMapping() {
        XCTAssertEqual(TimesUpDebugOptions(autoPlay: .exact).signedError(forLevelIndex: 0), 0)
        XCTAssertEqual(TimesUpDebugOptions(autoPlay: .offset(0.01)).signedError(forLevelIndex: 1), 0.01)
        XCTAssertEqual(TimesUpDebugOptions(autoPlay: .offset(-0.03)).signedError(forLevelIndex: 2), -0.03)
        let scripted = TimesUpDebugOptions(autoPlay: .scripted([0.01, -0.03, -0.16]))
        XCTAssertEqual(scripted.signedError(forLevelIndex: 0), 0.01)
        XCTAssertEqual(scripted.signedError(forLevelIndex: 1), -0.03)
        XCTAssertEqual(scripted.signedError(forLevelIndex: 2), -0.16)
    }

    private func simulatedProgress(framesPerSecond: Int, duration: TimeInterval) -> Double {
        var config = TimesUpGameConfig.reference
        config.targetDurations = [10]
        let logic = TimesUpGameLogic(config: config)
        logic.start(at: 0)
        let frameCount = Int(duration * Double(framesPerSecond))
        for frame in 1...frameCount {
            logic.update(at: Double(frame) / Double(framesPerSecond))
        }
        return logic.progress(at: duration)
    }
}
