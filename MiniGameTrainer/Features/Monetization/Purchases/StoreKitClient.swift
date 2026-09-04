import Foundation
import StoreKit

@MainActor
protocol StoreKitClient: AnyObject {
    func currentEntitlements() async -> [TransactionTrust]
    func loadProducts(ids: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async -> PurchaseOutcome
    func sync() async throws
    func transactionUpdates() -> AsyncStream<TransactionTrust>
    /// Finish transactions only after the app has applied entitlement.
    func finishDeliveredTransactions() async
}

/// Live StoreKit 2 client. Launch/restore entitlement uses `Transaction.currentEntitlements`.
/// Direct purchases also unlock from `Product.PurchaseResult.success` before finish.
@MainActor
final class LiveStoreKitClient: StoreKitClient {
    private var productsByID: [String: Product] = [:]
    private var unfinishedDelivered: [UInt64: Transaction] = [:]

    func currentEntitlements() async -> [TransactionTrust] {
        var trusts: [TransactionTrust] = []
        for await result in Transaction.currentEntitlements {
            let trust = Self.trust(from: result)
            MonetizationLog.debug("currentEntitlement \(trust)")
            trusts.append(trust)
        }
        MonetizationLog.debug("currentEntitlements count=\(trusts.count)")
        return trusts
    }

    func loadProducts(ids: [String]) async throws -> [StoreProduct] {
        let products = try await Product.products(for: Set(ids))
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return products.map { product in
            StoreProduct(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                price: product.price,
                isYearly: product.id == MonetizationConfiguration.yearlyProductID
            )
        }
        .sorted { lhs, rhs in
            if lhs.isYearly != rhs.isYearly { return lhs.isYearly && !rhs.isYearly }
            return lhs.id < rhs.id
        }
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        do {
            let product: Product
            if let cached = productsByID[productID] {
                product = cached
            } else {
                let loaded = try await Product.products(for: [productID])
                guard let first = loaded.first else {
                    return .failed("This subscription is unavailable right now.")
                }
                productsByID[productID] = first
                product = first
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    MonetizationLog.debug("Purchase result verified productID=\(transaction.productID)")
                    guard Self.isCurrentlyEntitled(transaction) else {
                        MonetizationLog.debug("Purchase transaction not currently entitled productID=\(transaction.productID)")
                        await transaction.finish()
                        return .failed("Purchase could not be verified.")
                    }
                    enqueueUnfinished(transaction)
                    return .verified(productID: transaction.productID)
                case .unverified(let transaction, _):
                    MonetizationLog.debug("Unverified purchase for \(transaction.productID)")
                    return .unverified(productID: transaction.productID)
                }
            case .userCancelled:
                MonetizationLog.debug("Purchase cancelled productID=\(productID)")
                return .userCancelled
            case .pending:
                MonetizationLog.debug("Purchase pending productID=\(productID)")
                return .pending
            @unknown default:
                return .failed("Purchase could not be completed.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func transactionUpdates() -> AsyncStream<TransactionTrust> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                for await result in Transaction.updates {
                    switch result {
                    case .verified(let transaction):
                        enqueueUnfinished(transaction)
                        let trust = Self.trust(from: result)
                        MonetizationLog.debug("Transaction.updates \(trust)")
                        continuation.yield(trust)
                    case .unverified(let transaction, _):
                        MonetizationLog.debug("Unverified transaction update for \(transaction.productID)")
                        continuation.yield(.unverified(productID: transaction.productID))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func finishDeliveredTransactions() async {
        let pending = unfinishedDelivered
        unfinishedDelivered.removeAll()
        for transaction in pending.values {
            await transaction.finish()
            MonetizationLog.debug("Finished transaction productID=\(transaction.productID)")
        }
    }

    private func enqueueUnfinished(_ transaction: Transaction) {
        unfinishedDelivered[transaction.id] = transaction
    }

    private static func trust(from result: VerificationResult<Transaction>) -> TransactionTrust {
        switch result {
        case .verified(let transaction):
            if isCurrentlyEntitled(transaction) {
                return .verified(productID: transaction.productID)
            }
            MonetizationLog.debug("Inactive entitlement productID=\(transaction.productID)")
            return .inactive(productID: transaction.productID)
        case .unverified(let transaction, _):
            MonetizationLog.debug("Unverified current entitlement for \(transaction.productID)")
            return .unverified(productID: transaction.productID)
        }
    }

    private static func isCurrentlyEntitled(_ transaction: Transaction) -> Bool {
        if transaction.revocationDate != nil {
            return false
        }
        if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
            return false
        }
        return true
    }
}
