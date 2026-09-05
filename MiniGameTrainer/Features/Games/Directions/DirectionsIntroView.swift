import SwiftUI

struct DirectionsIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = DirectionsTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { DirectionsGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: stats,
            playHint: "Starts Directions immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            DirectionsPreviewIllustration(config: tuning.config)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Directions tuning")
            }
        }
        .sheet(isPresented: $showTuning) { DirectionsDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct DirectionsPreviewIllustration: View {
    let config: DirectionsGameConfig

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Color(config.backgroundColor)
                ArrowShape()
                    .fill(Color(config.observeArrowColor))
                    .frame(width: width * 0.28, height: width * 0.22)
                    .rotationEffect(.degrees(-90))
                    .offset(y: 8)
                VStack {
                    HStack {
                        Text("0")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Spacer()
                        Text("LEVEL 1")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    HStack {
                        Text("OBSERVE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18)
        )
        path.closeSubpath()
        return path
    }
}
