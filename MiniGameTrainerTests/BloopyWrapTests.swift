import XCTest
@testable import MiniGameTrainer

final class BloopyWrapTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testBallMovingPastRightBoundaryStaysInsideAndDoesNotAppearOnLeft() {
        let radius: CGFloat = 10
        let result = BloopyPhysics.horizontalStep(
            position: 378,
            velocity: 80,
            input: .right,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 1,
            worldWidth: 390,
            ballRadius: radius
        )
        XCTAssertEqual(result.position, 390 - radius, accuracy: 1e-9)
        XCTAssertGreaterThan(result.position, 200)
        XCTAssertLessThan(result.position, 390)
        XCTAssertEqual(result.velocity, 0, accuracy: 1e-9)
    }

    func testBallMovingPastLeftBoundaryStaysInsideAndDoesNotAppearOnRight() {
        let radius: CGFloat = 10
        let result = BloopyPhysics.horizontalStep(
            position: 12,
            velocity: -80,
            input: .left,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 1,
            worldWidth: 390,
            ballRadius: radius
        )
        XCTAssertEqual(result.position, radius, accuracy: 1e-9)
        XCTAssertLessThan(result.position, 200)
        XCTAssertGreaterThan(result.position, 0)
        XCTAssertEqual(result.velocity, 0, accuracy: 1e-9)
    }

    func testLogicNeverWrapsBallAcrossHorizontalEdges() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        logic.setHorizontalInput(.right)
        for _ in 0..<180 {
            logic.update(deltaTime: 1 / 60)
            XCTAssertGreaterThanOrEqual(logic.ballPosition.x, logic.geometry.ballMinX - 1e-6)
            XCTAssertLessThanOrEqual(logic.ballPosition.x, logic.geometry.ballMaxX + 1e-6)
        }
        logic.setHorizontalInput(.left)
        for _ in 0..<180 {
            logic.update(deltaTime: 1 / 60)
            XCTAssertGreaterThanOrEqual(logic.ballPosition.x, logic.geometry.ballMinX - 1e-6)
            XCTAssertLessThanOrEqual(logic.ballPosition.x, logic.geometry.ballMaxX + 1e-6)
        }
    }

    func testSteerAwayFromLeftBoundaryImmediately() {
        let radius: CGFloat = 10
        let againstWall = BloopyPhysics.horizontalStep(
            position: radius,
            velocity: -40,
            input: .left,
            acceleration: 80,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 0.1,
            worldWidth: 100,
            ballRadius: radius
        )
        XCTAssertEqual(againstWall.position, radius, accuracy: 1e-9)
        XCTAssertEqual(againstWall.velocity, 0, accuracy: 1e-9)

        let inward = BloopyPhysics.horizontalStep(
            position: againstWall.position,
            velocity: againstWall.velocity,
            input: .right,
            acceleration: 80,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 0.1,
            worldWidth: 100,
            ballRadius: radius
        )
        XCTAssertGreaterThan(inward.position, radius)
        XCTAssertGreaterThan(inward.velocity, 0)
    }

    func testSteerAwayFromRightBoundaryImmediately() {
        let radius: CGFloat = 10
        let worldWidth: CGFloat = 100
        let againstWall = BloopyPhysics.horizontalStep(
            position: worldWidth - radius,
            velocity: 40,
            input: .right,
            acceleration: 80,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 0.1,
            worldWidth: worldWidth,
            ballRadius: radius
        )
        XCTAssertEqual(againstWall.position, worldWidth - radius, accuracy: 1e-9)
        XCTAssertEqual(againstWall.velocity, 0, accuracy: 1e-9)

        let inward = BloopyPhysics.horizontalStep(
            position: againstWall.position,
            velocity: againstWall.velocity,
            input: .left,
            acceleration: 80,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 0.1,
            worldWidth: worldWidth,
            ballRadius: radius
        )
        XCTAssertLessThan(inward.position, worldWidth - radius)
        XCTAssertLessThan(inward.velocity, 0)
    }

    func testLogicCanSteerOffLeftWall() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        logic.placeBallForTesting(
            position: CGPoint(x: logic.geometry.ballMinX, y: logic.ballPosition.y),
            velocity: CGVector(dx: -80, dy: logic.ballVelocity.dy)
        )
        logic.setHorizontalInput(.right)
        logic.update(deltaTime: 1 / 60)
        XCTAssertGreaterThan(logic.ballPosition.x, logic.geometry.ballMinX)
        XCTAssertGreaterThan(logic.ballVelocity.dx, 0)
    }

    func testLogicCanSteerOffRightWall() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        logic.placeBallForTesting(
            position: CGPoint(x: logic.geometry.ballMaxX, y: logic.ballPosition.y),
            velocity: CGVector(dx: 80, dy: logic.ballVelocity.dy)
        )
        logic.setHorizontalInput(.left)
        logic.update(deltaTime: 1 / 60)
        XCTAssertLessThan(logic.ballPosition.x, logic.geometry.ballMaxX)
        XCTAssertLessThan(logic.ballVelocity.dx, 0)
    }

    func testTouchingSideEdgeDoesNotEndTheRun() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        logic.placeBallForTesting(
            position: CGPoint(x: logic.geometry.ballMaxX, y: logic.ballPosition.y),
            velocity: CGVector(dx: 120, dy: logic.bounceImpulse)
        )
        logic.setHorizontalInput(.right)
        for _ in 0..<30 {
            logic.update(deltaTime: 1 / 60)
        }
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.ballPosition.x, logic.geometry.ballMaxX, accuracy: 1e-6)
    }
}
