import XCTest
@testable import MiniGameTrainer

final class TapSevenGameLogicTests: XCTestCase {
    private func logic(_ mutate: (inout TapSevenGameConfig) -> Void = { _ in }) -> TapSevenGameLogic {
        var config = TapSevenGameConfig.reference
        mutate(&config)
        return TapSevenGameLogic(config: config)
    }

    func testExactHitProducesZeroError() {
        let logic = logic()
        logic.start(at: 0)
        guard case .submitted(let result) = logic.handleTap(at: 7) else {
            return XCTFail("Expected submitted tap")
        }
        XCTAssertEqual(result.signedError, 0, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .exact)
        XCTAssertTrue(result.isPerfect)
        XCTAssertEqual(logic.state, .submitted)
    }

    func testEarlyTapIsNegativeAndScores() {
        let logic = logic()
        logic.start(at: 0)
        guard case .submitted(let result) = logic.handleTap(at: 6.93) else {
            return XCTFail("Expected submitted tap")
        }
        XCTAssertEqual(result.signedError, -0.07, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0.07, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .early)
        XCTAssertFalse(result.isPerfect)
    }

    func testLateTapIsPositiveAndScores() {
        let logic = logic()
        logic.start(at: 0)
        guard case .submitted(let result) = logic.handleTap(at: 7.12) else {
            return XCTFail("Expected submitted tap")
        }
        XCTAssertEqual(result.signedError, 0.12, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0.12, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .late)
        XCTAssertFalse(result.isPerfect)
    }

    func testLinearProgressClampsAfterTarget() {
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 0, target: 7), 0, accuracy: 1e-12)
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 1.75, target: 7), 0.25, accuracy: 1e-12)
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 3.5, target: 7), 0.5, accuracy: 1e-12)
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 5.25, target: 7), 0.75, accuracy: 1e-12)
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 7, target: 7), 1, accuracy: 1e-12)
        XCTAssertEqual(TapSevenScoring.progress(elapsed: 9, target: 7), 1, accuracy: 1e-12)
    }

    func testStartTapIsNotScored() {
        let logic = logic()
        XCTAssertEqual(logic.handleTap(at: 1), .started)
        XCTAssertNil(logic.result)
        XCTAssertEqual(logic.state, .timing)
        XCTAssertEqual(logic.elapsed(at: 1), 0, accuracy: 1e-12)
    }

    func testSameTimestampAsStartDoesNotSubmit() {
        let logic = logic()
        logic.start(at: 10)
        XCTAssertEqual(logic.handleTap(at: 10), .ignored)
        XCTAssertEqual(logic.state, .timing)
        XCTAssertNil(logic.result)
    }

    func testSecondTapAfterSubmitIsIgnored() {
        let logic = logic()
        logic.start(at: 0)
        XCTAssertNotEqual(logic.handleTap(at: 7), .ignored)
        XCTAssertEqual(logic.handleTap(at: 7.01), .ignored)
        XCTAssertEqual(logic.handleTap(at: 8), .ignored)
        XCTAssertEqual(logic.result!.actualElapsed, 7, accuracy: 1e-12)
    }

    func testOnlyFirstTimingTimestampCounts() {
        let logic = logic()
        logic.start(at: 0)
        guard case .submitted(let first) = logic.handleTap(at: 6.5) else {
            return XCTFail("First tap should submit")
        }
        XCTAssertEqual(logic.handleTap(at: 7.0), .ignored)
        XCTAssertEqual(first.actualElapsed, 6.5, accuracy: 1e-12)
        XCTAssertEqual(logic.result!.tapTimestamp, 6.5, accuracy: 1e-12)
    }

    func testPauseDuringTimingRestartsAttempt() {
        let logic = logic()
        logic.start(at: 0)
        logic.update(at: 4)
        logic.pause(at: 4)
        XCTAssertEqual(logic.state, .paused)
        logic.update(at: 20)
        XCTAssertEqual(logic.elapsed(at: 20), 0, accuracy: 1e-12)
        logic.resume(at: 20)
        XCTAssertEqual(logic.state, .ready)
        XCTAssertNil(logic.result)
        logic.start(at: 21)
        guard case .submitted(let result) = logic.handleTap(at: 28) else {
            return XCTFail("Restarted attempt should score from the new start")
        }
        XCTAssertEqual(result.actualElapsed, 7, accuracy: 1e-12)
        XCTAssertEqual(result.signedError, 0, accuracy: 1e-12)
        XCTAssertEqual(result.startTimestamp, 21, accuracy: 1e-12)
    }

    func testTimeoutAutoSubmitsLateWithoutEndingAtSeven() {
        var config = TapSevenGameConfig.reference
        config.maxAttemptDuration = 12
        let logic = TapSevenGameLogic(config: config)
        logic.start(at: 0)
        logic.update(at: 7)
        XCTAssertEqual(logic.state, .timing)
        XCTAssertEqual(logic.progress(at: 7), 1, accuracy: 1e-12)
        logic.update(at: 11.9)
        XCTAssertEqual(logic.state, .timing)
        logic.update(at: 12)
        XCTAssertEqual(logic.state, .submitted)
        XCTAssertEqual(logic.result!.actualElapsed, 12, accuracy: 1e-12)
        XCTAssertEqual(logic.result!.signedError, 5, accuracy: 1e-12)
        XCTAssertEqual(logic.result!.timedOut, true)
    }

    func testSingleAttemptSession() {
        XCTAssertEqual(TapSevenGameConfig.reference.attemptCount, 1)
        XCTAssertEqual(TapSevenGameConfig.reference.targetDuration, 7.0, accuracy: 1e-12)
    }
}

