import XCTest
@testable import MiniGameTrainer

@MainActor
final class AttemptCalendarTests: XCTestCase {
    private var defaults: UserDefaults!
    private var clock: MutableDayClock!
    private var entitlement: StubEntitlement!
    private let suiteName = "AttemptCalendarTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        entitlement = StubEntitlement(isPro: false)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func manager(timeZone: String, now: Date) -> AttemptManager {
        clock = MutableDayClock(now: now)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return AttemptManager(
            userDefaults: defaults,
            clock: clock,
            calendar: calendar,
            entitlement: entitlement
        )
    }

    private func date(_ timeZone: String, year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }

    func testNormalMidnightRolloverResetsFreeAndBonus() {
        let zone = "America/New_York"
        let evening = date(zone, year: 2026, month: 1, day: 15, hour: 23, minute: 30)
        let attempts = manager(timeZone: zone, now: evening)
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "piano") }
        _ = attempts.grantRewardedAttempts(3, for: "piano")
        _ = attempts.consumeAttempt(for: "piano")
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 7)
        XCTAssertEqual(attempts.record(for: "piano").rewardedAttemptsRemaining, 2)

        clock.now = date(zone, year: 2026, month: 1, day: 16, hour: 0, minute: 1)
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 0)
        XCTAssertEqual(attempts.record(for: "piano").rewardedAttemptsRemaining, 0)
    }

    func testDSTSpringForwardKeepsSameLocalDayUntilCalendarDateChanges() {
        let zone = "America/New_York"
        let before = date(zone, year: 2026, month: 3, day: 8, hour: 1, minute: 30)
        let attempts = manager(timeZone: zone, now: before)
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "piano") }
        let dayBefore = attempts.record(for: "piano").localDayIdentifier

        clock.now = date(zone, year: 2026, month: 3, day: 8, hour: 3, minute: 30)
        XCTAssertEqual(attempts.record(for: "piano").localDayIdentifier, dayBefore)
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)

        clock.now = date(zone, year: 2026, month: 3, day: 9, hour: 0, minute: 5)
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
    }

    func testDSTFallBackDoesNotCreateASecondFreeDay() {
        let zone = "America/New_York"
        let afternoon = date(zone, year: 2025, month: 11, day: 2, hour: 15)
        let attempts = manager(timeZone: zone, now: afternoon)
        _ = attempts.consumeAttempt(for: "piano")
        let day = attempts.record(for: "piano").localDayIdentifier

        clock.now = date(zone, year: 2025, month: 11, day: 2, hour: 1, minute: 30)
        XCTAssertEqual(attempts.record(for: "piano").localDayIdentifier, day)
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 6))
    }

    func testTimezoneChangeUsesNewLocalCalendarDay() {
        let eveningLA = date("America/Los_Angeles", year: 2026, month: 6, day: 1, hour: 21)
        let attempts = manager(timeZone: "America/Los_Angeles", now: eveningLA)
        for _ in 0..<3 { _ = attempts.consumeAttempt(for: "piano") }
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 4))

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        attempts.replaceCalendar(tokyo)
        clock.now = eveningLA
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
    }

    func testRelaunchNextDayAfterProcessDeathResets() {
        let zone = "Europe/Paris"
        let night = date(zone, year: 2026, month: 4, day: 10, hour: 22)
        let first = manager(timeZone: zone, now: night)
        for _ in 0..<7 { _ = first.consumeAttempt(for: "piano") }
        _ = first.grantRewardedAttempts(3, for: "piano")

        let morning = date(zone, year: 2026, month: 4, day: 11, hour: 8)
        let reloaded = manager(timeZone: zone, now: morning)
        XCTAssertEqual(reloaded.availability(for: "piano"), .free(remaining: 7))
        XCTAssertEqual(reloaded.record(for: "piano").rewardedAttemptsRemaining, 0)
    }

    func testOpenSessionAcrossMidnightResetsOnNextQuery() {
        let zone = "UTC"
        let beforeMidnight = date(zone, year: 2026, month: 7, day: 1, hour: 23, minute: 59)
        let attempts = manager(timeZone: zone, now: beforeMidnight)
        _ = attempts.consumeAttempt(for: "react")
        clock.now = date(zone, year: 2026, month: 7, day: 2, hour: 0, minute: 0)
        attempts.refreshForCalendarChange()
        XCTAssertEqual(attempts.availability(for: "react"), .free(remaining: 7))
    }

    func testDayIdentifierUsesCalendarComponentsNotEpochDivision() {
        let zone = "America/New_York"
        let dateValue = date(zone, year: 2026, month: 3, day: 8, hour: 1, minute: 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        let identifier = LocalDayIdentifier.make(now: dateValue, calendar: calendar)
        XCTAssertTrue(identifier.contains("2026-03-08"))
        XCTAssertNotEqual(identifier, String(Int(dateValue.timeIntervalSince1970 / 86_400)))
    }
}
