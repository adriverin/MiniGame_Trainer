import XCTest
@testable import MiniGameTrainer

final class BloopyPhysicsTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testVerticalStepUsesExactConstantAcceleration() {
        let result = BloopyPhysics.verticalStep(position: 100, velocity: 40, gravity: 20, deltaTime: 0.5)
        XCTAssertEqual(result.position, 117.5, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, 30, accuracy: 1e-9)
    }

    func testHoldAcceleratesAndReleaseDamps() {
        let hold = BloopyPhysics.horizontalStep(
            position: 50,
            velocity: 0,
            input: .right,
            acceleration: 100,
            damping: 2,
            maximumSpeed: 200,
            deltaTime: 0.5,
            worldWidth: 400,
            ballRadius: 8
        )
        XCTAssertEqual(hold.velocity, 50, accuracy: 1e-9)

        let coast = BloopyPhysics.horizontalStep(
            position: hold.position,
            velocity: hold.velocity,
            input: .none,
            acceleration: 100,
            damping: 2,
            maximumSpeed: 200,
            deltaTime: 0.5,
            worldWidth: 400,
            ballRadius: 8
        )
        XCTAssertLessThan(abs(coast.velocity), abs(hold.velocity))
        XCTAssertGreaterThan(abs(coast.velocity), 0)
    }

    func testMaximumSpeedIsClamped() {
        let result = BloopyPhysics.horizontalStep(
            position: 50,
            velocity: 190,
            input: .right,
            acceleration: 400,
            damping: 0,
            maximumSpeed: 200,
            deltaTime: 1,
            worldWidth: 400,
            ballRadius: 8
        )
        XCTAssertEqual(result.velocity, 200, accuracy: 1e-9)
    }

    func testDescendingCrossingLandsOnce() {
        let platform = BloopyPlatform(id: 1, worldX: 50, worldY: 20, width: 40)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 50, y: 40),
            current: CGPoint(x: 50, y: 24),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            deltaTime: 1 / 60
        )
        XCTAssertNotNil(contact)
        XCTAssertEqual(contact!.worldPosition.y, 32, accuracy: 1e-9)
        XCTAssertEqual(contact!.platformID, 1)
    }

    func testRisingThroughPlatformDoesNotLand() {
        let platform = BloopyPlatform(id: 1, worldX: 50, worldY: 20, width: 40)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 50, y: 10),
            current: CGPoint(x: 50, y: 40),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testBallNearLeftEdgeDoesNotCollideWithRightPlatform() {
        let platform = BloopyPlatform(id: 7, worldX: 380, worldY: 20, width: 20)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 12, y: 40),
            current: CGPoint(x: 10, y: 24),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testBallNearRightEdgeDoesNotCollideWithLeftPlatform() {
        let platform = BloopyPlatform(id: 1, worldX: 10, worldY: 50, width: 30)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 385, y: 70),
            current: CGPoint(x: 395, y: 54),
            platform: platform,
            ballRadius: 10,
            platformHeight: 8,
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testLogicLeftEdgeDoesNotLandOnRightPlatform() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let farRight = BloopyPlatform(
            id: 9_001,
            worldX: sceneSize.width - 20,
            worldY: logic.ballPosition.y - 40,
            width: 28
        )
        logic.replacePlatformsForTesting([farRight])
        let top = logic.geometry.platformTop(worldY: farRight.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: logic.geometry.ballMinX + 2, y: top + logic.geometry.ballRadius + 16),
            velocity: CGVector(dx: 0, dy: -220),
            previous: CGPoint(x: logic.geometry.ballMinX + 2, y: top + logic.geometry.ballRadius + 16)
        )
        let before = logic.landingCount
        logic.update(deltaTime: 1 / 60)
        XCTAssertEqual(logic.landingCount, before)
        XCTAssertNil(logic.lastLanding)
    }

    func testLogicRightEdgeDoesNotLandOnLeftPlatform() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let farLeft = BloopyPlatform(
            id: 9_002,
            worldX: 20,
            worldY: logic.ballPosition.y - 40,
            width: 28
        )
        logic.replacePlatformsForTesting([farLeft])
        let top = logic.geometry.platformTop(worldY: farLeft.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: logic.geometry.ballMaxX - 2, y: top + logic.geometry.ballRadius + 16),
            velocity: CGVector(dx: 0, dy: -220),
            previous: CGPoint(x: logic.geometry.ballMaxX - 2, y: top + logic.geometry.ballRadius + 16)
        )
        let before = logic.landingCount
        logic.update(deltaTime: 1 / 60)
        XCTAssertEqual(logic.landingCount, before)
        XCTAssertNil(logic.lastLanding)
    }

    func testSixtyAndOneTwentyHertzTrajectoriesMatch() {
        let config = BloopyGameConfig.deterministic()
        let slow = BloopyGameLogic(config: config, sceneSize: sceneSize)
        let fast = BloopyGameLogic(config: config, sceneSize: sceneSize)
        slow.start()
        fast.start()
        slow.setHorizontalInput(.right)
        fast.setHorizontalInput(.right)
        for _ in 0..<90 { slow.update(deltaTime: 1 / 60) }
        for _ in 0..<180 { fast.update(deltaTime: 1 / 120) }
        XCTAssertEqual(slow.ballPosition.x, fast.ballPosition.x, accuracy: 1.5)
        XCTAssertEqual(slow.ballPosition.y, fast.ballPosition.y, accuracy: 1.5)
        XCTAssertEqual(slow.landingCount, fast.landingCount)
        XCTAssertEqual(slow.score, fast.score)
    }

    func testCameraStaysPutBelowFollowLineThenTracksAbove() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        let geometry = BloopyGeometry(sceneSize: sceneSize, config: .deterministic())
        logic.start()
        XCTAssertLessThan(logic.ballPosition.y, geometry.cameraFollowY)
        logic.update(deltaTime: 1 / 60)
        XCTAssertEqual(logic.cameraY, 0, accuracy: 1e-9)

        while logic.score < 40, logic.state == .playing {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
        }
        XCTAssertGreaterThan(logic.cameraY, 0)
        if logic.ballPosition.y >= logic.cameraY + geometry.cameraFollowY - 1 {
            XCTAssertEqual(logic.ballScreenPosition.y, geometry.cameraFollowY, accuracy: 2)
        }
        let cameraBefore = logic.cameraY
        logic.setHorizontalInput(.none)
        if logic.ballVelocity.dy > 0 {
            var guardFrames = 0
            while logic.ballVelocity.dy > 0, guardFrames < 120, logic.state == .playing {
                logic.update(deltaTime: 1 / 60)
                guardFrames += 1
            }
        }
        XCTAssertGreaterThanOrEqual(logic.cameraY, cameraBefore - 1e-6)
    }

    func testLandingDoesNotBounceTwiceAcrossAdjacentFrames() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var lastCount = logic.landingCount
        var doubleHits = 0
        for _ in 0..<240 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            if logic.landingCount > lastCount + 1 { doubleHits += 1 }
            lastCount = logic.landingCount
        }
        XCTAssertEqual(doubleHits, 0)
        XCTAssertGreaterThan(logic.landingCount, 2)
    }
}
