import XCTest
@testable import MiniGameTrainer

final class TrampboxGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(_ mutate: (inout TrampboxGameConfig) -> Void = { _ in }) -> TrampboxGameLogic {
        var config = TrampboxGameConfig.deterministic(seed: 42)
        mutate(&config)
        let logic = TrampboxGameLogic(config: config, sceneSize: sceneSize)
        logic.startPlaying()
        _ = logic.drainEvents()
        return logic
    }

    private func steerAndLand(_ logic: TrampboxGameLogic, hz: Double = 120) {
        guard let target = logic.targetPlatform else { return XCTFail("Missing target") }
        logic.applyDrag(deltaX: target.centerX - logic.desiredBallX)
        let originalScore = logic.score
        var frames = 0
        while logic.score == originalScore, logic.state == .playing, frames < 1_000 {
            logic.update(deltaTime: 1 / hz)
            frames += 1
        }
        XCTAssertEqual(logic.score, originalScore + logic.config.pointsPerLanding)
    }

    func testSuccessfulLandingAddsOnePointAndRestartsBounce() {
        let logic = makeLogic()
        let departedID = logic.platforms.first!.id
        let oldTargetID = logic.targetPlatform!.id
        steerAndLand(logic)
        XCTAssertEqual(logic.score, 1)
        XCTAssertLessThan(logic.bouncePhase, 0.05)
        XCTAssertEqual(logic.platforms.first?.id, oldTargetID)
        XCTAssertFalse(logic.platforms.contains { $0.id == departedID }, "Departing visual must no longer exist in collision state")
        XCTAssertTrue(logic.drainEvents().contains(.scoreChanged(1)))
    }

    func testSuccessiveAutomaticBouncesScoreWithoutJumpInput() {
        let logic = makeLogic()
        for expected in 1...20 {
            steerAndLand(logic)
            XCTAssertEqual(logic.score, expected)
        }
        XCTAssertEqual(logic.makeSummary().landings, 20)
    }

    func testRelativeDragTracksTargetAtCappedSpeed() {
        let logic = makeLogic()
        let start = logic.ballX
        logic.applyDrag(deltaX: 300)
        logic.update(deltaTime: 0.01)
        XCTAssertEqual(logic.ballX - start, logic.geometry.maximumHorizontalSpeed * 0.01, accuracy: 0.001)
        XCTAssertEqual(logic.horizontalVelocity, logic.geometry.maximumHorizontalSpeed, accuracy: 0.001)
    }

    func testMissTransitionsToFallThenGameOver() {
        let logic = makeLogic {
            $0.initialPlatformWidthRatio = 0.04
            $0.minimumPlatformWidthRatio = 0.04
            $0.minimumHorizontalOffsetRatio = 0.40
            $0.maximumHorizontalOffsetRatio = 0.40
            $0.maximumHorizontalSpeedRatio = 2.0
            $0.initialBounceDuration = 0.8
            $0.minimumBounceDuration = 0.8
            $0.reachabilityMultiplier = 1
        }
        while logic.state == .playing { logic.update(deltaTime: 1.0 / 120.0) }
        XCTAssertEqual(logic.state, .falling)
        let y = logic.ballScreenY
        logic.update(deltaTime: 1.0 / 60.0)
        XCTAssertGreaterThan(logic.ballScreenY, y)
        var guardFrames = 0
        while logic.state == .falling, guardFrames < 1_000 {
            logic.update(deltaTime: 1.0 / 60.0)
            guardFrames += 1
        }
        XCTAssertEqual(logic.state, .gameOver(.missedPlatform))
        XCTAssertTrue(logic.drainEvents().contains(.gameEnded(.missedPlatform)))
    }

    func testFrameRateIndependentPositionAndPhase() {
        let sixty = makeLogic()
        let oneTwenty = makeLogic()
        sixty.applyDrag(deltaX: 180)
        oneTwenty.applyDrag(deltaX: 180)
        for _ in 0..<18 { sixty.update(deltaTime: 1.0 / 60.0) }
        for _ in 0..<36 { oneTwenty.update(deltaTime: 1.0 / 120.0) }
        XCTAssertEqual(sixty.ballX, oneTwenty.ballX, accuracy: 0.001)
        XCTAssertEqual(sixty.ballScreenY, oneTwenty.ballScreenY, accuracy: 0.001)
        XCTAssertEqual(sixty.bouncePhase, oneTwenty.bouncePhase, accuracy: 0.0001)
        XCTAssertEqual(sixty.elapsedTime, oneTwenty.elapsedTime, accuracy: 0.0001)
    }

    func testPauseStopsSimulationAndResumeRestoresIt() {
        let logic = makeLogic()
        logic.update(deltaTime: 0.1)
        logic.pause()
        let phase = logic.bouncePhase
        let elapsed = logic.elapsedTime
        logic.update(deltaTime: 1)
        XCTAssertEqual(logic.bouncePhase, phase)
        XCTAssertEqual(logic.elapsedTime, elapsed)
        logic.resume()
        XCTAssertEqual(logic.state, .playing)
    }

    func testResetRestoresScoreDifficultyBallAndSeededPath() {
        let logic = makeLogic()
        let initialPlatforms = logic.platforms
        for _ in 0..<4 { steerAndLand(logic) }
        XCTAssertEqual(logic.score, 4)
        XCTAssertGreaterThan(logic.elapsedTime, 0)
        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.elapsedTime, 0)
        XCTAssertEqual(logic.bouncePhase, 0)
        XCTAssertEqual(logic.ballX, sceneSize.width * logic.config.startingXRatio, accuracy: 0.001)
        XCTAssertEqual(logic.platforms, initialPlatforms)
        XCTAssertNil(logic.lastLanding)
    }

    func testSummaryDefinesPrecisionAsOneMinusNormalizedCenterError() {
        let logic = makeLogic()
        steerAndLand(logic)
        let summary = logic.makeSummary()
        XCTAssertEqual(summary.landings, 1)
        XCTAssertNotNil(summary.averagePrecision)
        XCTAssertGreaterThanOrEqual(summary.averagePrecision!, 0)
        XCTAssertLessThanOrEqual(summary.averagePrecision!, 1)
        XCTAssertEqual(summary.score, 1)
    }

    func testLargeDeltaIsClamped() {
        let logic = makeLogic()
        logic.update(deltaTime: 10)
        XCTAssertEqual(logic.elapsedTime, logic.config.maximumFrameDelta, accuracy: 1e-12)
    }
}
