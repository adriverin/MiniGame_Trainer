import XCTest
@testable import MiniGameTrainer

@MainActor
final class EntitlementEvaluatorTests: XCTestCase {
    private let configured = MonetizationConfiguration.proProductIDs

    func testVerifiedQualifyingEntitlementIsPro() {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: [.verified(productID: MonetizationConfiguration.monthlyProductID)],
            configuredProductIDs: configured
        )
        XCTAssertTrue(EntitlementEvaluator.isPro(verifiedQualifyingProductIDs: entitled, configuredProductIDs: configured))
    }

    func testUnverifiedTransactionIsNotPro() {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: [.unverified(productID: MonetizationConfiguration.yearlyProductID)],
            configuredProductIDs: configured
        )
        XCTAssertTrue(entitled.isEmpty)
        XCTAssertFalse(EntitlementEvaluator.isPro(verifiedQualifyingProductIDs: entitled, configuredProductIDs: configured))
    }

    func testExpiredOrNonCurrentEntitlementIsNotPro() {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: [],
            configuredProductIDs: configured
        )
        XCTAssertFalse(EntitlementEvaluator.isPro(verifiedQualifyingProductIDs: entitled, configuredProductIDs: configured))
    }

    func testInactiveTransactionIsNotPro() {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: [.inactive(productID: MonetizationConfiguration.monthlyProductID)],
            configuredProductIDs: configured
        )
        XCTAssertTrue(entitled.isEmpty)
        XCTAssertFalse(EntitlementEvaluator.isPro(verifiedQualifyingProductIDs: entitled, configuredProductIDs: configured))
    }

    func testCanonicalProductIDsMatchStoreKitConfiguration() {
        XCTAssertEqual(MonetizationConfiguration.monthlyProductID, "com.gamewe.minigametrainer.pro.monthly")
        XCTAssertEqual(MonetizationConfiguration.yearlyProductID, "com.gamewe.minigametrainer.pro.yearly")
        XCTAssertFalse(MonetizationConfiguration.monthlyProductID.contains(" "))
        XCTAssertFalse(MonetizationConfiguration.yearlyProductID.contains(" "))
        XCTAssertEqual(
            MonetizationConfiguration.proProductIDs,
            [
                "com.gamewe.minigametrainer.pro.monthly",
                "com.gamewe.minigametrainer.pro.yearly"
            ]
        )
        XCTAssertEqual(MonetizationConfiguration.currentBundleID, "com.gamewe.minigametrainer")
    }

    func testEitherMonthlyOrAnnualGrantsPro() {
        XCTAssertTrue(
            EntitlementEvaluator.isPro(
                verifiedQualifyingProductIDs: [MonetizationConfiguration.monthlyProductID],
                configuredProductIDs: configured
            )
        )
        XCTAssertTrue(
            EntitlementEvaluator.isPro(
                verifiedQualifyingProductIDs: [MonetizationConfiguration.yearlyProductID],
                configuredProductIDs: configured
            )
        )
        XCTAssertTrue(
            EntitlementEvaluator.isPro(
                verifiedQualifyingProductIDs: MonetizationConfiguration.proProductIDs,
                configuredProductIDs: configured
            )
        )
    }

    func testUnrelatedVerifiedProductIsNotPro() {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: [.verified(productID: "com.other.app.pro")],
            configuredProductIDs: configured
        )
        XCTAssertFalse(EntitlementEvaluator.isPro(verifiedQualifyingProductIDs: entitled, configuredProductIDs: configured))
    }
}

@MainActor
final class MockStoreKitClient: StoreKitClient {
    var entitlements: [TransactionTrust]
    var products: [StoreProduct]
    var purchaseOutcome: PurchaseOutcome
    var syncShouldFail = false
    var finishCount = 0
    var finishHandler: (() -> Void)?
    private var updateContinuation: AsyncStream<TransactionTrust>.Continuation?

    init(
        entitlements: [TransactionTrust] = [],
        products: [StoreProduct] = [
            StoreProduct(id: MonetizationConfiguration.yearlyProductID, displayName: "Annual Pro", displayPrice: "$24.99", price: 24.99, isYearly: true),
            StoreProduct(id: MonetizationConfiguration.monthlyProductID, displayName: "Monthly Pro", displayPrice: "$3.99", price: 3.99, isYearly: false)
        ],
        purchaseOutcome: PurchaseOutcome = .userCancelled
    ) {
        self.entitlements = entitlements
        self.products = products
        self.purchaseOutcome = purchaseOutcome
    }

    func currentEntitlements() async -> [TransactionTrust] { entitlements }

