import SwiftUI

struct SwipeFastIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = SwipeFastTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { SwipeFastGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Swipe Fast immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            SwipeFastPreviewIllustration(config: tuning.config)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Swipe Fast tuning")
            }
        }
        .sheet(isPresented: $showTuning) { SwipeFastDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct SwipeFastPreviewIllustration: View {
    let config: SwipeFastGameConfig

    var body: some View {
        GeometryReader { proxy in
            let box = min(proxy.size.width, proxy.size.height) * 0.38
            let gap = box * 0.12
            let arrows: [SwipeDirection] = [.right, .up, .up, .left]
            ZStack {
                Color(config.backgroundColor)
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        previewBox(size: box, direction: arrows[0])
                        previewBox(size: box, direction: arrows[1])
                    }
                    HStack(spacing: gap) {
                        previewBox(size: box, direction: arrows[2])
                        previewBox(size: box, direction: arrows[3])
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func previewBox(size: CGFloat, direction: SwipeDirection) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * config.boxCornerRadiusRatio, style: .continuous)
                .fill(Color(config.boxColor))
            Image(systemName: arrowSymbol(direction))
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color(config.arrowColor))
            VStack {
                Spacer()
                Capsule()
                    .fill(Color(config.barColor(for: .cyan)))
                    .frame(height: max(3, size * config.barHeightRatio))
                    .padding(.horizontal, size * config.barHorizontalInsetRatio)
                    .padding(.bottom, size * config.barBottomInsetRatio)
            }
        }
        .frame(width: size, height: size)
    }

    private func arrowSymbol(_ direction: SwipeDirection) -> String {
        switch direction {
        case .up: "arrow.up"
        case .right: "arrow.right"
        case .down: "arrow.down"
        case .left: "arrow.left"
        }
    }
}