final class TapSevenScoringTests: XCTestCase {
    func testDisplayFormattingUsesTwoDecimals() {
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(1.315), "1.31")
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(6.996), "7.00")
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(7.004), "7.00")
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(7.006), "7.01")
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(0), "0.00")
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(7), "7.00")
    }

    func testDisplayedSevenDoesNotImplyPerfect() {
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(6.996), "7.00")
        XCTAssertFalse(
            TapSevenScoring.isPerfect(
                signedError: TapSevenScoring.signedError(elapsed: 6.996, target: 7),
                perfectThreshold: 0.0005
            )
        )
        XCTAssertEqual(TapSevenFormatter.displayedElapsed(7.004), "7.00")
        XCTAssertFalse(
            TapSevenScoring.isPerfect(
                signedError: TapSevenScoring.signedError(elapsed: 7.004, target: 7),
                perfectThreshold: 0.0005
            )
        )
    }

    func testPerfectThresholdInsideBoundaryAndOutside() {
        let threshold = TapSevenGameConfig.reference.perfectThreshold
        XCTAssertEqual(threshold, 0.0005, accuracy: 1e-12)
        XCTAssertTrue(TapSevenScoring.isPerfect(signedError: 0, perfectThreshold: threshold))
        XCTAssertTrue(TapSevenScoring.isPerfect(signedError: -0.0002, perfectThreshold: threshold))
        XCTAssertTrue(TapSevenScoring.isPerfect(signedError: 0.000499, perfectThreshold: threshold))
        XCTAssertFalse(TapSevenScoring.isPerfect(signedError: 0.0005, perfectThreshold: threshold))
        XCTAssertFalse(TapSevenScoring.isPerfect(signedError: 0.0007, perfectThreshold: threshold))
        XCTAssertFalse(TapSevenScoring.isPerfect(signedError: 0.0009, perfectThreshold: threshold))
        XCTAssertEqual(TapSevenScoring.direction(signedError: -0.0002, perfectThreshold: threshold), .exact)
        XCTAssertEqual(TapSevenScoring.direction(signedError: 0.0007, perfectThreshold: threshold), .late)
        XCTAssertEqual(TapSevenScoring.direction(signedError: -0.0007, perfectThreshold: threshold), .early)
    }

    func testZeroIsAValidScore() {
        XCTAssertEqual(TapSevenScoring.scoreMilliseconds(absoluteError: 0), 0)
        XCTAssertEqual(TapSevenGameConfig.scorePresentation.formatted(0), "0.00 s")
        XCTAssertEqual(TapSevenGameConfig.scorePresentation.comparison, .lowerIsBetter)
    }

    func testMillisecondPersistenceRoundsRawError() {
        XCTAssertEqual(TapSevenScoring.scoreMilliseconds(absoluteError: 0.0002), 0)
        XCTAssertEqual(TapSevenScoring.scoreMilliseconds(absoluteError: 0.0009), 1)
        XCTAssertEqual(TapSevenScoring.scoreMilliseconds(absoluteError: 0.0376), 38)
        XCTAssertEqual(TapSevenGameConfig.scorePresentation.formatted(38), "0.04 s")
        XCTAssertEqual(TapSevenGameConfig.scorePresentation.formatted(1), "0.00 s")
    }

    func testGeometryUsesConfiguredRatios() {
        let geometry = TapSevenGeometry(sceneSize: CGSize(width: 390, height: 844), config: .reference)
        XCTAssertEqual(geometry.ringCenter.x, 195, accuracy: 0.001)
        XCTAssertEqual(geometry.ringCenter.y, 844 * 0.51, accuracy: 0.001)
        XCTAssertEqual(geometry.ringRadius, 390 * 0.59 / 2, accuracy: 0.001)
        XCTAssertEqual(geometry.strokeWidth, 390 * 0.064, accuracy: 0.001)
        XCTAssertEqual(geometry.instructionPosition.y, 844 * 0.30, accuracy: 0.001)
    }

    @MainActor
    func testResultBuilderPersistsMillisecondsAndDirection() {
        let attempt = TapSevenAttemptResult(
            targetDuration: 7,
            actualElapsed: 7.12,
            signedError: 0.12,
            absoluteError: 0.12,
            isPerfect: false,
            direction: .late,
            startTimestamp: 0,
            tapTimestamp: 7.12,
            timedOut: false
        )
        let gameResult = TapSevenResultBuilder.makeResult(from: TapSevenSessionSummary(result: attempt, duration: 7.12))
        XCTAssertEqual(gameResult.gameID, "tapSeven")
        XCTAssertEqual(gameResult.score, 120)
        XCTAssertEqual(gameResult.scorePresentation.formatted(gameResult.score), "0.12 s")
        XCTAssertEqual(gameResult.metrics.contains(where: { $0.key == "direction" }), true)
        XCTAssertEqual(gameResult.metrics.contains(where: { $0.value == "Late" }), true)
    }
}

