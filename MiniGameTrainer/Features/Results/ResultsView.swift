import SwiftUI

enum ResultProgressFeedback: Equatable {
    case newPersonalBest
    case matchedBest
    case distanceFromBest(String)

    static func evaluate(result: GameResult, statistics: GameStatistics) -> ResultProgressFeedback {
        if statistics.gamesPlayed <= 1 {
            return .newPersonalBest
        }

        let comparison = result.scorePresentation.comparison
        if comparison.isBetter(result.score, than: statistics.previousBestScore) {
            return .newPersonalBest
        }

        let difference = Swift.abs(result.score - statistics.bestScore)
        if difference == 0 {
            return .matchedBest
        }
        return .distanceFromBest(result.scorePresentation.formattedDifference(difference))
    }

    var title: String {
        switch self {
        case .newPersonalBest: "New Personal Best"
        case .matchedBest: "Matched your best"
        case .distanceFromBest(let difference): "\(difference) from your best"
        }
    }

    var isNewPersonalBest: Bool {
        if case .newPersonalBest = self { return true }
        return false
    }
}

/// Shared, progress-led results screen for every minigame.
struct ResultsView: View {
    let result: GameResult

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 78

    private var descriptor: MiniGameDescriptor? { GameRegistry.descriptor(for: result.gameID) }
    private var stats: GameStatistics { statistics.statistics(for: result.gameID) }
    private var theme: GameVisualTheme { GamePresentationCatalog.theme(for: result.gameID) }
    private var progress: ResultProgressFeedback {
        ResultProgressFeedback.evaluate(result: result, statistics: stats)
    }
    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 132), spacing: AppTheme.Spacing.md, alignment: .top)]
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    resultHeader
                    scoreHero
                    progressCard
                    sessionSummary
                    if !result.metrics.isEmpty { sessionMetrics }
                }
                .padding(AppTheme.Metrics.screenPadding)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AppTheme.Spacing.sm) {
                PrimaryButton(
                    title: "Try Again",
                    systemImage: "arrow.counterclockwise",
                    tint: theme.primary
                ) {
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
            .background(.ultraThinMaterial)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: AppTheme.Motion.entrance, dampingFraction: 0.78)) {
                    appeared = true
                }
            }
        }
    }

    private var resultHeader: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if let descriptor {
                GameIconView(descriptor: descriptor, theme: theme, size: 46)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("RESULTS")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.1)
                    .foregroundStyle(theme.primary)
                Text(descriptor?.name ?? result.gameID)
                    .font(AppTheme.Fonts.heading)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var scoreHero: some View {
        ZStack {
            GameMotifBackground(theme: theme)
            VStack(spacing: AppTheme.Spacing.xs) {
                Text(result.scorePresentation.label.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(result.scorePresentation.formatted(result.score))
                    .font(AppTheme.Fonts.display(scoreSize).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.32)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .shadow(color: theme.primary.opacity(0.25), radius: 18)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 176)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.scorePresentation.label), \(result.scorePresentation.formatted(result.score))")
    }

    private var progressCard: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: progress.isNewPersonalBest ? "trophy.fill" : "scope")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primary)
                .frame(width: 44, height: 44)
                .background(theme.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.title)
                    .font(AppTheme.Fonts.body.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Best \(result.scorePresentation.formatted(stats.bestScore))")
                    .font(AppTheme.Fonts.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
            if progress.isNewPersonalBest {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.primary)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(theme.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var sessionSummary: some View {
        HStack(spacing: 0) {
            summaryItem(title: "Games", value: "\(stats.gamesPlayed)")
            Divider().overlay(AppTheme.Colors.divider).frame(height: 44)
            summaryItem(title: "Average", value: result.scorePresentation.formattedAverage(stats.averageScore))
            if let bestReaction = stats.bestReactionTime {
                Divider().overlay(AppTheme.Colors.divider).frame(height: 44)
                summaryItem(title: "Best reaction", value: MetricFormatter.milliseconds(bestReaction))
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(value)
                .font(AppTheme.Fonts.body.weight(.bold).monospacedDigit())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var sessionMetrics: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("This Session")
                .font(AppTheme.Fonts.heading)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: AppTheme.Spacing.md) {
                ForEach(result.metrics) { metric in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(metric.value)
                            .font(AppTheme.Fonts.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(metric.label)
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
