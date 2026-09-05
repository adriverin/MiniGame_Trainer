import SwiftUI

struct PianoIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = PianoTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { PianoGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts a countdown, then the game",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            PianoPreviewIllustration()
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTuning = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Tuning")
            }
        }
        .sheet(isPresented: $showTuning) {
            PianoDebugSettingsView(store: tuning)
        }
        #endif
    }
}

/// Simple original illustration of the tile column, drawn with the game palette.
private struct PianoPreviewIllustration: View {
    private let lanes = 4
    private let pattern: [(row: Int, lane: Int, active: Bool)] = [
        (0, 2, true), (1, 0, true), (2, 3, true), (3, 1, false),
    ]

    var body: some View {
        GeometryReader { proxy in
            let laneWidth = proxy.size.width / CGFloat(lanes)
            let rowHeight = proxy.size.height / 4
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.Colors.background)
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, tile in
                    Rectangle()
                        .fill(Color(uiColor: AppTheme.UIColors.activeTile).opacity(tile.active ? 1 : 0.08))
                        .frame(width: laneWidth - 3, height: rowHeight - 3)
                        .offset(x: laneWidth * CGFloat(tile.lane) + 1.5, y: rowHeight * CGFloat(tile.row) + 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
