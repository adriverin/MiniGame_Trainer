import SwiftUI

struct TapSevenIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TapSevenTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TapSevenGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts TAP AT 7",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            TapSevenPreviewIllustration(config: tuning.config)
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
