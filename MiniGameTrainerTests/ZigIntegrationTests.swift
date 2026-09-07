import XCTest
@testable import MiniGameTrainer

@MainActor
final class ZigIntegrationTests: XCTestCase {
    func testRegistryAppendsZigAsSeventeenthGame() {
        XCTAssertEqual(GameRegistry.descriptors.count, 19)
        XCTAssertEqual(GameRegistry.descriptors[16].id, "zig")
        XCTAssertEqual(GameRegistry.descriptors[16].name, "ZIG")
    }

    func testResultAndDistancePresentation() {
        let summary = ZigSessionSummary(score: 42, duration: 20.5, turns: 18, maximumSpeed: 2.731)
        let result = ZigResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.score, 42)
        XCTAssertEqual(result.scorePresentation.label, "Distance")
        XCTAssertEqual(result.metrics.map(\.key), ["distance", "turns", "duration", "maximumSpeed"])
    }

    func testStatisticsPersistHighestDistance() {
        let suite = "ZigStatistics-\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        store.record(ZigResultBuilder.makeResult(from: .init(score: 12, duration: 8, turns: 7, maximumSpeed: 2)))
        store.record(ZigResultBuilder.makeResult(from: .init(score: 8, duration: 6, turns: 5, maximumSpeed: 1.8)))
        XCTAssertEqual(store.statistics(for: "zig").bestScore, 12)
        defaults.removePersistentDomain(forName: suite)
    }

    func testZigInheritsAttemptRules() {
        let suite = "ZigAttempts-\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
        let entitlement = StubEntitlement(isPro: false)
        let attempts = AttemptManager(userDefaults: defaults, clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)), calendar: calendar, entitlement: entitlement)
        for _ in 0..<7 { XCTAssertTrue(attempts.consumeAttempt(for: "zig")) }
        XCTAssertEqual(attempts.availability(for: "zig"), .exhausted)
        XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "zig"))
        entitlement.isPro = true
        XCTAssertEqual(attempts.availability(for: "zig"), .proUnlimited)
        defaults.removePersistentDomain(forName: suite)
    }
}
