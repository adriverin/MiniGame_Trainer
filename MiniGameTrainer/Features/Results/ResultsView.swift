import SwiftUI

/// Shared results screen for every minigame.
struct ResultsView: View {
    let result: GameResult

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

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
                            StatRow(label: "Best", value: result.scorePresentation.formatted(stats.bestScore), highlight: isNewBest)
                            Divider().overlay(AppTheme.Colors.divider)
                            StatRow(label: "Games played", value: "\(stats.gamesPlayed)")
                            StatRow(label: "Average score", value: result.scorePresentation.formattedAverage(stats.averageScore))
                            if let best = stats.bestReactionTime {
                                StatRow(label: "Best reaction (all time)", value: MetricFormatter.milliseconds(best))
                            }
                        }
                    }

                    if !result.metrics.isEmpty {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("THIS SESSION")
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .padding(.bottom, 6)
                                ForEach(result.metrics) { metric in
                                    StatRow(label: metric.label, value: metric.value)
                                }
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        PrimaryButton(title: "Try Again", systemImage: "arrow.counterclockwise") {
                            router.retry(gameID: result.gameID)
                        }
                        PrimaryButton(title: "Home", systemImage: "house.fill", style: .outlined) {
                            router.goHome()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(AppTheme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(duration: 0.5)) { appeared = true }
            }
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 6) {
            Text(result.scorePresentation.label)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(result.scorePresentation.formatted(result.score))
                .font(AppTheme.Fonts.display(84).monospacedDigit())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
            if isNewBest {
                Label("New personal best", systemImage: "star.fill")
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.Colors.success.opacity(0.15)))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
