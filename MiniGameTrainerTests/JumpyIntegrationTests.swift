import XCTest
@testable import MiniGameTrainer

@MainActor
final class JumpyIntegrationTests: XCTestCase {
    func testRegistryAppendsJumpyAsSixteenthGame() {
        XCTAssertEqual(GameRegistry.descriptors.count, 16)
        XCTAssertEqual(GameRegistry.descriptors.last?.id, "jumpy")
        XCTAssertEqual(GameRegistry.descriptor(for: "jumpy")?.name, "JUMPY")
    }

    func testDistanceScorePresentationIsIntegerHigherIsBetter() {
        let presentation = JumpyGameModule.descriptor.scorePresentation
        XCTAssertEqual(presentation.label, "Distance")
        XCTAssertNil(presentation.unit)
        XCTAssertEqual(presentation.comparison, .higherIsBetter)
        XCTAssertEqual(presentation.formatted(125), "125")
    }

    func testResultContainsMeaningfulMetrics() {
        let summary = JumpySessionSummary(score: 12, duration: 4.25, totalJumps: 18, forwardJumps: 14, sidewaysJumps: 3, backwardJumps: 1)
        let result = JumpyResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "jumpy")
        XCTAssertEqual(result.score, 12)
        XCTAssertEqual(result.scorePresentation, JumpyGameModule.descriptor.scorePresentation)
        XCTAssertEqual(result.metrics.map(\.key), ["distance", "jumps", "forward", "sideways", "backward", "duration"])
    }

    func testJumpyStatisticsPersistHighestDistance() {
        let suite = "JumpyStatistics-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(JumpyResultBuilder.makeResult(from: .init(score: 8, duration: 2, totalJumps: 8, forwardJumps: 8, sidewaysJumps: 0, backwardJumps: 0)))
        store.record(JumpyResultBuilder.makeResult(from: .init(score: 5, duration: 2, totalJumps: 9, forwardJumps: 7, sidewaysJumps: 2, backwardJumps: 0)))
        XCTAssertEqual(store.statistics(for: "jumpy").bestScore, 8)
        XCTAssertEqual(store.statistics(for: "jumpy").gamesPlayed, 2)
        defaults.removePersistentDomain(forName: suite)
    }

    func testJumpyInheritsFreeRewardedAndProAttemptRules() {
        let suite = "JumpyAttempts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let entitlement = StubEntitlement(isPro: false)
        let attempts = AttemptManager(
            userDefaults: defaults,
            clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)),
            calendar: calendar,
            entitlement: entitlement
        )
        for _ in 0..<7 { XCTAssertTrue(attempts.consumeAttempt(for: "jumpy")) }
        XCTAssertEqual(attempts.availability(for: "jumpy"), .exhausted)
        XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "jumpy"))
        XCTAssertEqual(attempts.availability(for: "jumpy"), .rewarded(remaining: 3))
        entitlement.isPro = true
        XCTAssertEqual(attempts.availability(for: "jumpy"), .proUnlimited)
        defaults.removePersistentDomain(forName: suite)
    }

    func testPauseFreezesVisualFollowDuringHop() {
        let config = JumpyGameConfig(randomSeed: 7)
        let scene = JumpyGameScene(size: CGSize(width: 393, height: 852), config: config, debugOptions: .init())
        scene.startSession()
        scene.update(1)
        XCTAssertTrue(scene.logic.requestMove(.up))
        scene.update(1.06)
        let progressBeforePause = scene.visualCameraProgressForTesting
        XCTAssertGreaterThan(progressBeforePause, 0)

        scene.pauseGame()
        scene.update(10)
        XCTAssertEqual(scene.visualCameraProgressForTesting, progressBeforePause, accuracy: 0.0001)
        scene.resumeGame()
        scene.update(20)
        XCTAssertEqual(scene.visualCameraProgressForTesting, progressBeforePause, accuracy: 0.0001)
    }

    func testPauseFreezesFailureHoldAndCompletionRemainsOneShot() {
        let config = JumpyGameConfig(randomSeed: 8)
        let scene = JumpyGameScene(size: CGSize(width: 393, height: 852), config: config, debugOptions: .init())
        let delegate = JumpySceneDelegateSpy()
        scene.gameDelegate = delegate
        scene.startSession()
        scene.logic.replaceRowsForTesting([
            JumpyWorldRow(worldRow: 0, kind: .road(JumpyLane(
                id: 1,
                worldRow: 0,
                direction: .right,
                speed: 0,
                vehicleWidth: 0.16,
                vehicleOffsets: [0.5 + config.trafficMargin],
                groupStartIndices: [0],
                cycleLength: 1.64,
                phase: 0
            )))
        ])
        scene.update(1)
        scene.update(1.01)
        XCTAssertTrue(scene.logic.isFinished)
        XCTAssertEqual(delegate.collisionCount, 1)

        scene.pauseGame()
        scene.update(10)
        scene.resumeGame()
        scene.update(20)
        scene.update(20.10)
        scene.update(20.20)
        scene.update(20.30)
        XCTAssertEqual(delegate.completionCount, 0)
        scene.update(20.39)
        scene.update(21)
        XCTAssertEqual(delegate.completionCount, 1)
    }
}

@MainActor
private final class JumpySceneDelegateSpy: JumpyGameSceneDelegate {
    private(set) var collisionCount = 0
    private(set) var completionCount = 0

    func jumpySceneDidHop(_ scene: JumpyGameScene) {}
    func jumpySceneDidCollide(_ scene: JumpyGameScene) { collisionCount += 1 }
    func jumpyScene(_ scene: JumpyGameScene, didEndWith summary: JumpySessionSummary) { completionCount += 1 }
}
