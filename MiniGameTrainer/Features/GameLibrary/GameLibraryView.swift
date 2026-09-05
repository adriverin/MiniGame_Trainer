import SwiftUI

/// Lists every registered game as a card. New games appear automatically once registered.
struct GameLibraryView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("\(GameRegistry.descriptors.count) games to master")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(GameRegistry.descriptors) { descriptor in
                GameCardView(
                    descriptor: descriptor,
                    statistics: statistics.statistics(for: descriptor.id),
                    onPlay: { router.showIntro(for: descriptor.id) }
                )
            }
        }
    }
}
