import SwiftUI

struct GridIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = GridTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { GridGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts GRID immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            GridPreviewIllustration(config: tuning.config)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("GRID tuning")
            }
        }
        .sheet(isPresented: $showTuning) { GridDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct GridPreviewIllustration: View {
    let config: GridGameConfig
    private let highlighted: Set<GridCell> = GridDifficultyModel.qualityAssurancePattern

    var body: some View {
        GeometryReader { proxy in
            let geometry = GridGeometry(
                sceneSize: CGSize(width: proxy.size.width, height: proxy.size.height),
                rows: 3,
                columns: 3,
                config: {
                    var preview = config
                    preview.gridHeightRatio = 0.72
                    preview.gridCenterYRatio = 0.50
                    preview.gridWidthRatio = 0.72
                    return preview
                }()
            )
            ZStack {
                Color(config.backgroundColor)
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { column in
                        let cell = GridCell(row: row, column: column)
                        let frame = geometry.frame(for: cell)
                        RoundedRectangle(cornerRadius: geometry.cornerRadius, style: .continuous)
                            .fill(Color(highlighted.contains(cell) ? config.activeCellColor : config.inactiveCellColor))
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: proxy.size.height - frame.midY)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
