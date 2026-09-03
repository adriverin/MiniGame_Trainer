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
            worldWidth: 400
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
            worldWidth: 400
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
            worldWidth: 400
        )
        XCTAssertEqual(result.velocity, 200, accuracy: 1e-9)
    }

    func testDescendingCrossingLandsOnce() {
        let platform = BloopyPlatform(id: 1, worldX: 50, worldY: 20, width: 40, kind: .fresh)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 50, y: 40),
            current: CGPoint(x: 50, y: 24),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            worldWidth: 100,
            deltaTime: 1 / 60
        )
        XCTAssertNotNil(contact)
        XCTAssertEqual(contact!.worldPosition.y, 32, accuracy: 1e-9)
        XCTAssertEqual(contact!.platformID, 1)
    }

    func testRisingThroughPlatformDoesNotLand() {
        let platform = BloopyPlatform(id: 1, worldX: 50, worldY: 20, width: 40, kind: .fresh)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 50, y: 10),
            current: CGPoint(x: 50, y: 40),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            worldWidth: 100,
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testWrappedLandingUsesToroidalOverlap() {
        let platform = BloopyPlatform(id: 7, worldX: 8, worldY: 20, width: 20, kind: .fresh)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 96, y: 40),
            current: CGPoint(x: 98, y: 24),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            worldWidth: 100,
            deltaTime: 1 / 60
        )
        XCTAssertNotNil(contact)
        XCTAssertEqual(contact?.platformID, 7)
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
        let falling = logic.ballVelocity.dy
        if falling > 0 {
            // wait until descent if still rising
            var guardFrames = 0
            while logic.ballVelocity.dy > 0, guardFrames < 120, logic.state == .playing {
                logic.update(deltaTime: 1 / 60)
                guardFrames += 1
            }
        }
        let cameraDuringFall = logic.cameraY
        XCTAssertGreaterThanOrEqual(cameraDuringFall, cameraBefore - 1e-6)
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

    func testSameStepWrapCanStillLand() {
        // Test that the wrap function itself correctly handles positions near the boundary
        let w: CGFloat = 390
        let x: CGFloat = w * 0.97  // 378.3
        let moved = x + 20         // 398.3 > 390
        let wrapped = BloopyPhysics.wrap(moved, width: w)
        XCTAssertEqual(wrapped, 8.3, accuracy: 0.1)
        XCTAssertFalse(wrapped.isNaN)
        
        // Verify collision detection works with wrap: ball near right edge,
        // platform near left edge
        let platform = BloopyPlatform(id: 1, worldX: 10, worldY: 50, width: 30, kind: .fresh)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 385, y: 70),
            current: CGPoint(x: 395, y: 54),   // unwrapped x past boundary
            platform: platform,
            ballRadius: 10,
            platformHeight: 8,
            worldWidth: w,
            deltaTime: 1 / 60
        )
        XCTAssertNotNil(contact, "Wrapped landing should detect collision with platform near left edge")
    }
}
