import Foundation

/// StoreKit-facing business logic that can be unit-tested without Apple's cryptography.
enum TransactionTrust: Equatable, CustomStringConvertible {
    case verified(productID: String)
    case unverified(productID: String)
    /// Revoked or expired. Must not grant Pro, but still triggers an entitlement refresh.
    case inactive(productID: String)

    var description: String {
        switch self {
        case .verified(let productID):
            return "verified(\(productID))"
        case .unverified(let productID):
            return "unverified(\(productID))"
        case .inactive(let productID):
            return "inactive(\(productID))"
        }
    }
}

enum EntitlementEvaluator {
    static func entitledProductIDs(
        from transactions: [TransactionTrust],
        configuredProductIDs: Set<String>
    ) -> Set<String> {
        var entitled: Set<String> = []
        for transaction in transactions {
            switch transaction {
            case .verified(let productID) where configuredProductIDs.contains(productID):
                entitled.insert(productID)
            case .verified, .unverified, .inactive:
                continue
            }
        }
        return entitled
    }

    static func isPro(
        verifiedQualifyingProductIDs: Set<String>,
        configuredProductIDs: Set<String>
    ) -> Bool {
        !verifiedQualifyingProductIDs.isDisjoint(with: configuredProductIDs)
    }
}

enum PurchaseOutcome: Equatable {
    case verified(productID: String)
    case unverified(productID: String)
    case pending
    case userCancelled
    case failed(String)
}

struct StoreProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let price: Decimal
    let isYearly: Bool
}
