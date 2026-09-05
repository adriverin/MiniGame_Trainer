import SwiftUI

struct GameCardView: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let onPlay: () -> Void

    var formattedBestScore: String {
        descriptor.scorePresentation.formatted(statistics.bestScore)
    }

    var bestScoreLabel: String {
        statistics.gamesPlayed > 0 ? formattedBestScore : "No score yet"
    }

    var body: some View {
        Button(action: onPlay) {
            CardContainer {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        Image(systemName: descriptor.iconName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 48, height: 48)
                            .background(AppTheme.Colors.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(descriptor.name)
                                .font(AppTheme.Fonts.cardTitle)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(descriptor.skills.joined(separator: " · "))
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            bestScore
                            Spacer(minLength: AppTheme.Spacing.md)
                            playLabel.fixedSize()
                        }
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            bestScore
                            playLabel
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(ShellPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(descriptor.name). \(descriptor.subtitle). \(statistics.gamesPlayed > 0 ? "Personal best " : "")\(bestScoreLabel).")
        .accessibilityHint("Opens instructions and the Play button")
        .accessibilityIdentifier("gameCard.\(descriptor.id)")
    }

    private var bestScore: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            if statistics.gamesPlayed > 0 {
                Text("Personal Best")
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Text(bestScoreLabel)
                .font(statistics.gamesPlayed > 0 ? AppTheme.Fonts.numeric : AppTheme.Fonts.secondary)
                .foregroundStyle(statistics.gamesPlayed > 0 ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playLabel: some View {
        Label("Play", systemImage: "arrow.up.right")
            .font(AppTheme.Fonts.button)
            .foregroundStyle(AppTheme.Colors.accent)
    }
}
