import Foundation
import Combine

@MainActor
final class PurchaseManager: ObservableObject, ProEntitlementStatus {
    enum CatalogState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum ActionState: Equatable {
        case idle
        case purchasing
        case pending
        case failed(String)
        case cancelled
        case restoring
        case restored
    }

    @Published private(set) var verifiedPro = false
    @Published private(set) var products: [StoreProduct] = []
    @Published private(set) var catalogState: CatalogState = .idle
    @Published private(set) var actionState: ActionState = .idle

    #if DEBUG
    enum DebugOverride: Equatable {
        case none
        case forcePro
        case forceFree
    }

    @Published var debugOverride: DebugOverride = .none
    #endif

    private let client: StoreKitClient
    private let configuredProductIDs: Set<String>
    private var updatesTask: Task<Void, Never>?
    /// Invalidates in-flight entitlement refreshes so a lagging `currentEntitlements`
    /// query cannot overwrite a just-applied verified purchase.
    private var entitlementEpoch = 0

    var isPro: Bool {
        #if DEBUG
        switch debugOverride {
        case .forcePro:
            return true
        case .forceFree:
            return false
        case .none:
            break
        }
        #endif
        return verifiedPro
    }

    var isBusy: Bool {
        switch actionState {
        case .purchasing, .restoring:
            return true
        default:
            return false
        }
    }

    var monthlyProduct: StoreProduct? {
        products.first { $0.id == MonetizationConfiguration.monthlyProductID }
    }

    var yearlyProduct: StoreProduct? {
        products.first { $0.id == MonetizationConfiguration.yearlyProductID }
    }

    init(
        client: StoreKitClient? = nil,
        configuredProductIDs: Set<String> = MonetizationConfiguration.proProductIDs
    ) {
        self.client = client ?? LiveStoreKitClient()
        self.configuredProductIDs = configuredProductIDs
    }

    func start() {
        guard updatesTask == nil else { return }
        MonetizationLog.debug(
            "PurchaseManager start instance=\(ObjectIdentifier(self)) products=\(configuredProductIDs.sorted())"
        )
        listenForTransactionUpdates()
        Task { await refreshEntitlement() }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        catalogState = .loading
        do {
            let loaded = try await client.loadProducts(ids: Array(configuredProductIDs))
            products = loaded
            catalogState = loaded.isEmpty ? .failed("Subscriptions are unavailable right now.") : .loaded
            MonetizationLog.debug("Loaded \(loaded.count) StoreKit products")
        } catch {
            products = []
            catalogState = .failed("Subscriptions are unavailable right now.")
            MonetizationLog.debug("Product load failed: \(error.localizedDescription)")
        }
    }

    func refreshEntitlement() async {
        await refreshEntitlement(including: [])
    }

    func restore() async {
        guard !isBusy else { return }
        actionState = .restoring
        do {
            entitlementEpoch += 1
            try await client.sync()
            await refreshEntitlement()
            actionState = .restored
            MonetizationLog.debug("Restore completed isPro=\(isPro)")
        } catch {
            actionState = .failed(error.localizedDescription)
            MonetizationLog.debug("Restore failed")
        }
    }

    func purchase(_ product: StoreProduct) async {
        guard !isBusy else { return }
        actionState = .purchasing
        MonetizationLog.debug("Purchase begin productID=\(product.id) isPro=\(isPro)")
        let outcome = await client.purchase(productID: product.id)
        await handle(outcome)
    }

    func clearActionMessage() {
        actionState = .idle
    }

    private func handle(_ outcome: PurchaseOutcome) async {
        switch outcome {
        case .verified(let productID):
            MonetizationLog.debug("Purchase verified productID=\(productID)")
            entitlementEpoch += 1
            applyEntitlement(from: [.verified(productID: productID)])
            await refreshEntitlement(including: [.verified(productID: productID)])
            await client.finishDeliveredTransactions()
            actionState = .idle
            MonetizationLog.debug("Purchase complete isPro=\(isPro) verifiedPro=\(verifiedPro)")
        case .unverified(let productID):
            MonetizationLog.debug("Purchase unverified productID=\(productID)")
            actionState = .failed("Purchase could not be verified.")
        case .pending:
            actionState = .pending
        case .userCancelled:
            actionState = .cancelled
        case .failed(let message):
            await client.finishDeliveredTransactions()
            actionState = .failed(message)
        }
    }

    private func refreshEntitlement(including extra: [TransactionTrust]) async {
        let epoch = entitlementEpoch
        let fromStore = await client.currentEntitlements()
        guard epoch == entitlementEpoch else {
            MonetizationLog.debug("Skipped stale entitlement refresh epoch=\(epoch) current=\(entitlementEpoch)")
            return
        }
        applyEntitlement(from: fromStore + extra)
    }

    private func applyEntitlement(from trusts: [TransactionTrust]) {
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: trusts,
            configuredProductIDs: configuredProductIDs
        )
        let next = EntitlementEvaluator.isPro(
            verifiedQualifyingProductIDs: entitled,
            configuredProductIDs: configuredProductIDs
        )
        MonetizationLog.debug(
            "Entitlement entitled=\(entitled.sorted()) isPro=\(next) instance=\(ObjectIdentifier(self))"
        )
        if verifiedPro != next {
            MonetizationLog.debug("Pro entitlement changed to \(next)")
        }
        verifiedPro = next
        objectWillChange.send()
    }

    private func listenForTransactionUpdates() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await trust in self.client.transactionUpdates() {
                if Task.isCancelled { break }
                MonetizationLog.debug("Transaction update \(trust)")
                self.entitlementEpoch += 1
                switch trust {
                case .verified(let productID):
                    await self.refreshEntitlement(including: [.verified(productID: productID)])
                case .unverified, .inactive:
                    await self.refreshEntitlement()
                }
                await self.client.finishDeliveredTransactions()
            }
        }
    }
}
