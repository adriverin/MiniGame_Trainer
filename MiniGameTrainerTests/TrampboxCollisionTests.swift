import XCTest
@testable import MiniGameTrainer

final class TrampboxCollisionTests: XCTestCase {
    func testDescendingOverlappingBallLands() {
        XCTAssertTrue(TrampboxCollisionDetector.didLand(
            previousBallBottom: 98,
            currentBallBottom: 102,
            previousPlatformTop: 100,
            currentPlatformTop: 100,
            descending: true,
            ballX: 50,
            ballRadius: 8,
            platformCenterX: 50,
            platformWidth: 40,
            rule: .ballOverlap,
            tolerance: 1
        ))
    }

    func testAscendingCrossingDoesNotLand() {
        XCTAssertFalse(TrampboxCollisionDetector.didLand(
            previousBallBottom: 102,
            currentBallBottom: 98,
            previousPlatformTop: 100,
            currentPlatformTop: 100,
            descending: false,
            ballX: 50,
            ballRadius: 8,
            platformCenterX: 50,
            platformWidth: 40,
            rule: .ballOverlap,
            tolerance: 1
        ))
    }

    func testBallOutsidePlatformMisses() {
        XCTAssertFalse(TrampboxCollisionDetector.didLand(
            previousBallBottom: 98,
            currentBallBottom: 102,
            previousPlatformTop: 100,
            currentPlatformTop: 100,
            descending: true,
            ballX: 100,
            ballRadius: 8,
            platformCenterX: 50,
            platformWidth: 40,
            rule: .ballOverlap,
            tolerance: 1
        ))
    }

    func testCenterRuleIsStricterThanOverlapRule() {
        let common = (ballX: CGFloat(73), radius: CGFloat(8), center: CGFloat(50), width: CGFloat(40))
        XCTAssertFalse(TrampboxCollisionDetector.horizontallyOverlaps(
            ballX: common.ballX, ballRadius: common.radius, platformCenterX: common.center,
            platformWidth: common.width, rule: .centerInsidePlatform, tolerance: 1
        ))
        XCTAssertTrue(TrampboxCollisionDetector.horizontallyOverlaps(
            ballX: common.ballX, ballRadius: common.radius, platformCenterX: common.center,
            platformWidth: common.width, rule: .ballOverlap, tolerance: 1
        ))
    }
}
