import SwiftUI

struct LegalLinkButtons: View {
    var body: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: MonetizationConfiguration.termsOfUseURL)
            Text("·")
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Link("Privacy Policy", destination: MonetizationConfiguration.privacyPolicyURL)
        }
        .font(AppTheme.Fonts.caption)
        .foregroundStyle(AppTheme.Colors.accent)
    }
}
