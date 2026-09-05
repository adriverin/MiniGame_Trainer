import SwiftUI

/// Unobtrusive remaining-attempt label shown above every game intro.
struct AttemptStatusBanner: View {
    let gameID: String

    @EnvironmentObject private var attempts: AttemptManager
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        let _ = attempts.revision
        if purchases.isPro {
            EmptyView()
        } else {
            Label(label, systemImage: "circle.dotted")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .monospacedDigit()
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.surface, in: Capsule())
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.background)
                .accessibilityLabel(label)
        }
    }

    private var label: String {
        switch attempts.availability(for: gameID) {
        case .proUnlimited:
            return ""
        case .free(let remaining):
            return "\(remaining) / \(attempts.freeLimit) free attempts remaining"
        case .rewarded(let remaining):
            let noun = remaining == 1 ? "attempt" : "attempts"
            return "\(remaining) bonus \(noun) remaining"
        case .exhausted:
            return "Free attempts used"
        }
    }
}
