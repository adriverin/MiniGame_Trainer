import XCTest
@testable import MiniGameTrainer

final class ZigGameLogicTests: XCTestCase {
    func testTapTogglesOnlyTwoDirectionsAndDoesNotScore() {
        let logic = ZigGameLogic()
        XCTAssertEqual(logic.direction, .positiveY)
        XCTAssertTrue(logic.toggleDirection()); XCTAssertEqual(logic.direction, .positiveX)
        XCTAssertTrue(logic.toggleDirection()); XCTAssertEqual(logic.direction, .positiveY)
        XCTAssertTrue(logic.toggleDirection()); XCTAssertEqual(logic.direction, .positiveX)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.turns, 3)
    }

    func testContinuousMovementAndDistanceScoreOnStraight() {
        var config = ZigGameConfig.reference; config.maximumFrameDelta = 10
        let logic = ZigGameLogic(config: config)
        logic.update(deltaTime: 0.5)
        XCTAssertEqual(logic.ballPosition.y, 0.725, accuracy: 0.002)
        XCTAssertEqual(logic.score, 0)
        logic.update(deltaTime: 0.25)
        XCTAssertEqual(logic.score, 1)
    }

    func testDistanceBoundaries() {
        let logic = ZigGameLogic()
        logic.setBallForTesting(.zero, distance: 0.9); XCTAssertEqual(logic.score, 0)
        logic.setBallForTesting(.zero, distance: 1.0); XCTAssertEqual(logic.score, 1)
        logic.setBallForTesting(.zero, distance: 2.4); XCTAssertEqual(logic.score, 2)
    }

    func testSpeedAnchorsMonotonicityAndCap() {
        let model = ZigDifficultyModel(config: .reference)
        XCTAssertEqual(model.speed(forScore: 0), 1.45, accuracy: 0.0001)
        XCTAssertEqual(model.speed(forScore: 14), 1.877, accuracy: 0.0001)
        XCTAssertEqual(model.speed(forScore: 42), 2.731, accuracy: 0.0001)
        XCTAssertEqual(model.speed(forScore: 99), 4.4695, accuracy: 0.0001)
        XCTAssertEqual(model.speed(forScore: 150), 6.025, accuracy: 0.0001)
        XCTAssertEqual(model.speed(forScore: 190), 7.245, accuracy: 0.0001)
        var previous: CGFloat = 0
        for score in 0...300 { let speed = model.speed(forScore: score); XCTAssertGreaterThanOrEqual(speed, previous); previous = speed }
        XCTAssertEqual(model.speed(forScore: 300), 8.0, accuracy: 0.0001)
    }

    func testReferenceTrajectoryWithPerfectTurns() {
        var config = ZigGameConfig.reference; config.randomSeed = 77
        let logic = ZigGameLogic(config: config)
        let anchors: [(TimeInterval, Int)] = [(8.5, 14), (20.5, 42), (36.5, 99), (48.5, 163), (52.5, 190)]
        var time: TimeInterval = 0
        for anchor in anchors {
            while time < anchor.0 {
                _ = logic.performPerfectTurnIfNeeded()
                logic.update(deltaTime: 1.0 / 240.0)
                time += 1.0 / 240.0
            }
            XCTAssertEqual(logic.state, .running)
            XCTAssertEqual(logic.score, anchor.1, accuracy: 4)
        }
    }

    func testSupportStraightCornerEarlyAndLate() {
        let logic = ZigGameLogic()
        logic.replaceCellsForTesting([ZigCell(x: 0, y: 3), ZigCell(x: 0, y: 4), ZigCell(x: 1, y: 4)])
        XCTAssertTrue(logic.isSupported(CGPoint(x: 0, y: 3.9)))
        XCTAssertTrue(logic.isSupported(CGPoint(x: 0.48, y: 4)))
        XCTAssertFalse(logic.isSupported(CGPoint(x: 3.7, y: 3)))
        XCTAssertFalse(logic.isSupported(CGPoint(x: 0, y: 4.7)))
    }

    func testEarlyTurnFallsAndFreezesSummary() {
        var config = ZigGameConfig.reference; config.maximumFrameDelta = 2
        let logic = ZigGameLogic(config: config)
        logic.replaceCellsForTesting([ZigCell(x: 0, y: 3), ZigCell(x: 0, y: 4)])
        logic.setBallForTesting(CGPoint(x: 0, y: 4), direction: .positiveX)
        logic.update(deltaTime: 1)
        XCTAssertEqual(logic.state, .falling)
        let summary = logic.makeSummary()
        XCTAssertFalse(logic.toggleDirection())
        logic.update(deltaTime: 0.1)
        XCTAssertEqual(logic.makeSummary(), summary)
    }

    func testPauseFreezesRunningAndFalling() {
        let logic = ZigGameLogic()
        logic.pause(); let before = logic.ballPosition; logic.update(deltaTime: 1); XCTAssertEqual(logic.ballPosition, before)
        logic.resume(); logic.update(deltaTime: 0.01); XCTAssertGreaterThan(logic.ballPosition.y, before.y)
        logic.replaceCellsForTesting([]); logic.setBallForTesting(CGPoint(x: 0, y: 3.1)); logic.update(deltaTime: 0.01)
        XCTAssertEqual(logic.state, .falling)
        logic.pause(); logic.update(deltaTime: 1); XCTAssertEqual(logic.fallElapsed, 0)
        logic.resume()
        for _ in 0..<10 { logic.update(deltaTime: 0.05) }
        XCTAssertEqual(logic.state, .finished)
        XCTAssertEqual(logic.drainEvents().filter { $0 == .finished }.count, 1)
    }

    func testPathRetentionIsBoundedAndLookaheadMaintained() {
        var config = ZigGameConfig.reference; config.randomSeed = 3
        let logic = ZigGameLogic(config: config)
        for _ in 0..<5_000 {
            _ = logic.performPerfectTurnIfNeeded(); logic.update(deltaTime: 1.0 / 240.0)
            if logic.isFinished { break }
        }
        XCTAssertEqual(logic.state, .running)
        XCTAssertLessThan(logic.cells.count, config.lookaheadUnits + config.retainedUnitsBehind + 10)
        XCTAssertGreaterThanOrEqual(logic.cells.map(\.progress).max() ?? 0, Int(logic.cameraProgress) + config.lookaheadUnits - 1)
    }

    func testProjectionAxesAndCameraAnchor() {
        let size = CGSize(width: 400, height: 800)
        let config = ZigGameConfig.reference
        let projection = ZigProjection(size: size, config: config, cameraProgress: 0, cameraLateral: 0)
        let origin = projection.point(x: 0, y: 0)
        let positiveX = projection.point(x: 1, y: 0)
        let positiveY = projection.point(x: 0, y: 1)
        XCTAssertGreaterThan(positiveX.x, origin.x)
        XCTAssertLessThan(positiveY.x, origin.x)
        XCTAssertGreaterThan(positiveX.y, origin.y)
        XCTAssertGreaterThan(positiveY.y, origin.y)

        let followed = ZigProjection(size: size, config: config, cameraProgress: 12, cameraLateral: 2)
        XCTAssertEqual(followed.point(x: 7, y: 5).x, size.width / 2, accuracy: 0.001)
        XCTAssertEqual(followed.point(x: 7, y: 5).y, followed.anchorY, accuracy: 0.001)
    }

    func testCameraProgressNeverMovesBackward() {
        let logic = ZigGameLogic()
        var previous = logic.cameraProgress
        for _ in 0..<400 {
            _ = logic.performPerfectTurnIfNeeded()
            logic.update(deltaTime: 1.0 / 240.0)
            XCTAssertGreaterThanOrEqual(logic.cameraProgress, previous)
            previous = logic.cameraProgress
        }
    }
}
