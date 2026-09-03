import XCTest
@testable import MiniGameTrainer

final class ColorReflexTimingTests: XCTestCase {
    private func makeLogic(
        mutate: (inout ColorReflexGameConfig) -> Void = { _ in }
    ) -> ColorReflexGameLogic {
        var config = ColorReflexGameConfig.deterministic(seed: 11)
        mutate(&config)
        return ColorReflexGameLogic(config: config, seed: 11)
    }

    func testSuccessfulTapAt218Milliseconds() throws {
        let logic = makeLogic {
            $0.minWait = 5
            $0.maxWait = 5
        }
        logic.start(at: 0)
        logic.update(at: 5)
        XCTAssertEqual(logic.state, .tapNow)
        guard case .scored(let reaction, let score) = logic.handleTouchBegan(at: 5.218) else {
            return XCTFail("Expected a scored reaction")
        }
        XCTAssertEqual(reaction, 0.218, accuracy: 1e-12)
        XCTAssertEqual(score, 1)
        XCTAssertEqual(try XCTUnwrap(logic.lastReactionTime), 0.218, accuracy: 1e-12)
    }

    func testTapBeforeTriggerAppliesTimePenaltyAndNoScore() throws {
        let logic = makeLogic {
            $0.sessionDuration = 30
            $0.minWait = 4
            $0.maxWait = 4
            $0.prematurePenalty = 2
        }
        logic.start(at: 0)
        XCTAssertEqual(try XCTUnwrap(logic.sessionDeadline), 30, accuracy: 1e-12)
        guard case .premature(let penalty, let remaining) = logic.handleTouchBegan(at: 1.0) else {
            return XCTFail("Expected premature")
        }
        XCTAssertEqual(penalty, 2, accuracy: 1e-12)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(try XCTUnwrap(logic.sessionDeadline), 28, accuracy: 1e-12)
        XCTAssertEqual(remaining, 27, accuracy: 1e-12)
        XCTAssertEqual(logic.remainingFraction(at: 1.0), 27.0 / 30.0, accuracy: 1e-12)
        XCTAssertEqual(logic.state, .waiting)
        XCTAssertEqual(try XCTUnwrap(logic.triggerTimestamp), 5, accuracy: 1e-12)
    }

    func testMultiplePenaltiesStackWithoutDuplicateEnd() throws {
        let logic = makeLogic {
            $0.sessionDuration = 6
            $0.minWait = 5
            $0.maxWait = 5
            $0.prematurePenalty = 2
        }
        logic.start(at: 0)
        XCTAssertEqual(logic.handleTouchBegan(at: 0.2).isEndedOrPremature, true)
        logic.handleTouchEnded()
        XCTAssertEqual(try XCTUnwrap(logic.sessionDeadline), 4, accuracy: 1e-12)
        XCTAssertFalse(logic.hasTerminated)
        XCTAssertEqual(logic.handleTouchBegan(at: 0.3).isEndedOrPremature, true)
        logic.handleTouchEnded()
        XCTAssertEqual(try XCTUnwrap(logic.sessionDeadline), 2, accuracy: 1e-12)
        XCTAssertFalse(logic.hasTerminated)
        let third = logic.handleTouchBegan(at: 0.4)
        XCTAssertEqual(third, .ended)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertTrue(logic.hasTerminated)
        XCTAssertEqual(logic.handleTouchBegan(at: 0.5), .ended)
        XCTAssertEqual(logic.prematureTapCount, 3)
    }

    func testRemainingWithoutPenaltyIsDurationMinusElapsed() {
        let logic = makeLogic { $0.sessionDuration = 41 }
        logic.start(at: 2.367)
        XCTAssertEqual(logic.remaining(at: 2.367), 41, accuracy: 1e-12)
        XCTAssertEqual(logic.remaining(at: 12.367), 31, accuracy: 1e-12)
        XCTAssertEqual(logic.elapsed(at: 12.367), 10, accuracy: 1e-12)
        XCTAssertEqual(logic.remainingFraction(at: 22.867), 0.5, accuracy: 1e-12)
    }

    func testTapExactlyAtDeadlineIsAccepted() {
        let logic = makeLogic {
            $0.sessionDuration = 5
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        guard case .scored(_, let score) = logic.handleTouchBegan(at: 5) else {
            return XCTFail("Tap at the deadline must be accepted")
        }
        XCTAssertEqual(score, 1)
    }

    func testTapAfterDeadlineIsRejectedAndEndsOnce() {
        let logic = makeLogic {
            $0.sessionDuration = 5
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        logic.update(at: 5.0001)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.handleTouchBegan(at: 5.01), .ended)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.endReason, .timeExpired)
    }

    func testTriggeredTapAfterDeadlineDoesNotScore() {
        let logic = makeLogic {
            $0.sessionDuration = 1.1
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .tapNow)
        logic.update(at: 1.1001)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.handleTouchBegan(at: 1.12), .ended)
        XCTAssertEqual(logic.score, 0)
    }

    func testIdenticalTimestampSequenceMatchesAt60And120Hertz() {
        func run(steps: [TimeInterval]) -> (Int, [TimeInterval], Int, ColorReflexState) {
            let logic = makeLogic {
                $0.sessionDuration = 8
                $0.minWait = 1
                $0.maxWait = 1
            }
            logic.start(at: 0)
            for time in steps {
                logic.update(at: time)
                if time == 1.218 || time == 2.436 {
                    _ = logic.handleTouchBegan(at: time)
                    logic.handleTouchEnded()
                }
            }
            return (logic.score, logic.reactionTimes, logic.prematureTapCount, logic.state)
        }
        func grid(_ hz: Double, extras: [TimeInterval]) -> [TimeInterval] {
            var times: [TimeInterval] = []
            var t: TimeInterval = 0
            while t <= 4.0 {
                times.append((t * 1_000_000).rounded() / 1_000_000)
                t += 1 / hz
            }
            times.append(contentsOf: extras)
            return times.sorted()
        }
        let events: [TimeInterval] = [1.218, 2.436]
        let a = run(steps: grid(60, extras: events))
        let b = run(steps: grid(120, extras: events))
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
        XCTAssertEqual(a.3, b.3)
        XCTAssertEqual(a.0, 2)
        XCTAssertEqual(a.1.count, 2)
        XCTAssertEqual(a.1[0], 0.218, accuracy: 1e-12)
        XCTAssertEqual(a.1[1], 0.218, accuracy: 1e-12)
    }

    func testSessionClockDoesNotPauseBetweenRounds() {
        let logic = makeLogic {
            $0.sessionDuration = 10
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 0)
        logic.update(at: 1)
        _ = logic.handleTouchBegan(at: 1.2)
        XCTAssertEqual(logic.remaining(at: 1.2), 8.8, accuracy: 1e-12)
        XCTAssertEqual(logic.remaining(at: 2.0), 8.0, accuracy: 1e-12)
    }
}

private extension ColorReflexTapOutcome {
    var isEndedOrPremature: Bool {
        switch self {
        case .ended, .premature: true
        default: false
        }
    }
}