final class TapSevenTimingTests: XCTestCase {
    func testProgressIsIndependentOfUpdateFrequency() {
        let at60 = simulatedProgress(framesPerSecond: 60, duration: 3.5)
        let at120 = simulatedProgress(framesPerSecond: 120, duration: 3.5)
        XCTAssertEqual(at60, at120, accuracy: 1e-12)
        XCTAssertEqual(at60, 0.5, accuracy: 1e-12)
    }

    func testElapsedUsesTimestampsNotFrameCount() {
        let logic = TapSevenGameLogic(config: .reference)
        logic.start(at: 100)
        logic.update(at: 100.016)
        logic.update(at: 103)
        XCTAssertEqual(logic.elapsed(at: 103), 3, accuracy: 1e-12)
        XCTAssertEqual(logic.progress(at: 103), 3 / 7, accuracy: 1e-12)
        XCTAssertEqual(logic.displayedElapsed(at: 103), "3.00")
    }

    func testScoreDoesNotDependOnDisplayedText() {
        let logic = TapSevenGameLogic(config: .reference)
        logic.start(at: 0)
        guard case .submitted(let result) = logic.handleTap(at: 6.996) else {
            return XCTFail("Expected submit")
        }
        XCTAssertEqual(logic.displayedElapsed(at: 6.996), "7.00")
        XCTAssertEqual(result.actualElapsed, 6.996, accuracy: 1e-12)
        XCTAssertEqual(result.absoluteError, 0.004, accuracy: 1e-12)
        XCTAssertFalse(result.isPerfect)
    }

    func testAutoTapOffsetsMapToSignedError() {
        XCTAssertEqual(TapSevenDebugOptions(autoTapOffset: 0).autoTapOffset, Optional(0.0))
        XCTAssertEqual(TapSevenDebugOptions(autoTapOffset: -0.03).autoTapOffset, Optional(-0.03))
        XCTAssertEqual(TapSevenDebugOptions(autoTapOffset: 0.06).autoTapOffset, Optional(0.06))
        let offsets: [TimeInterval] = [0, -0.010, 0.010, -0.050, 0.050, 0.250]
        for offset in offsets {
            let logic = TapSevenGameLogic(config: .reference)
            logic.start(at: 0)
            let tapTime = 7 + offset
            guard case .submitted(let result) = logic.handleTap(at: tapTime) else {
                return XCTFail("Offset \(offset) should submit")
            }
            XCTAssertEqual(result.signedError, offset, accuracy: 1e-12)
            XCTAssertEqual(result.absoluteError, abs(offset), accuracy: 1e-12)
        }
    }

    private func simulatedProgress(framesPerSecond: Int, duration: TimeInterval) -> Double {
        let logic = TapSevenGameLogic(config: .reference)
        logic.start(at: 0)
        let frameCount = Int(duration * Double(framesPerSecond))
        for frame in 1...frameCount {
            logic.update(at: Double(frame) / Double(framesPerSecond))
        }
        return logic.progress(at: duration)
    }
}
