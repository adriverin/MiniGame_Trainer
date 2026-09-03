import XCTest
@testable import MiniGameTrainer

final class KeepUpCeilingTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(_ mutate: (inout KeepUpGameConfig) -> Void = { _ in }) -> KeepUpGameLogic {
        var config = KeepUpGameConfig.reference
        mutate(&config)
        let logic = KeepUpGameLogic(config: config, sceneSize: sceneSize)
        logic.start()
        return logic
    }

    func testRenderedCeilingAndCollisionYShareOneGeometryValue() {
        let geometry = KeepUpGeometry(sceneSize: sceneSize, config: .reference)
        XCTAssertEqual(geometry.ceilingY, geometry.upperLineY, accuracy: 1e-12)
        XCTAssertEqual(geometry.ceilingY, sceneSize.height * KeepUpGameConfig.reference.upperLineYRatio, accuracy: 1e-12)
        XCTAssertEqual(geometry.maximumBallY, geometry.ceilingY - geometry.ballRadius, accuracy: 1e-12)
    }

    func testUpwardBallReversesVYAtCeilingAndPreservesVX() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0.35
            config.startingVerticalVelocityHeightRatio = 2.2
            config.startingBallYRatio = 0.72
            config.startingPlatformYRatio = 0.04
        }
        let vx = logic.ballVelocity.dx
        XCTAssertGreaterThan(vx, 0)
        var frames = 0
        while logic.ceilingContactCount == 0, !logic.isFinished, frames < 500 {
            logic.setPlatformPosition(CGPoint(x: 0, y: 0))
            logic.update(deltaTime: 1.0 / 120.0)
            frames += 1
            XCTAssertLessThanOrEqual(logic.ballPosition.y, logic.geometry.maximumBallY + 1e-6)
        }
        XCTAssertEqual(logic.ceilingContactCount, 1)
        XCTAssertEqual(logic.score, 0)
        XCTAssertLessThan(logic.ballVelocity.dy, 0)
        XCTAssertEqual(logic.ballVelocity.dx, vx, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(logic.ballPosition.y, logic.geometry.maximumBallY + 1e-6)
    }

    func testBallCenterDoesNotPassLegalCeilingMaximum() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0
            config.startingVerticalVelocityHeightRatio = 3.5
            config.startingBallYRatio = 0.50
            config.startingPlatformYRatio = 0
        }
        for _ in 0..<800 {
            logic.setPlatformPosition(.zero)
            logic.update(deltaTime: 1.0 / 60.0)
            XCTAssertLessThanOrEqual(logic.ballPosition.y, logic.geometry.maximumBallY + 1e-6)
            XCTAssertTrue(logic.ballPosition.y.isFinite && logic.ballVelocity.dy.isFinite)
        }
        XCTAssertGreaterThan(logic.ceilingContactCount, 0)
        XCTAssertEqual(logic.score, 0)
    }

    func testCeilingCollisionIsFrameRateIndependent() {
        func run(hz: Double) -> KeepUpGameLogic {
            let logic = makeLogic { config in
                config.startingHorizontalVelocityWidthRatio = 0.2
                config.startingVerticalVelocityHeightRatio = 2.0
                config.startingBallYRatio = 0.68
                config.startingPlatformYRatio = 0.05
            }
            let duration = 0.45
            let frames = Int((duration * hz).rounded())
            for _ in 0..<frames {
                logic.setPlatformPosition(.zero)
                logic.update(deltaTime: 1 / hz)
            }
            return logic
        }
        let sixty = run(hz: 60)
        let oneTwenty = run(hz: 120)
        XCTAssertEqual(sixty.ceilingContactCount, oneTwenty.ceilingContactCount)
        XCTAssertGreaterThan(sixty.ceilingContactCount, 0)
        XCTAssertEqual(sixty.ballPosition.x, oneTwenty.ballPosition.x, accuracy: 0.05)
        XCTAssertEqual(sixty.ballPosition.y, oneTwenty.ballPosition.y, accuracy: 0.05)
        XCTAssertEqual(sixty.ballVelocity.dx, oneTwenty.ballVelocity.dx, accuracy: 0.05)
        XCTAssertEqual(sixty.ballVelocity.dy, oneTwenty.ballVelocity.dy, accuracy: 0.05)
    }

    func testMovingPlatformCatchAfterCeilingDoesNotScoreTheCeiling() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0
            config.startingVerticalVelocityHeightRatio = -0.25
            config.startingBallYRatio = 0.42
            config.startingPlatformYRatio = 0.20
        }
        var frames = 0
        while logic.score < 1, !logic.isFinished, frames < 2_000 {
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x, y: sceneSize.height * 0.20))
            logic.update(deltaTime: 1.0 / 120.0)
            frames += 1
        }
        XCTAssertEqual(logic.score, 1)
        let ceilingsAtFirstCatch = logic.ceilingContactCount

        while logic.ceilingContactCount == ceilingsAtFirstCatch, !logic.isFinished, frames < 4_000 {
            let platformY = sceneSize.height * (0.18 + 0.05 * CGFloat(sin(Double(frames) * 0.04)))
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x + 6, y: platformY))
            logic.update(deltaTime: 1.0 / 120.0)
            frames += 1
        }
        XCTAssertGreaterThan(logic.ceilingContactCount, ceilingsAtFirstCatch)
        XCTAssertEqual(logic.score, 1, "Ceiling contact must not increment score")

        while logic.score < 2, !logic.isFinished, frames < 6_000 {
            let platformY = sceneSize.height * (0.18 + 0.05 * CGFloat(sin(Double(frames) * 0.04)))
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x, y: platformY))
            logic.update(deltaTime: 1.0 / 120.0)
            frames += 1
        }
        XCTAssertEqual(logic.score, 2)
        XCTAssertEqual(logic.performance.bounces.count, 2)
        XCTAssertGreaterThan(logic.ceilingContactCount, 0)
        XCTAssertFalse(logic.isFinished)
    }
}
