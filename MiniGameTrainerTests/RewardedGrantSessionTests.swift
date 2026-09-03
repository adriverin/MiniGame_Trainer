import XCTest
@testable import MiniGameTrainer

@MainActor
final class RewardedGrantSessionTests: XCTestCase {
    func testNoRewardCallbackGrantsNothing() {
        let session = RewardedGrantSession()
        let token = session.begin(gameID: "bloopy")
        XCTAssertNotNil(token)
        session.end(token: token!)
        XCTAssertFalse(session.isPresenting)
    }

    func testSingleRewardCallbackReturnsGameIDOnce() {
        let session = RewardedGrantSession()
        let token = session.begin(gameID: "bloopy")!
        XCTAssertEqual(session.consumeReward(token: token), "bloopy")
        XCTAssertNil(session.consumeReward(token: token))
        session.end(token: token)
    }

    func testDuplicateCallbackStillExactlyOneGrant() {
        let session = RewardedGrantSession()
        let token = session.begin(gameID: "piano")!
        var grants = 0
        if session.consumeReward(token: token) != nil { grants += 1 }
        if session.consumeReward(token: token) != nil { grants += 1 }
        if session.consumeReward(token: token) != nil { grants += 1 }
        XCTAssertEqual(grants, 1)
    }

    func testCannotPresentTwoAdsAtOnce() {
        let session = RewardedGrantSession()
        XCTAssertNotNil(session.begin(gameID: "piano"))
        XCTAssertNil(session.begin(gameID: "bloopy"))
    }

    func testRewardBoundToCapturedGameID() {
        let session = RewardedGrantSession()
        let token = session.begin(gameID: "colorReflex")!
        XCTAssertEqual(session.consumeReward(token: token), "colorReflex")
        XCTAssertNotEqual(session.consumeReward(token: token), "piano")
    }
}

@MainActor
final class AttemptRewardIntegrationTests: XCTestCase {
    func testRewardCallbackGrantsThreeOnce() {
        let defaults = UserDefaults(suiteName: "AttemptRewardIntegrationTests")!
        defaults.removePersistentDomain(forName: "AttemptRewardIntegrationTests")
        let entitlement = StubEntitlement(isPro: false)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let attempts = AttemptManager(
            userDefaults: defaults,
            clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            calendar: calendar,
            entitlement: entitlement
        )
        for _ in 0..<7 { _ = attempts.consumeAttempt(for: "bloopy") }

        let session = RewardedGrantSession()
        XCTAssertEqual(attempts.record(for: "bloopy").rewardedAttemptsRemaining, 0)
        let token = session.begin(gameID: "bloopy")!
        XCTAssertNil(session.consumeReward(token: UUID()), "No grant without the live token")
        if let gameID = session.consumeReward(token: token) {
            _ = attempts.grantRewardedAttempts(3, for: gameID)
        }
        if let gameID = session.consumeReward(token: token) {
            _ = attempts.grantRewardedAttempts(3, for: gameID)
        }
        XCTAssertEqual(attempts.record(for: "bloopy").rewardedAttemptsRemaining, 3)
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 7))
        defaults.removePersistentDomain(forName: "AttemptRewardIntegrationTests")
    }
}
