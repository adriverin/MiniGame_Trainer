import SwiftUI

/// Long labels move above their value instead of squeezing the score.
struct StatRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.lg) {
                labelText.fixedSize()
                Spacer(minLength: AppTheme.Spacing.sm)
                valueText.fixedSize()
            }
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                labelText
                valueText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label).font(AppTheme.Fonts.secondary).foregroundStyle(AppTheme.Colors.textSecondary)
    }

    private var valueText: some View {
        Text(value)
            .font(AppTheme.Fonts.body.weight(.semibold).monospacedDigit())
            .foregroundStyle(highlight ? AppTheme.Colors.success : AppTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(AppTheme.Metrics.cardPadding)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

/// Opaque and identical to LaunchBackground to avoid a launch-to-shell color flash.
struct ScreenBackground: View {
    var body: some View {
        AppTheme.Colors.background.ignoresSafeArea()
    }
}

struct StatusBadge: View {
    let title: String
    var systemImage: String = "star.fill"
    var color: Color = AppTheme.Colors.accent

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Fonts.caption)
            .foregroundStyle(color)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
