import SwiftUI

/// Dedicated per-game statistics list. Presentation only; `StatisticsStore` is unchanged.
struct StatisticsView: View {
    @EnvironmentObject private var statistics: StatisticsStore

    var body: some View {
        Form {
            Section {
                ForEach(GameRegistry.descriptors) { descriptor in
                    let stats = statistics.statistics(for: descriptor.id)
                    LabeledContent(descriptor.name) {
                        Text(stats.gamesPlayed > 0
                             ? "\(descriptor.scorePresentation.formatted(stats.bestScore)) · \(stats.gamesPlayed) played"
                             : "No score yet")
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .font(AppTheme.Fonts.body)
        .tint(AppTheme.Colors.accent)
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
}
