import Foundation
import Combine

/// Central per-game / local-day attempt service. Individual minigames must not
/// implement their own counters.
@MainActor
final class AttemptManager: ObservableObject {
    let freeLimit: Int
    let rewardGrant: Int

    @Published private(set) var revision = 0

    private let store: AttemptStore
    private let clock: DayClock
    private var calendar: Calendar
    private let entitlement: ProEntitlementStatus
    private var records: [String: DailyAttemptRecord]

    #if DEBUG
    var debugDayIdentifierOverride: String?
    #endif

    init(
        userDefaults: UserDefaults = .standard,
        clock: DayClock = SystemDayClock(),
        calendar: Calendar = .autoupdatingCurrent,
        entitlement: ProEntitlementStatus,
        freeLimit: Int = MonetizationConfiguration.freeAttemptsPerGamePerDay,
        rewardGrant: Int = MonetizationConfiguration.rewardedAttemptGrant
    ) {
        self.store = AttemptStore(userDefaults: userDefaults)
        self.clock = clock
        self.calendar = calendar
        self.entitlement = entitlement
        self.freeLimit = freeLimit
        self.rewardGrant = rewardGrant
        self.records = store.load()
    }

    var isPro: Bool { entitlement.isPro }

    func currentDayIdentifier() -> String {
        #if DEBUG
        if let debugDayIdentifierOverride {
            return debugDayIdentifierOverride
        }
        #endif
        return LocalDayIdentifier.make(now: clock.now, calendar: calendar)
    }

    func record(for gameID: String) -> DailyAttemptRecord {
        let day = currentDayIdentifier()
        if let existing = records[gameID], existing.localDayIdentifier == day {
            return existing
        }
        let fresh = DailyAttemptRecord.fresh(gameID: gameID, day: day)
        records[gameID] = fresh
        persist()
        return fresh
    }

    func availability(for gameID: String) -> AttemptAvailability {
        if entitlement.isEnabled(.unlimitedAttempts) {
            return .proUnlimited
        }
        let snapshot = record(for: gameID)
        let freeRemaining = snapshot.freeRemaining(limit: freeLimit)
        if freeRemaining > 0 {
            return .free(remaining: freeRemaining)
        }
        if snapshot.rewardedAttemptsRemaining > 0 {
            return .rewarded(remaining: snapshot.rewardedAttemptsRemaining)
        }
        return .exhausted
    }

    /// Atomic authorize + consume. The only supported way to start a playable run.
    @discardableResult
    func beginPlayableRun(for gameID: String) -> PlayableRunStart {
        consumeAttempt(for: gameID) ? .started : .blocked
    }

    @discardableResult
    func consumeAttempt(for gameID: String) -> Bool {
        if entitlement.isEnabled(.unlimitedAttempts) {
            MonetizationLog.debug("Pro bypass consume game=\(gameID)")
            publish()
            return true
        }

        var snapshot = record(for: gameID)
        if snapshot.freeRemaining(limit: freeLimit) > 0 {
            snapshot.freeAttemptsUsed += 1
            records[gameID] = snapshot
            persist()
            publish()
            MonetizationLog.debug("Consumed free attempt game=\(gameID) used=\(snapshot.freeAttemptsUsed)/\(freeLimit)")
            return true
        }
        if snapshot.rewardedAttemptsRemaining > 0 {
            snapshot.rewardedAttemptsRemaining -= 1
            records[gameID] = snapshot
            persist()
            publish()
            MonetizationLog.debug("Consumed rewarded attempt game=\(gameID) bonus=\(snapshot.rewardedAttemptsRemaining)")
            return true
        }
        MonetizationLog.debug("Blocked consume game=\(gameID)")
        return false
    }

    @discardableResult
    func grantRewardedAttempts(_ count: Int, for gameID: String) -> Bool {
        grantRewardedAttempts(count, for: gameID, bypassExhaustionCheck: false)
    }

    @discardableResult
    func grantRewardedAttempts(_ count: Int, for gameID: String, bypassExhaustionCheck: Bool) -> Bool {
        guard count > 0 else { return false }
        if entitlement.isEnabled(.unlimitedAttempts) {
            MonetizationLog.debug("Ignored reward grant while Pro game=\(gameID)")
            return false
        }
        var snapshot = record(for: gameID)
        if !bypassExhaustionCheck && snapshot.totalRemaining(limit: freeLimit) > 0 {
            MonetizationLog.debug("Rejected pre-bank reward game=\(gameID)")
            return false
        }
        snapshot.rewardedAttemptsRemaining += count
        records[gameID] = snapshot
        persist()
        publish()
        MonetizationLog.debug("Granted +\(count) rewarded attempts game=\(gameID) bonus=\(snapshot.rewardedAttemptsRemaining)")
        return true
    }

    func canRequestRewardedGrant(for gameID: String) -> Bool {
        availability(for: gameID).canRequestRewardedAd
    }

    func refreshForCalendarChange() {
        _ = currentDayIdentifier()
        publish()
    }

    #if DEBUG
    func debugSetAttemptsExhausted(for gameID: String) {
        var snapshot = record(for: gameID)
        snapshot.freeAttemptsUsed = freeLimit
        snapshot.rewardedAttemptsRemaining = 0
        records[gameID] = snapshot
        persist()
        publish()
    }

    func debugGrantRewardedAttempts(for gameID: String) {
        _ = grantRewardedAttempts(rewardGrant, for: gameID, bypassExhaustionCheck: true)
    }

    func debugDumpState() -> String {
        let day = currentDayIdentifier()
        let lines = records.keys.sorted().map { id in
            let rec = record(for: id)
            return "\(id) day=\(rec.localDayIdentifier) freeUsed=\(rec.freeAttemptsUsed) bonus=\(rec.rewardedAttemptsRemaining)"
        }
        return "day=\(day) pro=\(entitlement.isPro)\n" + lines.joined(separator: "\n")
    }
    #endif

    func replaceCalendar(_ calendar: Calendar) {
        self.calendar = calendar
        publish()
    }

    private func persist() {
        store.save(records)
    }

    private func publish() {
        revision += 1
    }
}
