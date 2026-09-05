import SwiftUI

struct BloopyIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = BloopyTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { BloopyGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Bloopy immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            BloopyPreviewIllustration(config: tuning.config)
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Bloopy tuning")
            }
        }
        .sheet(isPresented: $showTuning) { BloopyDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct BloopyPreviewIllustration: View {
    let config: BloopyGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let ball = width * config.ballDiameterRatio
            ZStack {
                Color(config.backgroundColor)
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color(config.trailColor).opacity(0.10 + Double(index) * 0.04))
                        .frame(width: ball * (0.20 + CGFloat(index) * 0.04))
                        .position(
                            x: width * (0.28 + CGFloat(index) * 0.04),
                            y: proxy.size.height * (0.62 - CGFloat(index) * 0.045)
                        )
                }
                Circle()
                    .fill(Color(config.ballColor))
                    .frame(width: ball, height: ball)
                    .position(x: width * 0.62, y: proxy.size.height * 0.28)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(config.platformColor))
                    .frame(width: width * 0.28, height: 14)
                    .position(x: width * 0.32, y: proxy.size.height * 0.72)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(config.platformColor))
                    .frame(width: width * 0.22, height: 14)
                    .position(x: width * 0.70, y: proxy.size.height * 0.42)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
