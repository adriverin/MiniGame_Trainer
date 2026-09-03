import XCTest
@testable import MiniGameTrainer

final class KeepUpCollisionTests: XCTestCase {
    private let platform = CGPoint(x: 100, y: 100)

    private func collision(
        ballFrom: CGPoint,
        ballTo: CGPoint,
        platformFrom: CGPoint? = nil,
        platformTo: CGPoint? = nil,
        tolerance: CGFloat = 0,
        minimumNormalY: CGFloat = 0.18
    ) -> KeepUpCollision? {
        KeepUpPhysics.sweptMovingUpperArcCollision(
            previousBallPosition: ballFrom,
            currentBallPosition: ballTo,
            previousPlatformPosition: platformFrom ?? platform,
            currentPlatformPosition: platformTo ?? platform,
            platformRadius: 50,
            ballRadius: 10,
            effectiveCatchRadius: 46,
            tolerance: tolerance,
            minimumNormalY: minimumNormalY
        )
    }

    func testStationaryPlatformDescendingCenterCrossingCollidesWithUpperArc() {
        let hit = collision(ballFrom: CGPoint(x: 100, y: 180), ballTo: CGPoint(x: 100, y: 140))
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.point.y, 160, accuracy: 1e-9)
        XCTAssertEqual(hit!.normal.dy, 1, accuracy: 1e-9)
    }

    func testRisingBallAgainstStationaryPlatformDoesNotCollide() {
        XCTAssertNil(collision(ballFrom: CGPoint(x: 100, y: 140), ballTo: CGPoint(x: 100, y: 180)))
    }

    func testFastBallCrossingEntirePlatformStillCollides() {
        let hit = collision(ballFrom: CGPoint(x: 100, y: 250), ballTo: CGPoint(x: 100, y: 50))
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.segmentFraction, 0.45, accuracy: 1e-9)
    }

    func testMovingPlatformCrossingBallTrajectoryProducesValidUpperFaceCatch() {
        let hit = collision(
            ballFrom: CGPoint(x: 100, y: 150),
            ballTo: CGPoint(x: 100, y: 150),
            platformFrom: CGPoint(x: 0, y: 100),
            platformTo: CGPoint(x: 200, y: 100)
        )
        XCTAssertNotNil(hit)
        XCTAssertGreaterThan(hit!.normal.dy, 0.8)
        XCTAssertGreaterThan(hit!.normal.dx, 0)
    }

    func testUpwardMovingPlatformCanCatchBallThroughRelativeApproach() {
        let hit = collision(
            ballFrom: CGPoint(x: 100, y: 170),
            ballTo: CGPoint(x: 100, y: 165),
            platformFrom: CGPoint(x: 100, y: 100),
            platformTo: CGPoint(x: 100, y: 120)
        )
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.platformPoint.y, 108, accuracy: 1e-9)
    }

    func testPlatformMovingAwayDoesNotCreateCatch() {
        XCTAssertNil(collision(
            ballFrom: CGPoint(x: 100, y: 180),
            ballTo: CGPoint(x: 100, y: 170),
            platformFrom: CGPoint(x: 100, y: 100),
            platformTo: CGPoint(x: 100, y: 80)
        ))
    }

    func testRapidSidewaysMotionAtPlatformEquatorDoesNotCreatePhantomCatch() {
        XCTAssertNil(collision(
            ballFrom: CGPoint(x: 100, y: 100),
            ballTo: CGPoint(x: 100, y: 100),
            platformFrom: CGPoint(x: 0, y: 100),
            platformTo: CGPoint(x: 200, y: 100)
        ))
    }

    func testRapidSidewaysMotionThatNeverCrossesBallPathDoesNotCreatePhantomCatch() {
        XCTAssertNil(collision(
            ballFrom: CGPoint(x: 100, y: 155),
            ballTo: CGPoint(x: 100, y: 150),
            platformFrom: CGPoint(x: 0, y: 100),
            platformTo: CGPoint(x: 30, y: 100)
        ))
    }

    func testDiagonalHighSpeedSweepDoesNotTunnel() {
        let hit = collision(
            ballFrom: CGPoint(x: 40, y: 230),
            ballTo: CGPoint(x: 150, y: 80),
            platformFrom: CGPoint(x: 150, y: 95),
            platformTo: CGPoint(x: 90, y: 105)
        )
        XCTAssertNotNil(hit)
        XCTAssertGreaterThanOrEqual(hit!.normal.dy, 0.18)
    }

    func testHorizontalMissDoesNotCollide() {
        XCTAssertNil(collision(ballFrom: CGPoint(x: 170, y: 190), ballTo: CGPoint(x: 170, y: 80)))
    }

    func testLowerHemisphereIntersectionDoesNotBounce() {
        XCTAssertNil(collision(ballFrom: CGPoint(x: 100, y: 95), ballTo: CGPoint(x: 100, y: 20)))
    }

    func testToleranceCanAdmitNearEdgeCatch() {
        let without = collision(ballFrom: CGPoint(x: 149, y: 180), ballTo: CGPoint(x: 149, y: 100))
        let with = collision(ballFrom: CGPoint(x: 149, y: 180), ballTo: CGPoint(x: 149, y: 100), tolerance: 4)
        XCTAssertNil(without)
        XCTAssertNotNil(with)
    }
}
