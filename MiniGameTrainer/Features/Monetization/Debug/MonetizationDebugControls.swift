import SwiftUI

#if DEBUG
struct MonetizationDebugSection: View {
    @EnvironmentObject private var attempts: AttemptManager
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var consent: ConsentManager
    @State private var selectedGameID = GameRegistry.descriptors.first?.id ?? "piano"

    var body: some View {
        let _ = attempts.revision
        Section("Monetization Debug") {
            Picker("Game", selection: $selectedGameID) {
                ForEach(GameRegistry.descriptors) { descriptor in
                    Text(descriptor.name).tag(descriptor.id)
                }
            }
            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Button("Force Free") {
                purchases.debugOverride = .forceFree
            }
            Button("Simulate Pro") {
                purchases.debugOverride = .forcePro
            }
            Button("Clear entitlement override") {
                purchases.debugOverride = .none
            }
            Button("Set attempts 0") {
                attempts.debugSetAttemptsExhausted(for: selectedGameID)
            }
            Button("Grant +3 without ad") {
                attempts.debugGrantRewardedAttempts(for: selectedGameID)
            }
            Button("Use real local day") {
                attempts.debugDayIdentifierOverride = nil
                attempts.refreshForCalendarChange()
            }
            Button("Reset UMP consent") {
                consent.resetConsentForTesting()
            }
        }
    }

    private var statusLine: String {
        let availability = attempts.availability(for: selectedGameID)
        let record = attempts.record(for: selectedGameID)
        return "override=\(overrideLabel) availability=\(availabilityLabel(availability)) freeUsed=\(record.freeAttemptsUsed) bonus=\(record.rewardedAttemptsRemaining) day=\(record.localDayIdentifier)"
    }

    private var overrideLabel: String {
        switch purchases.debugOverride {
        case .none: return "none"
        case .forcePro: return "pro"
        case .forceFree: return "free"
        }
    }

    private func availabilityLabel(_ availability: AttemptAvailability) -> String {
        switch availability {
        case .proUnlimited: return "unlimited"
        case .free(let remaining): return "free(\(remaining))"
        case .rewarded(let remaining): return "bonus(\(remaining))"
        case .exhausted: return "exhausted"
        }
    }
}
#endif
