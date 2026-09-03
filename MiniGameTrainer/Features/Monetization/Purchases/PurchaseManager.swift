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
        let trusts = await client.currentEntitlements()
        let entitled = EntitlementEvaluator.entitledProductIDs(
            from: trusts,
            configuredProductIDs: configuredProductIDs
        )
        let next = EntitlementEvaluator.isPro(
            verifiedQualifyingProductIDs: entitled,
            configuredProductIDs: configuredProductIDs
        )
        if verifiedPro != next {
            MonetizationLog.debug("Pro entitlement changed to \(next)")
        }
        verifiedPro = next
        objectWillChange.send()
    }

    func purchase(_ product: StoreProduct) async {
        guard !isBusy else { return }
        actionState = .purchasing
        let outcome = await client.purchase(productID: product.id)
        await handle(outcome)
    }

    func restore() async {
        guard !isBusy else { return }
        actionState = .restoring
        do {
            try await client.sync()
            await refreshEntitlement()
            actionState = .restored
            MonetizationLog.debug("Restore completed isPro=\(isPro)")
        } catch {
            actionState = .failed(error.localizedDescription)
            MonetizationLog.debug("Restore failed")
        }
    }

    func clearActionMessage() {
        actionState = .idle
    }

    private func handle(_ outcome: PurchaseOutcome) async {
        switch outcome {
        case .verified:
            await refreshEntitlement()
            actionState = .idle
        case .unverified:
            actionState = .failed("Purchase could not be verified.")
        case .pending:
            actionState = .pending
        case .userCancelled:
            actionState = .cancelled
        case .failed(let message):
            actionState = .failed(message)
        }
    }

    private func listenForTransactionUpdates() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await trust in self.client.transactionUpdates() {
                if Task.isCancelled { break }
                MonetizationLog.debug("Transaction update \(trust)")
                await self.refreshEntitlement()
            }
        }
    }
}
