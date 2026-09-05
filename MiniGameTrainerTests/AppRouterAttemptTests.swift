import XCTest
@testable import MiniGameTrainer

@MainActor
final class AppRouterAttemptTests: XCTestCase {
    private func makeRouter(isPro: Bool = false) -> (AppRouter, AttemptManager, UserDefaults) {
        let entitlement = StubEntitlement(isPro: isPro)
        let suite = "AppRouterAttemptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let attempts = AttemptManager(
            userDefaults: defaults,
            clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)),
            calendar: calendar,
            entitlement: entitlement
        )
        return (AppRouter(attemptManager: attempts), attempts, defaults)
    }

    func testRapidPlayStartsOnlyOneSessionAndConsumesOneAttempt() {
        let (router, attempts, _) = makeRouter()
        router.showIntro(for: "piano")
        router.startGame("piano")
        router.startGame("piano")
        XCTAssertEqual(router.path, [.gameIntro(gameID: "piano"), .game(gameID: "piano")])
        XCTAssertEqual(attempts.availability(for: "piano"), .free(remaining: 6))
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 1)
    }

    func testRetryConsumesAnotherAttempt() {
        let (router, attempts, _) = makeRouter()
        router.startGame("piano")
        let result = GameResult(gameID: "piano", score: 10, duration: 1)
        router.finishGame(with: result)
        router.retry(gameID: "piano")
        XCTAssertEqual(attempts.record(for: "piano").freeAttemptsUsed, 2)
        XCTAssertEqual(router.path.last, .game(gameID: "piano"))
    }

    func testExhaustedRetryShowsGateNotGame() {
        let (router, attempts, _) = makeRouter()
        for _ in 0..<7 {
            _ = attempts.consumeAttempt(for: "piano")
        }
        router.retry(gameID: "piano")
        XCTAssertEqual(router.path.last, .attemptGate(gameID: "piano"))
        XCTAssertEqual(attempts.availability(for: "piano"), .exhausted)
    }

    func testShowStatisticsPushesDedicatedRouteFromSettings() {
        let (router, _, _) = makeRouter()
        router.showSettings()
        router.showStatistics()
        XCTAssertEqual(router.path, [.settings, .statistics])
    }

    func testShowStatisticsDoesNotDuplicateTopRoute() {
        let (router, _, _) = makeRouter()
        router.showStatistics()
        router.showStatistics()
        XCTAssertEqual(router.path, [.statistics])
    }

    func testProStartsWithoutConsuming() {
        let (router, attempts, _) = makeRouter(isPro: true)
        router.startGame("bloopy")
        router.startGame("bloopy")
        XCTAssertEqual(router.path, [.game(gameID: "bloopy")])
        XCTAssertEqual(attempts.record(for: "bloopy").freeAttemptsUsed, 0)
    }

    func testVerifiedPurchaseUnlocksExhaustedGameOnSharedEntitlement() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: MonetizationConfiguration.monthlyProductID)
        )
        let suite = "AppRouterPurchaseUnlock-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let environment = AppEnvironment(
            userDefaults: defaults,
            clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)),
            calendar: calendar,
            storeKitClient: client
        )
        let router = AppRouter(attemptManager: environment.attemptManager)

        for _ in 0..<7 {
            XCTAssertTrue(environment.attemptManager.consumeAttempt(for: "piano"))
        }
        router.startGame("piano")
        XCTAssertEqual(router.path.last, .attemptGate(gameID: "piano"))
        XCTAssertEqual(environment.attemptManager.availability(for: "piano"), .exhausted)
        XCTAssertFalse(environment.purchaseManager.isPro)
        XCTAssertFalse(environment.attemptManager.isPro)

        await environment.purchaseManager.loadProducts()
        await environment.purchaseManager.purchase(environment.purchaseManager.monthlyProduct!)

        XCTAssertTrue(environment.purchaseManager.isPro)
        XCTAssertTrue(environment.attemptManager.isPro)
        XCTAssertEqual(environment.attemptManager.availability(for: "piano"), .proUnlimited)

        router.startGame("piano")
        XCTAssertEqual(router.path.last, .game(gameID: "piano"))
        XCTAssertEqual(environment.attemptManager.record(for: "piano").freeAttemptsUsed, 7)
        XCTAssertEqual(environment.attemptManager.availability(for: "piano"), .proUnlimited)

        defaults.removePersistentDomain(forName: suite)
    }
}
