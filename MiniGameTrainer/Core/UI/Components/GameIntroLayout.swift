import SwiftUI

/// The illustrated intros share layout and score formatting, not game behavior.
struct GameIntroLayout<Preview: View>: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let playHint: String
    let onPlay: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    preview()
                        .frame(height: AppTheme.Metrics.previewHeight)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        Text(descriptor.name)
                            .font(AppTheme.Fonts.title)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(descriptor.instructions)
                            .font(AppTheme.Fonts.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    CardContainer {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            StatRow(label: "Personal Best", value: statistics.gamesPlayed > 0
                                    ? descriptor.scorePresentation.formatted(statistics.bestScore) : "No score yet")
                            Text(descriptor.scorePresentation.comparison == .lowerIsBetter ? "Lower is better" : "Higher is better")
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.accent)
                            if statistics.gamesPlayed > 0 {
                                Divider().overlay(AppTheme.Colors.divider).padding(.vertical, AppTheme.Spacing.sm)
                                StatRow(label: "Games Played", value: "\(statistics.gamesPlayed)")
                                StatRow(label: "Average", value: descriptor.scorePresentation.formattedAverage(statistics.averageScore))
                                if let reaction = statistics.bestReactionTime {
                                    StatRow(label: "Best Reaction", value: MetricFormatter.milliseconds(reaction))
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.Metrics.screenPadding)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Play", systemImage: "play.fill", action: onPlay)
                .accessibilityHint(playHint)
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, AppTheme.Spacing.md)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.background)
        }
    }
}
