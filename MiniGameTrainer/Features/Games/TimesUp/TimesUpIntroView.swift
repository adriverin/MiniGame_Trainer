import SwiftUI

struct TimesUpIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TimesUpTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TimesUpGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                TimesUpPreviewIllustration(config: tuning.config)
                    .frame(height: 220)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(descriptor.name.uppercased())
                        .font(AppTheme.Fonts.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(descriptor.instructions)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CardContainer {
                    VStack(spacing: 2) {
                        StatRow(
                            label: "Best Average",
                            value: stats.gamesPlayed > 0 ? descriptor.scorePresentation.formatted(stats.bestScore) : "–"
                        )
                        StatRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                        if stats.gamesPlayed > 0 {
                            StatRow(
                                label: "Average Result",
                                value: descriptor.scorePresentation.formattedAverage(stats.averageScore)
                            )
                        }
                    }
                }

                Spacer()
                PrimaryButton(title: "PLAY", systemImage: "play.fill") {
                    router.startGame(descriptor.id)
                }
                .accessibilityHint("Starts TIME'S UP")
            }
            .padding(AppTheme.Metrics.screenPadding)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("TIME'S UP tuning")
            }
        }
        .sheet(isPresented: $showTuning) { TimesUpDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct TimesUpPreviewIllustration: View {
    let config: TimesUpGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * config.barWidthRatio * 1.15
            let height = proxy.size.height * 0.82
            ZStack {
                Color(config.backgroundColor)
                RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: width, height: height)
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(config.fillTopColor), Color(config.fillBottomColor)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width, height: height * 0.72)
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: width / 2, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
