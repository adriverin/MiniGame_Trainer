import XCTest
@testable import MiniGameTrainer

final class CenterHitGameLogicTests: XCTestCase {
    func testFreshSessionHasNoAttemptMarkerPositions() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        XCTAssertTrue(logic.attemptMarkerPositions.isEmpty)
    }

    @MainActor
    func testFirstRenderedMarkerUsesExactEvaluatedPositionWithoutChangingScoreOrMovement() {
        let scene = CenterHitGameScene(
            size: CGSize(width: 390, height: 844),
            config: .reference,
            debugOptions: .none
        )
        scene.startSession()
        XCTAssertEqual(scene.renderedAttemptMarkerCount, 0)
        let timestamp = scene.logic.lastSimulationTimestamp!
        guard case .scored(let attempt) = scene.logic.handleTap(at: timestamp) else {
            return XCTFail("Expected first tap to score")
        }
        let score = attempt.precision
        let position = scene.logic.position
        let direction = scene.logic.direction

        scene.syncAttemptMarkers()

        XCTAssertEqual(scene.renderedAttemptMarkerCount, 1)
        XCTAssertEqual(scene.renderedAttemptMarkerPositions[0], CGFloat(attempt.indicatorX), accuracy: 1e-9)
        XCTAssertEqual(scene.logic.attempts[0].precision, score, accuracy: 1e-12)
        XCTAssertEqual(scene.logic.position, position, accuracy: 1e-12)
        XCTAssertEqual(scene.logic.direction, direction)
    }

    @MainActor
    func testMarkerHistoryRetainsEveryAttemptAndResetClearsIt() {
        let scene = CenterHitGameScene(
            size: CGSize(width: 390, height: 844),
            config: .reference,
            debugOptions: .none
        )
        scene.startSession()
        let timestamp = scene.logic.lastSimulationTimestamp!
        for index in 0..<4 {
            _ = scene.logic.handleTap(at: timestamp + Double(index) * 0.001)
        }
        scene.syncAttemptMarkers()
        XCTAssertEqual(scene.renderedAttemptMarkerCount, 4)
        for (rendered, evaluated) in zip(scene.renderedAttemptMarkerPositions, scene.logic.attemptMarkerPositions) {
            XCTAssertEqual(Double(rendered), evaluated, accuracy: 0.0001)
        }

        scene.startSession()
        XCTAssertEqual(scene.renderedAttemptMarkerCount, 0)
        XCTAssertTrue(scene.logic.attemptMarkerPositions.isEmpty)
    }

    func testReferenceSpeedsIncreaseAfterEveryScoredTap() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        var speeds = [logic.currentSpeed]
        for index in 0..<4 {
            _ = logic.handleTap(at: Double(index) * 0.001)
            speeds.append(logic.currentSpeed)
        }
        let expected = [94.0, 144.0, 190.0, 230.0, 300.0]
        for (actual, expected) in zip(speeds, expected) {
            XCTAssertEqual(actual, expected, accuracy: 1e-9)
        }
        for pair in zip(speeds, speeds.dropFirst()) { XCTAssertLessThan(pair.0, pair.1) }
    }

    func testFiveTapsFinishAndSixthTapIsIgnored() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        for index in 1...4 {
            guard case .scored(let attempt) = logic.handleTap(at: Double(index) * 0.01) else {
                return XCTFail("Tap \(index) should score")
            }
            XCTAssertEqual(attempt.attemptNumber, index)
            XCTAssertFalse(logic.isFinished)
        }
        guard case .finished(let fifth) = logic.handleTap(at: 0.05) else { return XCTFail("Fifth tap should finish") }
        XCTAssertEqual(fifth.attemptNumber, 5)
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.handleTap(at: 0.06), .ignored)
        XCTAssertEqual(logic.attempts.count, 5)
    }

    func testTapDoesNotResetPositionOrDirection() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        logic.update(at: 0.1)
        XCTAssertEqual(logic.position, 59.4, accuracy: 1e-9)
        _ = logic.handleTap(at: 0.1)
        XCTAssertEqual(logic.position, 59.4, accuracy: 1e-9)
        XCTAssertEqual(logic.direction, .right)
        logic.update(at: 0.2)
        XCTAssertEqual(logic.position, 73.8, accuracy: 1e-9)
    }

    func testTapRecordsDirectionSpeedAndErrorTelemetry() {
        let logic = CenterHitGameLogic(config: .reference, leftBoundary: 0, rightBoundary: 100)
        logic.start(at: 0)
        guard case .scored(let attempt) = logic.handleTap(at: 0.1) else { return XCTFail("Expected score") }
        XCTAssertEqual(attempt.indicatorX, 59.4, accuracy: 1e-9)
        XCTAssertEqual(attempt.centerX, 50, accuracy: 1e-9)
        XCTAssertEqual(attempt.absoluteError, 9.4, accuracy: 1e-9)
        XCTAssertEqual(attempt.normalizedError, 0.188, accuracy: 1e-9)
        XCTAssertEqual(attempt.precision, 81.2, accuracy: 1e-9)
        XCTAssertEqual(attempt.direction, .right)
        XCTAssertEqual(attempt.speed, 94, accuracy: 1e-9)
    }

    func testReadyTapStartsButDoesNotConsumeAttemptWhenConfigured() {
        var config = CenterHitGameConfig.reference
        config.requiresTapToStart = true
        let logic = CenterHitGameLogic(config: config, leftBoundary: 0, rightBoundary: 100)
        XCTAssertEqual(logic.handleTap(at: 2), .started)
        XCTAssertEqual(logic.attempts.count, 0)
        XCTAssertEqual(logic.state, .running)
    }

    func testResetRestoresInitialState() {
        var config = CenterHitGameConfig.reference
        config.initialPositionRatio = 0.25
        config.initialDirection = .left
        let logic = CenterHitGameLogic(config: config, leftBoundary: 10, rightBoundary: 110)
        logic.start(at: 0)
        _ = logic.handleTap(at: 0.1)
        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.position, 35, accuracy: 1e-12)
        XCTAssertEqual(logic.direction, .left)
        XCTAssertTrue(logic.attempts.isEmpty)
        XCTAssertNil(logic.lastSimulationTimestamp)
    }

    func testSummaryCalculatesAverageBestWorstErrorsAndDirectionBias() {
        let attempts = [
            attempt(1, precision: 98, error: 2, direction: .right),
            attempt(2, precision: 94, error: 6, direction: .left),
            attempt(3, precision: 100, error: 0, direction: .right),
            attempt(4, precision: 96, error: 4, direction: .left),
            attempt(5, precision: 97, error: 3, direction: .right),
        ]
        let summary = CenterHitSessionSummary(attempts: attempts, duration: 10)
        XCTAssertEqual(summary.averagePrecision!, 97, accuracy: 1e-12)
        XCTAssertEqual(summary.bestPrecision!, 100, accuracy: 1e-12)
        XCTAssertEqual(summary.worstPrecision!, 94, accuracy: 1e-12)
        XCTAssertEqual(summary.averageCenterError!, 3, accuracy: 1e-12)
        XCTAssertEqual(summary.bestCenterError!, 0, accuracy: 1e-12)
        XCTAssertEqual(summary.leftToRightAveragePrecision!, 98.3333333333, accuracy: 1e-9)
        XCTAssertEqual(summary.rightToLeftAveragePrecision!, 95, accuracy: 1e-12)
        XCTAssertEqual(summary.scoreBasisPoints, 9_700)
    }

    @MainActor
    func testResultBuilderUsesPrecisionPresentationAndBasisPointScore() {
        let summary = CenterHitSessionSummary(
            attempts: (1...5).map { attempt($0, precision: 97.89, error: 8.78, direction: $0.isMultiple(of: 2) ? .left : .right) },
            duration: 10.1
        )
        let result = CenterHitResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "centerHit")
        XCTAssertEqual(result.score, 9_789)
        XCTAssertEqual(result.scorePresentation, .precisionPercent)
        XCTAssertEqual(result.scorePresentation.formatted(result.score), "97.89%")
        XCTAssertEqual(result.accuracy!, 0.9789, accuracy: 1e-12)
        XCTAssertEqual(result.metrics.last?.value, "5")
    }

    private func attempt(_ number: Int, precision: Double, error: Double, direction: CenterHitDirection) -> CenterHitAttempt {
        CenterHitAttempt(
            attemptNumber: number,
            tapTimestamp: Double(number),
            indicatorX: 50 + (direction == .right ? error : -error),
            centerX: 50,
            absoluteError: error,
            normalizedError: error / 50,
            precision: precision,
            direction: direction,
            speed: 100
        )
    }
}
