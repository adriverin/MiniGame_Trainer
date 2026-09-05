import SwiftUI

/// Shared results screen for every minigame.
struct ResultsView: View {
    let result: GameResult

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 76

    private var descriptor: MiniGameDescriptor? {
        GameRegistry.descriptor(for: result.gameID)
    }

    private var stats: GameStatistics {
        statistics.statistics(for: result.gameID)
    }

    private var isNewBest: Bool {
        stats.gamesPlayed > 1
            && result.score == stats.bestScore
            && result.scorePresentation.comparison.isBetter(result.score, than: stats.previousBestScore)
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Text(descriptor?.name ?? result.gameID)
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, 12)

                    scoreBlock

                    CardContainer {
                        VStack(spacing: 2) {
                            StatRow(label: "Personal Best", value: result.scorePresentation.formatted(stats.bestScore), highlight: isNewBest)
                            Divider().overlay(AppTheme.Colors.divider)
                            StatRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                            StatRow(label: "Average Score", value: result.scorePresentation.formattedAverage(stats.averageScore))
                            if let best = stats.bestReactionTime {
                                StatRow(label: "Best Reaction", value: MetricFormatter.milliseconds(best))
                            }
                        }
                    }

                    if !result.metrics.isEmpty {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This Session")
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .padding(.bottom, 6)
                                ForEach(result.metrics) { metric in
                                    StatRow(label: metric.label, value: metric.value)
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
            VStack(spacing: 12) {
                PrimaryButton(title: "Try Again", systemImage: "arrow.counterclockwise") {
                    router.retry(gameID: result.gameID)
                }
                PrimaryButton(title: "Library", systemImage: "square.grid.2x2", style: .outlined) {
                    router.goHome()
                }
            }
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: AppTheme.Metrics.contentWidth)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.background)
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.25)) { appeared = true }
            }
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 6) {
            Text(result.scorePresentation.label)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(result.scorePresentation.formatted(result.score))
                .font(AppTheme.Fonts.display(scoreSize).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scaleEffect(appeared ? 1 : 0.96)
                .opacity(appeared ? 1 : 0)
            if isNewBest {
                StatusBadge(title: "New Personal Best", systemImage: "trophy.fill", color: AppTheme.Colors.success)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
