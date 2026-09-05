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
}
