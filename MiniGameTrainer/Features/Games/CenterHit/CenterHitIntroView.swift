import SwiftUI

struct CenterHitIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = CenterHitTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { CenterHitGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts a five-attempt center timing session",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            CenterHitPreviewIllustration(config: tuning.config)
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Center Hit tuning")
            }
        }
        .sheet(isPresented: $showTuning) {
            CenterHitDebugSettingsView(store: tuning)
        }
        #endif
    }
}

private struct CenterHitPreviewIllustration: View {
    let config: CenterHitGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.88
            let height = width * 0.249
            ZStack {
                Color(config.backgroundColor)
                HStack(spacing: 0) {
                    ForEach(Array(config.normalizedZoneFractions.enumerated()), id: \.offset) { index, fraction in
                        Rectangle()
                            .fill(color(for: index))
                            .frame(width: width * fraction, height: height)
                    }
                }
                .frame(width: width, height: height)
                .clipShape(Capsule())

                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: max(2, width * 0.006), height: height)
                Capsule()
                    .fill(.white)
                    .frame(width: max(4, width * 0.0156), height: height * 1.2)
                    .offset(x: width * 0.18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func color(for index: Int) -> Color {
        switch index {
        case 0, 6: Color(config.redColor)
        case 1, 5: Color(config.orangeColor)
        case 2, 4: Color(config.yellowColor)
        default: Color(config.greenColor)
        }
    }
}
