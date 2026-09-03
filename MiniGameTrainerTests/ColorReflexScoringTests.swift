import XCTest
@testable import MiniGameTrainer

final class ColorReflexScoringTests: XCTestCase {
    private func makeLogic(
        mutate: (inout ColorReflexGameConfig) -> Void = { _ in }
    ) -> ColorReflexGameLogic {
        var config = ColorReflexGameConfig.deterministic(seed: 3)
        mutate(&config)
        return ColorReflexGameLogic(config: config, seed: 3)
    }

    func testEachValidTriggerAddsExactlyOnePoint() {
        let logic = makeLogic {
            $0.minWait = 0.5
            $0.maxWait = 0.5
            $0.sessionDuration = 20
        }
        logic.start(at: 0)
        var now: TimeInterval = 0
        for expected in 1...8 {
            now += 0.5
            logic.update(at: now)
            guard case .scored(_, let score) = logic.handleTouchBegan(at: now + 0.05) else {
                return XCTFail("Expected score on tap \(expected)")
            }
            logic.handleTouchEnded()
            XCTAssertEqual(score, expected)
            XCTAssertEqual(logic.score, expected)
            now += 0.05
        }
        XCTAssertEqual(logic.reactionTimes.count, 8)
    }

    func testDoubleTapOnSameTriggerDoesNotDoubleScore() {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        _ = logic.handleTouchBegan(at: 1.1)
        logic.handleTouchEnded()
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.state, .waiting)
        _ = logic.handleTouchBegan(at: 1.11)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.prematureTapCount, 1)
    }

    func testPrimaryScoreIsIntegerPointsNotAverageReaction() throws {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        _ = logic.handleTouchBegan(at: 1.218)
        logic.handleTouchEnded()
        logic.update(at: 2.218)
        _ = logic.handleTouchBegan(at: 2.400)
        let summary = logic.makeSummary(at: 2.400)
        XCTAssertEqual(summary.score, 2)
        XCTAssertEqual(summary.averageReactionTime ?? 0, (0.218 + 0.182) / 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(summary.bestReactionTime), 0.182, accuracy: 1e-12)
        let result = ColorReflexResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.score, 2)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
        XCTAssertNotEqual(result.scorePresentation, .reactionMilliseconds)
    }

    func testAutoReactFastRunIsBoundedAndStable() {
        let logic = makeLogic {
            $0.sessionDuration = 8
            $0.minWait = 0.25
            $0.maxWait = 0.25
        }
        logic.start(at: 0)
        var now: TimeInterval = 0
        var lastScore = 0
        while now <= 8 {
            logic.update(at: now)
            if logic.state == .tapNow {
                _ = logic.handleTouchBegan(at: now)
                logic.handleTouchEnded()
            }
            XCTAssertGreaterThanOrEqual(logic.score, lastScore)
            lastScore = logic.score
            XCTAssertFalse(logic.remaining(at: now).isNaN)
            now += 1.0 / 120.0
        }
        logic.update(at: 8.0001)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.score, lastScore)
        XCTAssertNil(logic.triggerTimestamp)
        XCTAssertGreaterThan(logic.score, 10)
        XCTAssertLessThan(logic.score, 40)
    }

    func testForcedScoreStartsFromOverrideThenIncrements() {
        let logic = makeLogic {
            $0.minWait = 0.4
            $0.maxWait = 0.4
        }
        logic.scoreOverride = 12
        logic.start(at: 0)
        XCTAssertEqual(logic.score, 12)
        logic.update(at: 0.4)
        _ = logic.handleTouchBegan(at: 0.55)
        XCTAssertEqual(logic.score, 13)
    }

    func testBarStageUsesRemainingFractionThresholds() {
        let config = ColorReflexGameConfig.reference
        XCTAssertEqual(config.barStage(remainingFraction: 1), .green)
        XCTAssertEqual(config.barStage(remainingFraction: 0.43), .green)
        XCTAssertEqual(config.barStage(remainingFraction: 0.42), .orange)
        XCTAssertEqual(config.barStage(remainingFraction: 0.26), .orange)
        XCTAssertEqual(config.barStage(remainingFraction: 0.25), .red)
        XCTAssertEqual(config.barStage(remainingFraction: 0), .red)
    }
}
