import SwiftUI

struct GameCardView: View {
    let descriptor: MiniGameDescriptor
    let statistics: GameStatistics
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            CardContainer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: descriptor.iconName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 52, height: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.Colors.surfaceElevated)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(descriptor.name)
                                .font(AppTheme.Fonts.heading)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(descriptor.skills.joined(separator: " + "))
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }

                    Text(descriptor.subtitle)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best")
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            Text("\(statistics.bestScore)")
                                .font(AppTheme.Fonts.display(28).monospacedDigit())
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        if statistics.gamesPlayed > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Played")
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Text("\(statistics.gamesPlayed)")
                                    .font(AppTheme.Fonts.display(28).monospacedDigit())
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                            }
                            .padding(.leading, 24)
                        }
                        Spacer()
                        Text("PLAY")
                            .font(AppTheme.Fonts.button)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppTheme.Colors.textPrimary))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(descriptor.name). \(descriptor.subtitle). Best score \(statistics.bestScore).")
        .accessibilityHint("Opens the game")
        .accessibilityAddTraits(.isButton)
    }
}
