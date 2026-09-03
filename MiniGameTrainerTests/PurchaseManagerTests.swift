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

    func emit(_ trust: TransactionTrust) {
        updateContinuation?.yield(trust)
    }
}

@MainActor
final class PurchaseManagerTests: XCTestCase {
    func testVerifiedPurchaseUnlocksPro() async {
        let client = MockStoreKitClient(
            entitlements: [],
            purchaseOutcome: .verified(productID: MonetizationConfiguration.monthlyProductID)
        )
        let manager = PurchaseManager(client: client)
        await manager.refreshEntitlement()
        XCTAssertFalse(manager.verifiedPro)

        client.entitlements = [.verified(productID: MonetizationConfiguration.monthlyProductID)]
        if let monthly = manager.monthlyProduct {
            await manager.purchase(monthly)
        } else {
            await manager.loadProducts()
            await manager.purchase(manager.monthlyProduct!)
        }
        XCTAssertTrue(manager.isPro)
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
