import SwiftUI

/// All games share this hierarchy; their existing previews remain lightweight visual flavor.
struct GameIntroLayout<Preview: View>: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let playHint: String
    let onPlay: () -> Void
    @ViewBuilder let preview: () -> Preview

    private var theme: GameVisualTheme { GamePresentationCatalog.theme(for: descriptor.id) }
    private var presentation: GamePresentation { GamePresentationCatalog.presentation(for: descriptor) }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    hero
                    identity
                    AttemptStatusBanner(gameID: descriptor.id)
                    howToPlay
                    personalBest
                }
                .padding(AppTheme.Metrics.screenPadding)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Play", systemImage: "play.fill", tint: theme.primary, action: onPlay)
                .accessibilityHint(playHint)
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, AppTheme.Spacing.md)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        ZStack {
            AppTheme.Colors.surface
            GameMotifBackground(theme: theme)
            preview()
                .opacity(0.88)
                .padding(10)
        }
        .frame(height: AppTheme.Metrics.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.30), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                GameIconView(descriptor: descriptor, theme: theme, size: 48)
                Text(descriptor.name)
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(presentation.primaryRule)
                .font(AppTheme.Fonts.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(descriptor.skills.prefix(2).joined(separator: "  ·  "))
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(theme.primary)
        }
    }

    private var howToPlay: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("How to Play")
                .font(AppTheme.Fonts.heading)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            CardContainer {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(presentation.instructions.enumerated()), id: \.element.id) { index, instruction in
                        instructionRow(instruction)
                        if index < presentation.instructions.count - 1 {
                            Divider().overlay(AppTheme.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private func instructionRow(_ instruction: GameInstruction) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: instruction.systemImage)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(theme.primary)
                .frame(width: 34, height: 34)
                .background(theme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(instruction.title)
                    .font(AppTheme.Fonts.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(instruction.detail)
                    .font(AppTheme.Fonts.secondary)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var personalBest: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("PERSONAL BEST")
                    .font(.caption2.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(bestValue)
                    .font(AppTheme.Fonts.numeric)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Spacer()
            Label(comparisonLabel, systemImage: comparisonImage)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(theme.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(theme.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Personal best. \(bestValue). \(comparisonLabel).")
    }

    private var bestValue: String {
        statistics.gamesPlayed > 0
            ? descriptor.scorePresentation.formatted(statistics.bestScore)
            : "Set your first best"
    }

    private var comparisonLabel: String {
        descriptor.scorePresentation.comparison == .lowerIsBetter ? "Lower is better" : "Higher is better"
    }

    private var comparisonImage: String {
        descriptor.scorePresentation.comparison == .lowerIsBetter ? "arrow.down.right" : "arrow.up.right"
    }
}
