import SwiftUI

struct JumpyIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = JumpyTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { JumpyGameModule.descriptor }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: statistics.statistics(for: descriptor.id),
            playHint: "Starts JUMPY immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            JumpyPreviewIllustration(config: tuning.config)
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("JUMPY tuning")
            }
        }
        .sheet(isPresented: $showTuning) { JumpyDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct JumpyPreviewIllustration: View {
    let config: JumpyGameConfig

    var body: some View {
        GeometryReader { proxy in
            let row = proxy.size.height / 6
            ZStack {
                Color(config.backgroundColor)
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(Color(index == 0 || index == 4 ? config.safeColor : (index.isMultiple(of: 2) ? config.roadAlternateColor : config.roadColor)))
                        .frame(height: row - 1)
                        .position(x: proxy.size.width / 2, y: proxy.size.height - row * (CGFloat(index) + 0.5))
                }
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill([Color.cyan, .yellow, .orange, .pink, .blue][index])
                        .frame(width: proxy.size.width * 0.18, height: row * 0.46)
                        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.35)).frame(height: row * 0.13).padding(.horizontal, 8) }
                        .position(x: proxy.size.width * (0.14 + CGFloat(index % 3) * 0.35), y: proxy.size.height - row * (CGFloat(index % 3 + 1) + 0.5))
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(config.playerDarkColor))
                        .frame(width: proxy.size.width * 0.088, height: row * 0.18)
                        .offset(x: proxy.size.width * 0.006, y: row * 0.22)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(config.playerColor))
                        .frame(width: proxy.size.width * 0.10, height: row * 0.45)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(config.playerLightColor))
                        .frame(width: proxy.size.width * 0.078, height: row * 0.28)
                        .offset(y: -row * 0.10)
                }
                .shadow(color: .black.opacity(0.35), radius: 2, y: 4)
                .position(x: proxy.size.width / 2, y: proxy.size.height - row * 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
