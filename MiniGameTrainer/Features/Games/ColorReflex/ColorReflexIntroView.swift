import SwiftUI

struct ColorReflexIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = ColorReflexTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { ColorReflexGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Color Reflex immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            ColorReflexPreviewIllustration()
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Color Reflex tuning")
            }
        }
        .sheet(isPresented: $showTuning) { ColorReflexDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct ColorReflexPreviewIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(ColorReflexSwatch.teal.uiColor),
                        Color(ColorReflexSwatch.coral.uiColor),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                VStack(spacing: 16) {
                    Capsule()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .background(Capsule().fill(Color(red: 0.28, green: 0.84, blue: 0.32)))
                        .frame(width: proxy.size.width * 0.55, height: 8)
                    Text("Wait...")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
