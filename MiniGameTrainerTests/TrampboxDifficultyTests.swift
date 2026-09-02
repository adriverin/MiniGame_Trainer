import XCTest
@testable import MiniGameTrainer

final class TrampboxDifficultyTests: XCTestCase {
    func testBounceDurationDecreasesWithScore() {
        let model = TrampboxDifficultyModel(config: .reference)
        XCTAssertGreaterThan(model.bounceDuration(for: 0), model.bounceDuration(for: 50))
        XCTAssertGreaterThan(model.bounceDuration(for: 50), model.bounceDuration(for: 100))
    }

    func testBounceDurationNeverDropsBelowMinimum() {
        let config = TrampboxGameConfig.reference
        let model = TrampboxDifficultyModel(config: config)
        XCTAssertEqual(model.bounceDuration(for: 10_000), config.minimumBounceDuration, accuracy: 1e-12)
    }

    func testPlatformWidthDecreasesWithScore() {
        let model = TrampboxDifficultyModel(config: .reference)
        XCTAssertGreaterThan(model.platformWidthRatio(for: 0), model.platformWidthRatio(for: 80))
        XCTAssertGreaterThan(model.platformWidthRatio(for: 80), model.platformWidthRatio(for: 160))
    }

    func testPlatformWidthNeverDropsBelowMinimum() {
        let config = TrampboxGameConfig.reference
        let model = TrampboxDifficultyModel(config: config)
        XCTAssertEqual(model.platformWidthRatio(for: 10_000), config.minimumPlatformWidthRatio, accuracy: 1e-12)
    }

    func testReferenceCurveMatchesMeasuredVideoAnchors() {
        let model = TrampboxDifficultyModel(config: .reference)
        XCTAssertEqual(model.bounceDuration(for: 0), 0.68, accuracy: 0.001)
        XCTAssertEqual(model.bounceDuration(for: 80), 0.416, accuracy: 0.001)
        XCTAssertEqual(model.bounceDuration(for: 160), 0.30, accuracy: 0.001)
        XCTAssertEqual(model.platformWidthRatio(for: 0), 0.25, accuracy: 0.001)
        XCTAssertEqual(model.platformWidthRatio(for: 160), 0.122, accuracy: 0.001)
    }

    func testNegativeScoreUsesInitialDifficulty() {
        let model = TrampboxDifficultyModel(config: .reference)
        XCTAssertEqual(model.bounceDuration(for: -1), model.bounceDuration(for: 0))
        XCTAssertEqual(model.platformWidthRatio(for: -1), model.platformWidthRatio(for: 0))
    }

    func testPlatformSpacingConvergesTowardHorizon() {
        let geometry = TrampboxGeometry(sceneSize: CGSize(width: 393, height: 852), config: .reference)
        let y0 = geometry.platformTopY(slot: 0, bouncePhase: 0)
        let y1 = geometry.platformTopY(slot: 1, bouncePhase: 0)
        let y2 = geometry.platformTopY(slot: 2, bouncePhase: 0)
        let y7 = geometry.platformTopY(slot: 7, bouncePhase: 0)
        XCTAssertEqual(y0 - y1, geometry.platformSpacing, accuracy: 0.001)
        XCTAssertGreaterThan(y0 - y1, y1 - y2)
        XCTAssertGreaterThan(y7, geometry.horizonY)
        XCTAssertLessThan(y7, y2)
    }

    func testProjectedWidthIncreasesMonotonicallyTowardForeground() {
        let geometry = TrampboxGeometry(sceneSize: CGSize(width: 393, height: 852), config: .reference)
        let logicalWidth: CGFloat = 100
        let far = geometry.projectedPlatformWidth(logicalWidth: logicalWidth, atScreenY: geometry.horizonY)
        let middle = geometry.projectedPlatformWidth(logicalWidth: logicalWidth, atScreenY: (geometry.horizonY + geometry.landingY) / 2)
        let near = geometry.projectedPlatformWidth(logicalWidth: logicalWidth, atScreenY: geometry.landingY)
        XCTAssertGreaterThan(middle, far)
        XCTAssertGreaterThan(near, middle)
        XCTAssertEqual(far, logicalWidth * 0.40, accuracy: 0.001)
        XCTAssertEqual(near, logicalWidth, accuracy: 0.001)
    }

    func testProjectedTopAndSideDepthGrowTowardForeground() {
        let geometry = TrampboxGeometry(sceneSize: CGSize(width: 393, height: 852), config: .reference)
        let logicalWidth: CGFloat = 100
        let farWidth = geometry.projectedPlatformWidth(logicalWidth: logicalWidth, atScreenY: geometry.horizonY)
        let nearWidth = geometry.projectedPlatformWidth(logicalWidth: logicalWidth, atScreenY: geometry.landingY)
        let farTop = geometry.projectedTopDepth(projectedWidth: farWidth, atScreenY: geometry.horizonY)
        let nearTop = geometry.projectedTopDepth(projectedWidth: nearWidth, atScreenY: geometry.landingY)
        let farSide = geometry.projectedSideDepth(projectedWidth: farWidth, atScreenY: geometry.horizonY)
        let nearSide = geometry.projectedSideDepth(projectedWidth: nearWidth, atScreenY: geometry.landingY)
        XCTAssertGreaterThan(nearTop, farTop)
        XCTAssertGreaterThan(nearSide, farSide)
        XCTAssertEqual(farTop / farWidth, 0.18, accuracy: 0.001)
        XCTAssertEqual(nearTop / nearWidth, 0.54, accuracy: 0.001)
        XCTAssertEqual(nearSide / nearWidth, 0.14, accuracy: 0.001)
    }

    func testApproachRotationResolvesToZeroAtLanding() {
        let geometry = TrampboxGeometry(sceneSize: CGSize(width: 393, height: 852), config: .reference)
        for id in 0..<20 {
            XCTAssertEqual(geometry.approachRotation(platformID: id, atScreenY: geometry.landingY), 0, accuracy: 0.000_001)
        }
        XCTAssertNotEqual(geometry.approachRotation(platformID: 3, atScreenY: (geometry.horizonY + geometry.landingY) / 2), 0)
    }
}
