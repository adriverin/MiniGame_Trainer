import Foundation
import StoreKit

@MainActor
protocol StoreKitClient: AnyObject {
    func currentEntitlements() async -> [TransactionTrust]
    func loadProducts(ids: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async -> PurchaseOutcome
    func sync() async throws
    func transactionUpdates() -> AsyncStream<TransactionTrust>
}

/// Live StoreKit 2 client. Entitlement uses `Transaction.currentEntitlements` only.
@MainActor
final class LiveStoreKitClient: StoreKitClient {
    private var productsByID: [String: Product] = [:]

    func currentEntitlements() async -> [TransactionTrust] {
        var trusts: [TransactionTrust] = []
        for await result in Transaction.currentEntitlements {
            trusts.append(Self.trust(from: result))
        }
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
                    await transaction.finish()
                    return .verified(productID: transaction.productID)
                case .unverified(let transaction, _):
                    MonetizationLog.debug("Unverified purchase for \(transaction.productID)")
                    return .unverified(productID: transaction.productID)
                }
            case .userCancelled:
                return .userCancelled
            case .pending:
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
            let task = Task {
                for await result in Transaction.updates {
                    switch result {
                    case .verified(let transaction):
                        await transaction.finish()
                        continuation.yield(.verified(productID: transaction.productID))
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

    private static func trust(from result: VerificationResult<Transaction>) -> TransactionTrust {
        switch result {
        case .verified(let transaction):
            return .verified(productID: transaction.productID)
        case .unverified(let transaction, _):
            MonetizationLog.debug("Unverified current entitlement for \(transaction.productID)")
            return .unverified(productID: transaction.productID)
        }
    }
}
