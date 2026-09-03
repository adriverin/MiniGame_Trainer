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
            Text(label)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
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
