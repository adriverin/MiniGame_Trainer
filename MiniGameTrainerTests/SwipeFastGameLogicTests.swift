import CoreGraphics
import XCTest
@testable import MiniGameTrainer

final class SwipeFastGestureTests: XCTestCase {
    private let classifier = SwipeFastGestureClassifier(minimumDistance: 20, maximumDuration: 1)

    func testRightIsPositiveDominantDx() {
        XCTAssertEqual(classifier.classify(dx: 40, dy: 8, duration: 0.1), .right)
    }

    func testLeftIsNegativeDominantDx() {
        XCTAssertEqual(classifier.classify(dx: -40, dy: 8, duration: 0.1), .left)
    }

    func testUpIsPositiveDominantDyInSpriteKit() {
        XCTAssertEqual(classifier.classify(dx: 8, dy: 40, duration: 0.1), .up)
    }

    func testDownIsNegativeDominantDyInSpriteKit() {
        XCTAssertEqual(classifier.classify(dx: 8, dy: -40, duration: 0.1), .down)
    }

    func testMovementBelowThresholdIsNotASwipe() {
        XCTAssertNil(classifier.classify(dx: 19.9, dy: 0, duration: 0.1))
        XCTAssertNil(classifier.classify(dx: 0, dy: 19, duration: 0.05))
    }

    func testExactThresholdIsInclusive() {
        XCTAssertEqual(classifier.classify(dx: 20, dy: 0, duration: 0.1), .right)
        XCTAssertEqual(classifier.classify(dx: 0, dy: -20, duration: 0.1), .down)
    }

    func testMostlyHorizontalDiagonalClassifiesHorizontal() {
        XCTAssertEqual(classifier.classify(dx: 40, dy: 39, duration: 0.1), .right)
        XCTAssertEqual(classifier.classify(dx: -40, dy: 39, duration: 0.1), .left)
    }

    func testMostlyVerticalDiagonalClassifiesVertical() {
        XCTAssertEqual(classifier.classify(dx: 39, dy: 40, duration: 0.1), .up)
        XCTAssertEqual(classifier.classify(dx: 39, dy: -40, duration: 0.1), .down)
    }

    func testExact45DegreeTieIsVertical() {
        XCTAssertEqual(classifier.classify(dx: 30, dy: 30, duration: 0.1), .up)
        XCTAssertEqual(classifier.classify(dx: -30, dy: -30, duration: 0.1), .down)
    }

    func testTooLongGestureIsRejected() {
        XCTAssertNil(classifier.classify(dx: 40, dy: 0, duration: 1.01))
    }

    func testPointFormMatchesDeltaForm() {
        let start = CGPoint(x: 10, y: 10)
        let end = CGPoint(x: 10, y: 50)
        XCTAssertEqual(classifier.classify(from: start, to: end, duration: 0.1), .up)
    }
}

