import XCTest
@testable import MiniGameTrainer

final class CenterHitTimingTests: XCTestCase {
    func testReflectionPreservesOvershoot() {
        let result = CenterHitMotion.reflected(position: 98, direction: .right, distance: 5, left: 0, right: 100)
        XCTAssertEqual(result.position, 97, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .left)
    }

    func testReflectionPreservesMultipleBoundaryCrossings() {
        let result = CenterHitMotion.reflected(position: 98, direction: .right, distance: 405, left: 0, right: 100)
        XCTAssertEqual(result.position, 97, accuracy: 1e-12)
        XCTAssertEqual(result.direction, .left)
    }

    func testEquivalentElapsedSimulationAtSixtyAndOneHundredTwentyHertz() {
        let at60 = simulated(framesPerSecond: 60, duration: 2)
        let at120 = simulated(framesPerSecond: 120, duration: 2)
        XCTAssertEqual(at60.position, at120.position, accuracy: 1e-8)
        XCTAssertEqual(at60.direction, at120.direction)
    }

    func testTouchTimestampAdvancesSevenMillisecondsBeforeScoring() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 10)
        let outcome = logic.handleTap(at: 10.007)
        guard case .scored(let attempt) = outcome else { return XCTFail("Expected scored tap") }
        XCTAssertEqual(attempt.indicatorX, 50.658, accuracy: 1e-9)
        XCTAssertEqual(attempt.absoluteError, 0.658, accuracy: 1e-9)
        XCTAssertEqual(attempt.precision, 98.684, accuracy: 1e-9)
        XCTAssertEqual(attempt.tapTimestamp, 0.007, accuracy: 1e-9)
    }

    func testLargeTimestampDeltaIsClampedToConfiguredSimulationStep() {
        var config = CenterHitGameConfig.reference
        config.maximumSimulationDelta = 0.25
        let logic = CenterHitGameLogic(config: config, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        logic.update(at: 10)
        XCTAssertEqual(logic.position, 73.5, accuracy: 1e-9)
        XCTAssertEqual(logic.direction, .right)
    }

    func testPauseDoesNotAdvanceThroughBackgroundTime() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        logic.update(at: 0.1)
        let pausedPosition = logic.position
        logic.pause(at: 0.1)
        logic.update(at: 5)
        XCTAssertEqual(logic.position, pausedPosition, accuracy: 1e-12)
        logic.resume(at: 5)
        logic.update(at: 5.1)
        XCTAssertEqual(logic.position, pausedPosition + 9.4, accuracy: 1e-9)
    }

    private func simulated(framesPerSecond: Int, duration: TimeInterval) -> (position: Double, direction: CenterHitDirection) {
        var config = CenterHitGameConfig.reference
        config.maximumSimulationDelta = 1
        let logic = CenterHitGameLogic(config: config, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        let frameCount = Int(duration * Double(framesPerSecond))
        for frame in 1...frameCount {
            logic.update(at: Double(frame) / Double(framesPerSecond))
        }
        return (logic.position, logic.direction)
    }
}