    func loadProducts(ids: [String]) async throws -> [StoreProduct] {
        products.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async -> PurchaseOutcome { purchaseOutcome }

    func sync() async throws {
        if syncShouldFail {
            throw NSError(domain: "MockStoreKit", code: 1)
        }
    }

    func transactionUpdates() -> AsyncStream<TransactionTrust> {
        AsyncStream { continuation in
            self.updateContinuation = continuation
        }
    }

    func finishDeliveredTransactions() async {
        finishCount += 1
        finishHandler?()
    }

    func emit(_ trust: TransactionTrust) {
        updateContinuation?.yield(trust)
    }
}

@MainActor
final class PurchaseManagerTests: XCTestCase {
    func testVerifiedPurchaseUnlocksProImmediatelyWithoutCurrentEntitlementsOrUpdates() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: MonetizationConfiguration.monthlyProductID)
        )
        let manager = PurchaseManager(client: client)
        await manager.refreshEntitlement()
        XCTAssertFalse(manager.isPro)
        XCTAssertFalse(manager.verifiedPro)

        var isProWhenFinished = false
        client.finishHandler = { isProWhenFinished = manager.isPro }

        await manager.loadProducts()
        await manager.purchase(manager.monthlyProduct!)

        XCTAssertTrue(manager.isPro, "Verified monthly purchase must unlock Pro without Transaction.updates or currentEntitlements")
        XCTAssertTrue(manager.verifiedPro)
        XCTAssertTrue(client.entitlements.isEmpty, "Regression: unlock must not require seeding currentEntitlements")
        XCTAssertTrue(isProWhenFinished, "Entitlement must be delivered before the transaction is finished")
        XCTAssertEqual(client.finishCount, 1)
    }

    func testVerifiedAnnualPurchaseUnlocksProImmediately() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: MonetizationConfiguration.yearlyProductID)
        )
        let manager = PurchaseManager(client: client)
        await manager.loadProducts()
        await manager.purchase(manager.yearlyProduct!)
        XCTAssertTrue(manager.isPro)
        XCTAssertTrue(manager.verifiedPro)
    }

    func testUnverifiedPurchaseDoesNotUnlockPro() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .unverified(productID: MonetizationConfiguration.yearlyProductID)
        )
        let manager = PurchaseManager(client: client)
        await manager.loadProducts()
        await manager.purchase(manager.yearlyProduct!)
        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.actionState, .failed("Purchase could not be verified."))
    }

    func testVerifiedUnrelatedProductDoesNotUnlockPro() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: "com.other.app.pro")
        )
        let manager = PurchaseManager(client: client)
        await manager.loadProducts()
        await manager.purchase(manager.monthlyProduct!)
        XCTAssertFalse(manager.isPro)
        XCTAssertFalse(manager.verifiedPro)
    }

    func testExpiredEntitlementRefreshClearsProAfterPurchase() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: MonetizationConfiguration.monthlyProductID)
        )
        let manager = PurchaseManager(client: client)
        await manager.loadProducts()
        await manager.purchase(manager.monthlyProduct!)
        XCTAssertTrue(manager.isPro)

        client.entitlements = []
        await manager.refreshEntitlement()
        XCTAssertFalse(manager.isPro)
        XCTAssertFalse(manager.verifiedPro)
    }

    func testProductLoadFailureDoesNotClearExistingPro() async {
        let client = MockStoreKitClient(
            entitlements: [.verified(productID: MonetizationConfiguration.yearlyProductID)],
            products: []
        )
        let manager = PurchaseManager(client: client)
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.isPro)
        await manager.loadProducts()
        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(manager.catalogState, .failed("Subscriptions are unavailable right now."))
    }

    func testRestoreWithoutCurrentEntitlementIsNotPro() async {
        let client = MockStoreKitClient(entitlements: [])
        let manager = PurchaseManager(client: client)
        await manager.restore()
        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.actionState, .restored)
    }

    func testRelaunchRefreshRestoresProFromCurrentEntitlements() async {
        let client = MockStoreKitClient(
            entitlements: [.verified(productID: MonetizationConfiguration.monthlyProductID)]
        )
        let manager = PurchaseManager(client: client)
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.isPro)
        XCTAssertTrue(manager.verifiedPro)
    }

    #if DEBUG
    func testDebugOverrideNeverTouchesVerifiedEntitlement() async {
        let client = MockStoreKitClient(entitlements: [])
        let manager = PurchaseManager(client: client)
        await manager.refreshEntitlement()
        manager.debugOverride = .forcePro
        XCTAssertTrue(manager.isPro)
        XCTAssertFalse(manager.verifiedPro)
        manager.debugOverride = .forceFree
        client.entitlements = [.verified(productID: MonetizationConfiguration.monthlyProductID)]
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.verifiedPro)
        XCTAssertFalse(manager.isPro)
    }
    #endif
}
