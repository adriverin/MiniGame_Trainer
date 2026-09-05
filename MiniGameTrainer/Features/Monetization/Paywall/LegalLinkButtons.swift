import SwiftUI

struct LegalLinkButtons: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.Spacing.lg) { links }
            VStack(spacing: AppTheme.Spacing.xs) { links }
        }
        .font(AppTheme.Fonts.caption)
        .foregroundStyle(AppTheme.Colors.accent)
    }

    private var links: some View {
        Group {
            Link("Terms of Use", destination: MonetizationConfiguration.termsOfUseURL)
                .frame(minHeight: 44)
            Link("Privacy Policy", destination: MonetizationConfiguration.privacyPolicyURL)
                .frame(minHeight: 44)
        }
    }
}
