import SwiftUI

struct TapSevenIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TapSevenTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TapSevenGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                TapSevenPreviewIllustration(config: tuning.config)
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
                            label: "Best Error",
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
                .accessibilityHint("Starts TAP AT 7")
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
                    .accessibilityLabel("TAP AT 7 tuning")
            }
        }
        .sheet(isPresented: $showTuning) { TapSevenDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct TapSevenPreviewIllustration: View {
    let config: TapSevenGameConfig

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height) * 0.82
            let stroke = diameter * 0.11
            ZStack {
                Color(config.backgroundColor)
                Circle()
                    .stroke(Color(config.trackColor), lineWidth: stroke)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .rotation(.degrees(-90))
                    .stroke(Color(config.progressColor), style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                    .frame(width: diameter, height: diameter)
                Text("3.50")
                    .font(.system(size: diameter * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