final class SwipeFastGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    private func makeLogic(
        seed: UInt64 = 1,
        mutate: (inout SwipeFastGameConfig) -> Void = { _ in }
    ) -> SwipeFastGameLogic {
        var config = SwipeFastGameConfig.reference
        mutate(&config)
        return SwipeFastGameLogic(config: config, sceneSize: sceneSize, seed: seed)
    }

    private func swipe(
        _ logic: SwipeFastGameLogic,
        box: SwipeFastBoxIndex,
        direction: SwipeDirection,
        at time: TimeInterval
    ) -> SwipeFastInputOutcome {
        let start = logic.geometry.arrowCenter(for: box)
        let distance = logic.geometry.minimumSwipeDistance + 8
        let end: CGPoint
        switch direction {
        case .up: end = CGPoint(x: start.x, y: start.y + distance)
        case .down: end = CGPoint(x: start.x, y: start.y - distance)
        case .left: end = CGPoint(x: start.x - distance, y: start.y)
        case .right: end = CGPoint(x: start.x + distance, y: start.y)
        }
        XCTAssertTrue(logic.beginGesture(at: start, time: time))
        return logic.endGesture(at: end, time: time + 0.04)
    }

    func testGestureStartingInTopLeftStaysOwnedWhenCrossingTopRight() {
        let logic = makeLogic { $0.avoidImmediateRepeat = true }
        logic.forcedDirections = [.right, .up, .up, .up]
        logic.start(at: 0)
        let start = logic.geometry.arrowCenter(for: .topLeft)
        let end = logic.geometry.arrowCenter(for: .topRight)
        XCTAssertTrue(logic.beginGesture(at: start, time: 0.1))
        logic.moveGesture(at: end, time: 0.14)
        let outcome = logic.endGesture(at: end, time: 0.18)
        guard case .correct(let box, let score, _) = outcome else {
            return XCTFail("Expected top-left to score, got \(outcome)")
        }
        XCTAssertEqual(box, .topLeft)
        XCTAssertEqual(score, 1)
        XCTAssertEqual(logic.box(.topRight).spawnedAt, 0, accuracy: 1e-12)
    }

    func testAvoidImmediateRepeatChangesDirection() {
        let logic = makeLogic { $0.avoidImmediateRepeat = true }
        logic.start(at: 0)
        let original = logic.box(.bottomLeft).direction
        let outcome = logic.applySwipe(original, on: .bottomLeft, at: 0.2)
        guard case .correct(_, _, let newDirection) = outcome else {
            return XCTFail("Expected correct swipe")
        }
        XCTAssertNotEqual(newDirection, original)
        XCTAssertEqual(logic.box(.bottomLeft).direction, newDirection)
    }

    func testSwipeStartingOutsideAnyBoxDoesNothing() {
        let logic = makeLogic()
        logic.start(at: 0)
        XCTAssertFalse(logic.beginGesture(at: CGPoint(x: 4, y: 4), time: 0.1))
        XCTAssertEqual(logic.endGesture(at: CGPoint(x: 80, y: 80), time: 0.2), .ignored)
        XCTAssertEqual(logic.score, 0)
    }

    func testCorrectSwipeIncrementsScoreAndResetsOnlyThatBox() {
        let logic = makeLogic { $0.avoidImmediateRepeat = true }
        logic.forcedDirections = [.right, .up, .down, .left]
        logic.start(at: 0)
        logic.update(at: 0.4)
        let othersBefore = [
            logic.box(.topRight),
            logic.box(.bottomLeft),
            logic.box(.bottomRight),
        ]
        let outcome = swipe(logic, box: .topLeft, direction: .right, at: 0.4)
        guard case .correct(let box, let score, _) = outcome else {
            return XCTFail("Expected correct swipe, got \(outcome)")
        }
        XCTAssertEqual(box, .topLeft)
        XCTAssertEqual(score, 1)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.box(.topLeft).spawnedAt, 0.44, accuracy: 1e-12)
        XCTAssertEqual(logic.box(.topRight).spawnedAt, othersBefore[0].spawnedAt, accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomLeft).spawnedAt, othersBefore[1].spawnedAt, accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomRight).spawnedAt, othersBefore[2].spawnedAt, accuracy: 1e-12)
        XCTAssertEqual(logic.box(.topRight).elapsed(at: 0.44), othersBefore[0].elapsed(at: 0.44), accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomLeft).elapsed(at: 0.44), othersBefore[1].elapsed(at: 0.44), accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomRight).elapsed(at: 0.44), othersBefore[2].elapsed(at: 0.44), accuracy: 1e-12)
    }

    func testWrongSwipeDefaultIgnoresAndLeavesTimers() {
        let logic = makeLogic()
        logic.forcedDirections = [.right, .up, .down, .left]
        logic.start(at: 0)
        logic.update(at: 0.3)
        let outcome = swipe(logic, box: .topLeft, direction: .left, at: 0.3)
        guard case .wrong(let box, let expected, let actual) = outcome else {
            return XCTFail("Expected wrong swipe, got \(outcome)")
        }
        XCTAssertEqual(box, .topLeft)
        XCTAssertEqual(expected, .right)
        XCTAssertEqual(actual, .left)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.box(.topLeft).spawnedAt, 0, accuracy: 1e-12)
        XCTAssertEqual(logic.wrongSwipes, 1)
    }

    func testWrongSwipeConfigurableGameOver() {
        let logic = makeLogic { $0.wrongSwipeBehavior = .gameOver }
        logic.forcedDirections = [.up, .up, .up, .up]
        logic.start(at: 0)
        let outcome = swipe(logic, box: .bottomRight, direction: .down, at: 0.2)
        guard case .wrong = outcome else { return XCTFail("Expected wrong") }
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.endReason, .wrongSwipe)
        XCTAssertEqual(logic.expiredBox, .bottomRight)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .gameOver)
    }

    func testTapBelowMinimumDistanceIsIgnored() {
        let logic = makeLogic()
        logic.forcedDirections = [.right, .up, .down, .left]
        logic.start(at: 0)
        let start = logic.geometry.arrowCenter(for: .topLeft)
        XCTAssertTrue(logic.beginGesture(at: start, time: 0.1))
        let outcome = logic.endGesture(at: CGPoint(x: start.x + 4, y: start.y), time: 0.12)
        XCTAssertEqual(outcome, .tooShort)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .playing)
    }

    func testSecondFingerDoesNotStartAnotherGesture() {
        let logic = makeLogic()
        logic.forcedDirections = [.right, .up, .down, .left]
        logic.start(at: 0)
        XCTAssertTrue(logic.beginGesture(at: logic.geometry.arrowCenter(for: .topLeft), time: 0.1))
        XCTAssertFalse(logic.beginGesture(at: logic.geometry.arrowCenter(for: .topRight), time: 0.11))
    }

    func testExpiryEndsOnceAndDoesNotRetrigger() {
        let logic = makeLogic()
        logic.allowedTimeOverride = 1
        logic.start(at: 0)
        logic.update(at: 0.999)
        XCTAssertEqual(logic.state, .playing)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.endReason, .expired)
        let firstBox = logic.expiredBox
        logic.update(at: 1.5)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.expiredBox, firstBox)
        XCTAssertEqual(logic.applySwipe(.up, on: .topLeft, at: 1.6), .ignored)
    }

    func testForcedExpireUsesChosenBoxOnce() {
        let logic = makeLogic()
        logic.start(at: 0)
        XCTAssertEqual(logic.expire(.bottomLeft, at: 0.5), .expired(box: .bottomLeft))
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.expiredBox, .bottomLeft)
        XCTAssertEqual(logic.expire(.topRight, at: 0.6), .ignored)
    }

    func testPauseResumeRestartsTheRun() {
        let logic = makeLogic()
        logic.forcedDirections = [.up, .right, .down, .left]
        logic.start(at: 0)
        _ = logic.applySwipe(.up, on: .topLeft, at: 0.2)
        XCTAssertEqual(logic.score, 1)
        logic.pause(at: 0.4)
        XCTAssertEqual(logic.state, .paused)
        logic.resume(at: 1.0)
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.box(.topLeft).spawnedAt, 1.0, accuracy: 1e-12)
    }

    func testDeterministicAutoPlayReachesScore100() {
        let logic = makeLogic { $0.avoidImmediateRepeat = false }
        logic.allowedTimeOverride = 8
        logic.start(at: 0)
        var time: TimeInterval = 0.02
        for index in 0..<120 {
            let box = SwipeFastBoxIndex(rawValue: index % 4)!
            let outcome = logic.applySwipe(logic.box(box).direction, on: box, at: time)
            guard case .correct(_, let score, _) = outcome else {
                return XCTFail("Auto-play failed at \(time) score \(logic.score): \(outcome)")
            }
            XCTAssertEqual(score, index + 1)
            time += 0.03
        }
        XCTAssertEqual(logic.score, 120)
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.difficulty.allowedTime(forScore: 120), 1.00, accuracy: 1e-12)
        XCTAssertEqual(logic.allowedTime(forScore: 120), 8, accuracy: 1e-12)
    }

    func testRapidCorrectSwipesHaveNoCooldown() {
        let logic = makeLogic { $0.avoidImmediateRepeat = false }
        logic.forcedDirections = [.up, .up, .up, .up]
        logic.start(at: 0)
        var time: TimeInterval = 0.05
        for index in 0..<8 {
            let box = SwipeFastBoxIndex(rawValue: index % 4)!
            let direction = logic.box(box).direction
            let outcome = logic.applySwipe(direction, on: box, at: time)
            guard case .correct(_, let score, _) = outcome else {
                return XCTFail("Lost a swipe at \(time): \(outcome)")
            }
            XCTAssertEqual(score, index + 1)
            time += 0.04
        }
        XCTAssertEqual(logic.score, 8)
    }

    func testBackgroundStyleRestartInvalidatesActiveGesture() {
        let logic = makeLogic()
        logic.start(at: 0)
        XCTAssertTrue(logic.beginGesture(at: logic.geometry.arrowCenter(for: .topLeft), time: 0.1))
        logic.pause(at: 0.2)
        XCTAssertNil(logic.activeGesture)
    }
}

