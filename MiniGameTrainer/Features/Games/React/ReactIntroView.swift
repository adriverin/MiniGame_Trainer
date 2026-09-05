import SwiftUI

struct ReactIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = ReactTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { ReactGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts a five-round visual reaction test",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            ReactPreviewIllustration()
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("REACT tuning")
            }
        }
        .sheet(isPresented: $showTuning) {
            ReactDebugSettingsView(store: tuning)
        }
        #endif
    }
}

private struct ReactPreviewIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height) * 0.22
            let gap = diameter * 0.14
            let step = diameter + gap
            ZStack {
                Color(red: 27 / 255, green: 23 / 255, blue: 27 / 255)
                ForEach(0..<9, id: \.self) { index in
                    let row = index / 3
                    let column = index % 3
                    Circle()
                        .fill(index == 5 ? Color(red: 94 / 255, green: 209 / 255, blue: 192 / 255) : Color(red: 39 / 255, green: 51 / 255, blue: 61 / 255))
                        .frame(width: diameter, height: diameter)
                        .offset(x: CGFloat(column - 1) * step, y: CGFloat(row - 1) * step)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
