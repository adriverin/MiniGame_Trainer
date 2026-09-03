import XCTest
@testable import MiniGameTrainer

final class KeepUpGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(_ mutate: (inout KeepUpGameConfig) -> Void = { _ in }) -> KeepUpGameLogic {
        var config = KeepUpGameConfig.reference
        mutate(&config)
        let logic = KeepUpGameLogic(config: config, sceneSize: sceneSize)
        logic.start()
        return logic
    }

    @discardableResult
    private func autoCatch(_ logic: KeepUpGameLogic, targetScore: Int, hz: Double = 120) -> Int {
        var frames = 0
        var exceededCeiling = false
        while logic.score < targetScore, !logic.isFinished, frames < targetScore * 1_000 + 2_000 {
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x, y: logic.platformY))
            logic.update(deltaTime: 1 / hz)
            if logic.ballPosition.y > logic.geometry.maximumBallY + 1e-4 { exceededCeiling = true }
            frames += 1
        }
        XCTAssertFalse(exceededCeiling, "Ball center passed ceilingY - ballRadius")
        return frames
    }

    func testSuccessfulCatchScoresExactlyOnceAndLaunchesUpward() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0
        }
        autoCatch(logic, targetScore: 1)
        XCTAssertEqual(logic.score, 1)
        XCTAssertGreaterThan(logic.ballVelocity.dy, 0)
        XCTAssertEqual(logic.drainEvents().filter { if case .bounced = $0 { true } else { false } }.count, 1)
        logic.update(deltaTime: 1.0 / 240.0)
        XCTAssertEqual(logic.score, 1, "One contact must not double-count while the ball is rising")
    }

    func testMissEndsRunWithoutChangingScore() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0
        }
        logic.setPlatformPosition(CGPoint(x: logic.geometry.maximumPlatformX, y: logic.platformY))
        for _ in 0..<600 where !logic.isFinished { logic.update(deltaTime: 1.0 / 120.0) }
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.drainEvents().contains(.failed))
    }

    func testAbsoluteTouchTrackingControlsBothAxesAndClampsCenter() {
        let logic = makeLogic()
        logic.beginTouch(position: CGPoint(x: -1_000, y: -1_000), at: 1)
        XCTAssertEqual(logic.platformX, logic.geometry.minimumPlatformX, accuracy: 1e-9)
        XCTAssertEqual(logic.platformY, logic.geometry.minimumPlatformY, accuracy: 1e-9)
        logic.moveTouch(position: CGPoint(x: 10_000, y: 10_000), at: 1.1)
        XCTAssertEqual(logic.platformX, logic.geometry.maximumPlatformX, accuracy: 1e-9)
        XCTAssertEqual(logic.platformY, logic.geometry.maximumPlatformY, accuracy: 1e-9)
        XCTAssertEqual(logic.desiredPlatformPosition, logic.platformPosition)
        XCTAssertGreaterThan(logic.platformVelocity.dx, 0)
        XCTAssertGreaterThan(logic.platformVelocity.dy, 0)
        logic.endTouch()
        XCTAssertEqual(logic.platformVelocity, .zero)
    }

    func testTouchCanMoveXThenYThenBothDiagonally() {
        let logic = makeLogic()
        logic.beginTouch(position: CGPoint(x: 100, y: 100), at: 1)

        logic.moveTouch(position: CGPoint(x: 180, y: 100), at: 1.1)
        XCTAssertEqual(logic.platformPosition, CGPoint(x: 180, y: 100))

        logic.moveTouch(position: CGPoint(x: 180, y: 220), at: 1.2)
        XCTAssertEqual(logic.platformPosition, CGPoint(x: 180, y: 220))

        logic.moveTouch(position: CGPoint(x: 260, y: 300), at: 1.3)
        XCTAssertEqual(logic.platformPosition, CGPoint(x: 260, y: 300))
        XCTAssertGreaterThan(logic.platformVelocity.dx, 0)
        XCTAssertGreaterThan(logic.platformVelocity.dy, 0)
    }

    func testPlatformCenterBoundsIntentionallyAllowCircleClipping() {
        let logic = makeLogic()
        logic.setPlatformPosition(CGPoint(x: -10_000, y: -10_000))
        XCTAssertEqual(logic.platformCenter, CGPoint(x: 0, y: 0))
        XCTAssertLessThan(logic.platformX - logic.geometry.platformRadius, 0)
        XCTAssertLessThan(logic.platformY - logic.geometry.platformRadius, 0)
        logic.setPlatformPosition(CGPoint(x: 10_000, y: logic.geometry.maximumPlatformY))
        XCTAssertEqual(logic.platformX, sceneSize.width, accuracy: 1e-9)
        XCTAssertGreaterThan(logic.platformX + logic.geometry.platformRadius, sceneSize.width)
    }

    func testPauseStopsSimulationAndResumeContinues() {
        let logic = makeLogic()
        logic.update(deltaTime: 0.1)
        logic.pause()
        let position = logic.ballPosition
        let time = logic.elapsedTime
        logic.update(deltaTime: 2)
        XCTAssertEqual(logic.ballPosition, position)
        XCTAssertEqual(logic.elapsedTime, time)
        logic.resume()
        logic.update(deltaTime: 1.0 / 120.0)
        XCTAssertNotEqual(logic.ballPosition, position)
    }

    func testLargeDeltaIsClamped() {
        let logic = makeLogic()
        logic.update(deltaTime: 10)
        XCTAssertEqual(logic.elapsedTime, logic.config.maximumFrameDelta, accuracy: 1e-12)
    }

    func testDiagonalTwoAxisTouchScriptIsEquivalentAtSixtyAndOneTwentyHertz() {
        let sixty = makeLogic { $0.startingHorizontalVelocityWidthRatio = 0 }
        let oneTwenty = makeLogic { $0.startingHorizontalVelocityWidthRatio = 0 }
        sixty.beginTouch(position: CGPoint(x: 40, y: 40), at: 0)
        oneTwenty.beginTouch(position: CGPoint(x: 40, y: 40), at: 0)
        for frame in 1...45 {
            let time = Double(frame) / 60
            sixty.moveTouch(position: CGPoint(x: sixty.ballPosition.x, y: 40 + 160 * time), at: time)
            sixty.update(deltaTime: 1.0 / 60.0)
        }
        for frame in 1...90 {
            let time = Double(frame) / 120
            oneTwenty.moveTouch(position: CGPoint(x: oneTwenty.ballPosition.x, y: 40 + 160 * time), at: time)
            oneTwenty.update(deltaTime: 1.0 / 120.0)
        }
        XCTAssertEqual(sixty.score, oneTwenty.score)
        XCTAssertGreaterThan(sixty.score, 0)
        XCTAssertFalse(sixty.isFinished)
        XCTAssertFalse(oneTwenty.isFinished)
        XCTAssertEqual(sixty.platformPosition.x, oneTwenty.platformPosition.x, accuracy: 0.5)
        XCTAssertEqual(sixty.platformPosition.y, oneTwenty.platformPosition.y, accuracy: 0.01)
        XCTAssertEqual(sixty.ballPosition.x, oneTwenty.ballPosition.x, accuracy: 2.0)
        XCTAssertEqual(sixty.ballPosition.y, oneTwenty.ballPosition.y, accuracy: 2.0)
        XCTAssertEqual(sixty.ballVelocity.dy, oneTwenty.ballVelocity.dy, accuracy: 2.0)
    }

    func testTrailHistoryRemainsBoundedAndExpires() {
        let logic = makeLogic { config in
            config.trailMaximumCount = 8
            config.trailLifetime = 0.2
            config.trailSampleInterval = 0.01
        }
        for _ in 0..<120 {
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x, y: logic.platformY))
            logic.update(deltaTime: 1.0 / 120.0)
            XCTAssertLessThanOrEqual(logic.trailSamples.count, 8)
            XCTAssertTrue(logic.trailSamples.allSatisfy { $0.age <= 0.2 + 1e-9 })
        }
    }

    func testResetRestoresDeterministicInitialState() {
        let logic = makeLogic()
        autoCatch(logic, targetScore: 3)
        logic.setPlatformPosition(CGPoint(x: 100, y: 100))
        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.elapsedTime, 0)
        XCTAssertEqual(logic.ballPosition.x, sceneSize.width * logic.config.startingBallXRatio, accuracy: 1e-9)
        XCTAssertEqual(logic.platformX, sceneSize.width * logic.config.startingPlatformXRatio, accuracy: 1e-9)
        XCTAssertEqual(logic.platformY, sceneSize.height * logic.config.startingPlatformYRatio, accuracy: 1e-9)
        XCTAssertTrue(logic.trailSamples.isEmpty)
        XCTAssertTrue(logic.performance.bounces.isEmpty)
        XCTAssertEqual(logic.ceilingContactCount, 0)
    }

    func testTwoHundredDeterministicCatchesStayStable() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0.22
        }
        let frames = autoCatch(logic, targetScore: 200)
        XCTAssertEqual(logic.score, 200, "Auto-catch timed out after \(frames) frames")
        XCTAssertFalse(logic.isFinished)
        XCTAssertEqual(logic.performance.bounces.count, 200)
        XCTAssertGreaterThan(logic.ceilingContactCount, 0)
        XCTAssertLessThan(logic.ceilingContactCount, 400)
        XCTAssertTrue(logic.ballPosition.x.isFinite && logic.ballPosition.y.isFinite)
        XCTAssertTrue(logic.ballVelocity.dx.isFinite && logic.ballVelocity.dy.isFinite)
        XCTAssertLessThanOrEqual(logic.ballPosition.y, logic.geometry.maximumBallY + 1e-4)
        XCTAssertLessThanOrEqual(logic.trailSamples.count, logic.trailCapacity)
    }

    func testOneHundredDeterministicCatchesStayStableWithTwoAxisPlatformState() {
        let logic = makeLogic { $0.startingHorizontalVelocityWidthRatio = 0 }
        let frames = autoCatch(logic, targetScore: 100, hz: 60)
        XCTAssertEqual(logic.score, 100, "Auto-catch timed out after \(frames) frames")
        XCTAssertFalse(logic.isFinished)
        XCTAssertTrue(logic.platformPosition.x.isFinite && logic.platformPosition.y.isFinite)
    }

    func testLowPlatformCatchOccursBeforeBallEscapesViewport() {
        let logic = makeLogic { config in
            config.startingHorizontalVelocityWidthRatio = 0
            config.startingVerticalVelocityHeightRatio = -0.05
            config.startingBallYRatio = 0.18
            config.startingPlatformYRatio = 0
        }
        autoCatch(logic, targetScore: 1)
        XCTAssertEqual(logic.score, 1)
        XCTAssertFalse(logic.isFinished)
        XCTAssertGreaterThan(logic.ballVelocity.dy, 0)
    }

    func testSummaryReportsCatchMetrics() {
        let logic = makeLogic { $0.startingHorizontalVelocityWidthRatio = 0 }
        autoCatch(logic, targetScore: 3)
        let summary = logic.makeSummary()
        XCTAssertEqual(summary.score, 3)
        XCTAssertEqual(summary.bounces.count, 3)
        XCTAssertNotNil(summary.averageCatchError)
        XCTAssertNotNil(summary.bestCatchError)
        XCTAssertNotNil(summary.closestSaveError)
        XCTAssertGreaterThan(summary.peakBallSpeed, 0)
    }
}
