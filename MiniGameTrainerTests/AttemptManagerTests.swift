import XCTest
@testable import MiniGameTrainer

@MainActor
final class AttemptManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var clock: MutableDayClock!
    private var entitlement: StubEntitlement!
    private let suiteName = "AttemptManagerTests"
    private let day = Date(timeIntervalSince1970: 1_767_398_400) // 2026-01-15 00:00 UTC

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        clock = MutableDayClock(now: day)
        entitlement = StubEntitlement(isPro: false)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func manager(calendar: Calendar = Calendar(identifier: .gregorian)) -> AttemptManager {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return AttemptManager(
            userDefaults: defaults,
            clock: clock,
            calendar: calendar,
            entitlement: entitlement
        )
    }

    func testNewUserHasSevenRemaining() {
        XCTAssertEqual(manager().availability(for: "piano"), .free(remaining: 7))
    }

    func testConsumeDecrementsToSix() {
        let attempts = manager()
        XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 6))
    }

    func testConsumeSevenReachesZero() {
        let attempts = manager()
        for _ in 0..<7 {
            XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        }
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 7)
    }

    func testEighthAuthorizationIsBlocked() {
        let attempts = manager()
        for _ in 0..<7 {
            XCTAssertEqual(attempts.beginPlayableRun(for: "piano"), .started)
        }
        XCTAssertEqual(attempts.beginPlayableRun(for: "piano"), .blocked)
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)
    }

    func testRewardGrantsThreeThenConsumesToZero() {
        let attempts = manager()
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "piano") }
        XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .rewarded(remaining: 3))
        XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .rewarded(remaining: 2))
        XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .rewarded(remaining: 1))
        XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)
        XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .rewarded(remaining: 3))
    }

    func testDifferentGameStillHasSevenFree() {
        let attempts = manager()
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "piano") }
        XCTAssertEqual(attempts.availability(for: "bloopy"), .free(remaining: 7))
        XCTAssertEqual(attempts.availability(for: "targetSpeed"), .free(remaining: 7))
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)
    }

    func testRejectsPreBankedRewardWhileAttemptsRemain() {
        let attempts = manager()
        XCTAssertFalse(attempts.grantRewardedAttempts(3, for: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
        XCTAssertTrue(attempts.consumeAttempt(for: "piano"))
        XCTAssertFalse(attempts.grantRewardedAttempts(3, for: "piano"))
        XCTAssertEqual(attempts.record(for: "piano").rewardedAttemptsRemaining, 0)
        XCTAssertFalse(attempts.canRequestRewardedGrant(for: "piano"))
    }

    func testRewardAvailableOnlyWhenExhausted() {
        let attempts = manager()
        XCTAssertFalse(attempts.canRequestRewardedGrant(for: "piano"))
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "piano") }
        XCTAssertTrue(attempts.canRequestRewardedGrant(for: "piano"))
        _ = attempts.grantRewardedAttempts(3, for: "piano")
        XCTAssertFalse(attempts.canRequestRewardedGrant(for: "piano"))
    }

    func testProAvailabilityUnlimitedAndDoesNotDecrement() {
        entitlement.isPro = true
        let attempts = manager()
        XCTAssertEqual(attempts.availability(for: "piano"), .proUnlimited)
        for _ in 0..<100 {
            XCTAssertTrue(attempts.consumeAttempt(for: "react"))
        }
        entitlement.isPro = false
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
        XCTAssertEqual(attempts.availability(for: "react"), .free(remaining: 7))
        XCTAssertEqual(attempts.record(for: "react").freeAttemptsUsed, 0)
        XCTAssertEqual(attempts.record(for: "react").rewardedAttemptsRemaining, 0)
    }

    func testProExpirationRestoresSameDayFreeState() {
        let attempts = manager()
        for _ in 0..<4 { _ = attempts.consumeAttempt(for: "piano") }
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 3))
        entitlement.isPro = true
        for _ in 0..<12 {
            XCTAssertEqual(attempts.beginPlayableRun(for: "piano"), .started)
        }
        entitlement.isPro = false
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 3))
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 4)
    }

    func testPersistsAcrossRelaunchSameDay() {
        let first = manager()
        _ = first.consumeAttempt(for: "piano")
        let reloaded = manager()
        XCTAssertEqual(reloaded.availability(for: "piano"), .free(remaining: 6))
    }

    func testCorruptedPersistenceResetsSafely() {
        defaults.set(Data("not-json".utf8), forKey: MonetizationConfiguration.persistenceKey)
        XCTAssertEqual(manager().availability(for: "piano"), .free(remaining: 7))
    }

    func testEveryRegisteredGameHasStableMonetizationIDAndOwnAllowance() {
        let attempts = manager()
        let ids = GameRegistry.modules.map { $0.descriptor.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.count, 15)
        for id in ids {
            XCTAssertFalse(id.isEmpty)
            XCTAssertEqual(attempts.availability(for: id), .free(remaining: 7))
        }
        _ = attempts.consumeAttempt(for: ids[0])
        XCTAssertEqual(attempts.availability(for: ids[0]), .free(remaining: 6))
        XCTAssertEqual(attempts.availability(for: ids[1]), .free(remaining: 7))
    }
}
