import SwiftUI

struct GameCardView: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let onPlay: () -> Void

    private var theme: GameVisualTheme { GamePresentationCatalog.theme(for: descriptor.id) }
    var formattedBestScore: String {
        descriptor.scorePresentation.formatted(statistics.bestScore)
    }
    var bestScoreLabel: String {
        statistics.gamesPlayed > 0 ? formattedBestScore : "No score yet"
    }
    private var tileScoreLabel: String {
        statistics.gamesPlayed > 0 ? formattedBestScore : "New"
    }

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    GameIconView(descriptor: descriptor, theme: theme, size: 48)
                    Spacer(minLength: AppTheme.Spacing.sm)
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.primary)
                        .frame(width: 30, height: 30)
                        .background(theme.primary.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(descriptor.name)
                        .font(AppTheme.Fonts.cardTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                    Text(descriptor.skills.prefix(2).joined(separator: " · "))
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                    Text(statistics.gamesPlayed > 0 ? "BEST" : "READY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(tileScoreLabel)
                        .font(AppTheme.Fonts.caption.monospacedDigit())
                        .foregroundStyle(statistics.gamesPlayed > 0 ? theme.primary : AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)
            .background {
                ZStack {
                    AppTheme.Colors.surface
                    LinearGradient(
                        colors: [theme.primary.opacity(0.11), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .strokeBorder(theme.primary.opacity(0.20), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
        }
        .buttonStyle(ShellPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens instructions and the Play button")
        .accessibilityIdentifier("gameCard.\(descriptor.id)")
    }

    private var accessibilityLabel: String {
        let best = statistics.gamesPlayed > 0 ? "Personal best \(formattedBestScore)." : "No score yet."
        return "\(descriptor.name). \(descriptor.skills.prefix(2).joined(separator: ", ")). \(best)"
    }
}

struct ContinueGameCard: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let hasHistory: Bool
    let onPlay: () -> Void

    private var theme: GameVisualTheme { GamePresentationCatalog.theme(for: descriptor.id) }

    var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .leading) {
                GameMotifBackground(theme: theme)

                HStack(spacing: AppTheme.Spacing.lg) {
                    GameIconView(descriptor: descriptor, theme: theme, size: 62)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(hasHistory ? "CONTINUE TRAINING" : "A GREAT PLACE TO START")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.7)
                            .foregroundStyle(theme.primary)
                        Text(descriptor.name)
                            .font(AppTheme.Fonts.heading)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        Text(descriptor.skills.prefix(2).joined(separator: " · "))
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text(bestText)
                            .font(AppTheme.Fonts.secondary.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    Spacer(minLength: AppTheme.Spacing.sm)
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.background)
                        .frame(width: 44, height: 44)
                        .background(theme.primary, in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(AppTheme.Spacing.lg)
            }
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous)
                    .strokeBorder(theme.primary.opacity(0.32), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
        }
        .buttonStyle(ShellPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hasHistory ? "Continue" : "Start training") with \(descriptor.name). \(bestText).")
        .accessibilityHint("Opens instructions and the Play button")
        .accessibilityIdentifier("continueGameCard")
    }

    private var bestText: String {
        guard statistics.gamesPlayed > 0 else { return "Set your first best" }
        return "Best \(descriptor.scorePresentation.formatted(statistics.bestScore))"
    }
}
