import SwiftUI

struct TraceIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TraceTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TraceGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Trace immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            TracePreviewIllustration(config: tuning.config)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Trace tuning")
            }
        }
        .sheet(isPresented: $showTuning) { TraceDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct TracePreviewIllustration: View {
    let config: TraceGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let nodes: [(CGFloat, CGFloat)] = [
                (0.22, 0.62), (0.40, 0.38), (0.58, 0.58), (0.74, 0.30),
            ]
            ZStack {
                Color(config.backgroundColor)
                ForEach(0..<12, id: \.self) { index in
                    let col = index % 4
                    let row = index / 4
                    Circle()
                        .fill(Color(config.inactiveNodeColor))
                        .frame(width: 14, height: 14)
                        .position(
                            x: width * (0.22 + CGFloat(col) * 0.18 + (row % 2 == 1 ? 0.06 : 0)),
                            y: height * (0.28 + CGFloat(row) * 0.22)
                        )
                }
                Path { path in
                    path.move(to: CGPoint(x: width * nodes[0].0, y: height * nodes[0].1))
                    for node in nodes.dropFirst() {
                        path.addLine(to: CGPoint(x: width * node.0, y: height * node.1))
                    }
                }
                .stroke(Color(config.referenceColor), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                ForEach(0..<nodes.count, id: \.self) { index in
                    Circle()
                        .fill(Color(config.referenceColor))
                        .frame(width: 18, height: 18)
                        .position(x: width * nodes[index].0, y: height * nodes[index].1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