final class SwipeFastTimingTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testRemainingFractionUsesMonotonicTimestamps() {
        let logic = SwipeFastGameLogic(config: .reference, sceneSize: sceneSize, seed: 1)
        logic.allowedTimeOverride = 2
        logic.start(at: 10)
        XCTAssertEqual(logic.remainingFraction(of: .topLeft, at: 10), 1, accuracy: 1e-12)
        XCTAssertEqual(logic.remainingFraction(of: .topLeft, at: 11), 0.5, accuracy: 1e-12)
        XCTAssertEqual(logic.remainingFraction(of: .topLeft, at: 12), 0, accuracy: 1e-12)
    }

    func testSameTimestampsAt60And120HzProduceTheSameState() {
        func run(stepsPerSecond: Double) -> (Double, Double, SwipeFastGameState) {
            let logic = SwipeFastGameLogic(config: .reference, sceneSize: sceneSize, seed: 7)
            logic.allowedTimeOverride = 1.5
            logic.forcedDirections = [.left, .right, .up, .down]
            logic.start(at: 0)
            let dt = 1 / stepsPerSecond
            var time = 0.0
            while time < 0.8 {
                time += dt
                logic.update(at: time)
            }
            logic.update(at: 0.8)
            return (
                logic.remainingFraction(of: .topLeft, at: 0.8),
                logic.remainingFraction(of: .bottomRight, at: 0.8),
                logic.state
            )
        }
        let slow = run(stepsPerSecond: 60)
        let fast = run(stepsPerSecond: 120)
        XCTAssertEqual(slow.0, fast.0, accuracy: 1e-12)
        XCTAssertEqual(slow.1, fast.1, accuracy: 1e-12)
        XCTAssertEqual(slow.2, fast.2)
        XCTAssertEqual(slow.0, 1 - 0.8 / 1.5, accuracy: 1e-12)
    }

    func testResettingOneBoxDoesNotChangeTheOtherThreeAges() {
        let logic = SwipeFastGameLogic(config: .reference, sceneSize: sceneSize, seed: 3)
        logic.allowedTimeOverride = 2
        logic.forcedDirections = [.up, .right, .down, .left]
        logic.start(at: 0)
        logic.update(at: 0.7)
        let before = SwipeFastBoxIndex.allCases.map { logic.box($0).elapsed(at: 0.7) }
        _ = logic.applySwipe(.right, on: .topRight, at: 0.7)
        XCTAssertEqual(logic.box(.topRight).elapsed(at: 0.7), 0, accuracy: 1e-12)
        XCTAssertEqual(logic.box(.topLeft).elapsed(at: 0.7), before[0], accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomLeft).elapsed(at: 0.7), before[2], accuracy: 1e-12)
        XCTAssertEqual(logic.box(.bottomRight).elapsed(at: 0.7), before[3], accuracy: 1e-12)
    }

    func testAllFourBoxesStartFullTogether() {
        let logic = SwipeFastGameLogic(config: .reference, sceneSize: sceneSize, seed: 2)
        logic.start(at: 5)
        for box in SwipeFastBoxIndex.allCases {
            XCTAssertEqual(logic.remainingFraction(of: box, at: 5), 1, accuracy: 1e-12)
            XCTAssertEqual(logic.box(box).spawnedAt, 5, accuracy: 1e-12)
        }
    }
}
