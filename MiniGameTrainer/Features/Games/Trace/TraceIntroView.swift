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
            let field = TraceHexField(radius: 1)
            let geometry = TraceGeometry(
                sceneSize: CGSize(width: width, height: height),
                config: config,
                field: field
            )
            let previewPath = [
                TraceNode(q: 0, r: 0),
                TraceNode(q: 1, r: 0),
                TraceNode(q: 1, r: -1),
                TraceNode(q: 0, r: -1),
            ]
            ZStack {
                Color(config.backgroundColor)
                ForEach(field.allNodes, id: \.self) { node in
                    let point = geometry.position(for: node)
                    Circle()
                        .fill(Color(config.inactiveNodeColor))
                        .frame(width: geometry.nodeVisualRadius * 2, height: geometry.nodeVisualRadius * 2)
                        .position(x: point.x, y: height - point.y)
                }
                Path { path in
                    let first = geometry.position(for: previewPath[0])
                    path.move(to: CGPoint(x: first.x, y: height - first.y))
                    for node in previewPath.dropFirst() {
                        let point = geometry.position(for: node)
                        path.addLine(to: CGPoint(x: point.x, y: height - point.y))
                    }
                }
                .stroke(
                    Color(config.referenceColor),
                    style: StrokeStyle(lineWidth: geometry.lineWidth, lineCap: .round, lineJoin: .round)
                )
                ForEach(previewPath, id: \.self) { node in
                    let point = geometry.position(for: node)
                    Circle()
                        .fill(Color(config.referenceColor))
                        .frame(width: geometry.nodeVisualRadius * 2, height: geometry.nodeVisualRadius * 2)
                        .position(x: point.x, y: height - point.y)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
