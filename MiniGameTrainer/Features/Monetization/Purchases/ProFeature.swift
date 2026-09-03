import Foundation

/// Capability checks for current and future Pro benefits.
/// Only features that already exist in the app should be consulted today.
enum ProFeature: String, CaseIterable, Equatable {
    case unlimitedAttempts
    case noRewardedAds
}

@MainActor
protocol ProEntitlementStatus: AnyObject {
    var isPro: Bool { get }
    func isEnabled(_ feature: ProFeature) -> Bool
}

extension ProEntitlementStatus {
    func isEnabled(_ feature: ProFeature) -> Bool {
        switch feature {
        case .unlimitedAttempts, .noRewardedAds:
            return isPro
        }
    }
}

final class StubEntitlement: ProEntitlementStatus {
    var isPro: Bool

    init(isPro: Bool) {
        self.isPro = isPro
    }
}
