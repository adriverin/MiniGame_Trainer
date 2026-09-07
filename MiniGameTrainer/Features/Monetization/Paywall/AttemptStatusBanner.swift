import SwiftUI

enum AttemptStatusPresentation {
    static func label(for availability: AttemptAvailability, freeLimit: Int) -> String {
        switch availability {
        case .proUnlimited: return "Unlimited"
        case .free(let remaining): return "\(remaining) / \(freeLimit) attempts"
        case .rewarded(let remaining): return "\(remaining) bonus \(remaining == 1 ? "attempt" : "attempts")"
        case .exhausted: return "No free attempts"
        }
    }
}

/// Compact attempt context inside the shared intro hierarchy.
struct AttemptStatusBanner: View {
    let gameID: String

    @EnvironmentObject private var attempts: AttemptManager
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        let _ = attempts.revision
        Label(label, systemImage: purchases.isPro ? "infinity" : "circle.dotted")
            .font(AppTheme.Fonts.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .monospacedDigit()
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 36)
            .background(AppTheme.Colors.surface, in: Capsule())
            .fixedSize()
            .accessibilityLabel("Attempt status: \(label)")
    }

    private var label: String {
        AttemptStatusPresentation.label(for: attempts.availability(for: gameID), freeLimit: attempts.freeLimit)
    }
}
