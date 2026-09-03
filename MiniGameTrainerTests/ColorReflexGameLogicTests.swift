import XCTest
@testable import MiniGameTrainer

final class ColorReflexGameLogicTests: XCTestCase {
    private func makeLogic(
        seed: UInt64 = 1,
        mutate: (inout ColorReflexGameConfig) -> Void = { _ in }
    ) -> ColorReflexGameLogic {
        var config = ColorReflexGameConfig.deterministic(seed: seed)
        mutate(&config)
        return ColorReflexGameLogic(config: config, seed: seed)
    }

    func testStartEntersWaitingImmediatelyWithoutCountdown() throws {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.start(at: 10)
        XCTAssertEqual(logic.state, .waiting)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(try XCTUnwrap(logic.triggerTimestamp), 11, accuracy: 1e-12)
        XCTAssertTrue(logic.promptIsWait)
    }

    func testTriggerAndTextChangeShareTheSameTimestamp() throws {
        let logic = makeLogic {
            $0.minWait = 1.25
            $0.maxWait = 1.25
        }
        logic.start(at: 0)
        logic.update(at: 1.249)
        XCTAssertEqual(logic.state, .waiting)
        logic.update(at: 1.25)
        XCTAssertEqual(logic.state, .tapNow)
        XCTAssertEqual(try XCTUnwrap(logic.triggerTimestamp), 1.25, accuracy: 1e-12)
    }

    func testGeneratedWaitDelayStaysInsideReferenceBounds() {
        let logic = makeLogic(seed: 99) {
            $0.sessionDuration = 400
        }
        logic.start(at: 0)
        var seen: [TimeInterval] = []
        var now: TimeInterval = 0
        for _ in 0..<80 {
            let delay = try! XCTUnwrap(logic.scheduledWaitDelay)
            seen.append(delay)
            XCTAssertGreaterThanOrEqual(delay, 0.60 - 1e-12)
            XCTAssertLessThanOrEqual(delay, 4.00 + 1e-12)
            now += delay
            logic.update(at: now)
            _ = logic.handleTouchBegan(at: now + 0.01)
            logic.handleTouchEnded()
            now += 0.01
        }
        XCTAssertGreaterThan(seen.max() ?? 0, 3.0)
        XCTAssertLessThan(seen.min() ?? 4, 1.2)
    }

    func testTriggerColorAlwaysDiffersFromCurrentColor() {
        let logic = makeLogic(seed: 7) {
            $0.minWait = 0.5
            $0.maxWait = 0.5
        }
        logic.start(at: 0)
        for step in 0..<24 {
            let before = logic.currentColor
            logic.update(at: 0.5 + Double(step))
            XCTAssertEqual(logic.state, .tapNow)
            XCTAssertNotEqual(logic.currentColor, before)
            _ = logic.handleTouchBegan(at: 0.5 + Double(step) + 0.05)
            logic.handleTouchEnded()
        }
    }

    func testSameSeedReplaysTheSameColorAndDelaySequence() {
        func collect(seed: UInt64) -> [(TimeInterval, ColorReflexSwatch)] {
            let logic = makeLogic(seed: seed) {
                $0.minWait = 0.6
                $0.maxWait = 4.0
            }
            logic.start(at: 0)
            var pairs: [(TimeInterval, ColorReflexSwatch)] = []
            var now: TimeInterval = 0
            for _ in 0..<8 {
                let delay = try! XCTUnwrap(logic.scheduledWaitDelay)
                now += delay
                logic.update(at: now)
                pairs.append((delay, logic.currentColor))
                _ = logic.handleTouchBegan(at: now + 0.1)
                logic.handleTouchEnded()
                now += 0.1
            }
            return pairs
        }
        let first = collect(seed: 20260903)
        let second = collect(seed: 20260903)
        XCTAssertEqual(first.map(\.0), second.map(\.0))
        XCTAssertEqual(first.map(\.1), second.map(\.1))
    }

    func testForcedColorSequenceIsConsumedInOrder() {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
        }
        logic.forcedColorSequence = [.teal, .orange, .purple, .cyan]
        logic.start(at: 0)
        XCTAssertEqual(logic.currentColor, .teal)
        logic.update(at: 1)
        XCTAssertEqual(logic.currentColor, .orange)
        _ = logic.handleTouchBegan(at: 1.1)
        logic.update(at: 2.1)
        XCTAssertEqual(logic.currentColor, .purple)
    }

    func testHeldTouchFromWaitDoesNotScoreAfterTrigger() {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
            $0.prematurePenalty = 0
        }
        logic.start(at: 0)
        XCTAssertEqual(logic.handleTouchBegan(at: 0.4).isPremature, true)
        XCTAssertEqual(logic.score, 0)
        logic.update(at: 1.4)
        XCTAssertEqual(logic.state, .tapNow)
        XCTAssertEqual(logic.handleTouchBegan(at: 1.45), .ignored)
        XCTAssertEqual(logic.score, 0)
        logic.handleTouchEnded()
        guard case .scored(let reaction, let score) = logic.handleTouchBegan(at: 1.5) else {
            return XCTFail("A new touch after release should score")
        }
        XCTAssertEqual(reaction, 0.1, accuracy: 1e-12)
        XCTAssertEqual(score, 1)
    }

    func testTouchEndedAfterTriggerWithoutNewBeginDoesNotScore() {
        let logic = makeLogic {
            $0.minWait = 1
            $0.maxWait = 1
            $0.prematurePenalty = 0
            $0.prematureResetsWait = false
        }
        logic.start(at: 0)
        _ = logic.handleTouchBegan(at: 0.2)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .tapNow)
        logic.handleTouchEnded()
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .tapNow)
    }

    func testMultiTouchIsOneLogicalResponse() {
        let logic = makeLogic {
            $0.minWait = 0.5
            $0.maxWait = 0.5
        }
        logic.start(at: 0)
        logic.update(at: 0.5)
        _ = logic.handleTouchBegan(at: 0.62)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.state, .waiting)
        XCTAssertEqual(logic.handleTouchBegan(at: 0.63).isPremature, true)
        XCTAssertEqual(logic.score, 1)
    }

    func testPauseShiftsDeadlineAndTriggerByPausedDuration() throws {
        let logic = makeLogic {
            $0.sessionDuration = 10
            $0.minWait = 2
            $0.maxWait = 2
        }
        logic.start(at: 0)
        logic.pause(at: 0.5)
        XCTAssertEqual(logic.state, .paused)
        logic.resume(at: 3.5)
        XCTAssertEqual(try XCTUnwrap(logic.sessionDeadline), 13, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(logic.triggerTimestamp), 5, accuracy: 1e-12)
        logic.update(at: 4.9)
        XCTAssertEqual(logic.state, .waiting)
        logic.update(at: 5)
        XCTAssertEqual(logic.state, .tapNow)
    }
}

private extension ColorReflexGameLogic {
    var promptIsWait: Bool { state == .waiting }
}

private extension ColorReflexTapOutcome {
    var isPremature: Bool {
        if case .premature = self { return true }
        return false
    }
}
