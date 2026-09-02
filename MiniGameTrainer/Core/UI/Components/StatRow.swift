import SwiftUI

/// Label / value line used on results and intro screens.
struct StatRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Fonts.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Fonts.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(highlight ? AppTheme.Colors.success : AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Rounded dark card container.
struct CardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(AppTheme.Metrics.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            }
    }
}

/// Full-screen background used by all shell screens.
struct ScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.Colors.background, AppTheme.Colors.background.opacity(0.85), Color(red: 0.05, green: 0.02, blue: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
