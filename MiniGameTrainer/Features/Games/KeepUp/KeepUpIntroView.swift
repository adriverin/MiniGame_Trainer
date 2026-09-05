import SwiftUI

struct KeepUpIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = KeepUpTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { KeepUpGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Keep Up immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            KeepUpPreviewIllustration(config: tuning.config)
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Keep Up tuning")
            }
        }
        .sheet(isPresented: $showTuning) { KeepUpDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct KeepUpPreviewIllustration: View {
    let config: KeepUpGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let platformDiameter = width * config.platformDiameterRatio
            let ballDiameter = width * config.ballDiameterRatio
            ZStack {
                Color(config.backgroundColor)
                ForEach(0..<9, id: \.self) { index in
                    Circle()
                        .fill(Color(config.trailColor).opacity(0.08 + Double(index) * 0.03))
                        .frame(width: ballDiameter * (0.18 + CGFloat(index) * 0.035))
                        .position(
                            x: width * (0.30 + CGFloat(index) * 0.035),
                            y: proxy.size.height * (0.28 + CGFloat(index) * 0.050)
                        )
                }
                Circle()
                    .fill(Color(config.ballColor))
                    .frame(width: ballDiameter, height: ballDiameter)
                    .position(x: width * 0.30, y: proxy.size.height * 0.25)
                Circle()
                    .fill(Color(config.platformColor))
                    .frame(width: platformDiameter, height: platformDiameter)
                    .position(x: width * 0.61, y: proxy.size.height * 0.72)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
