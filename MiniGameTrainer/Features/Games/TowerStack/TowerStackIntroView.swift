import SwiftUI

struct TowerStackIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TowerStackTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TowerStackGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                TowerStackPreviewIllustration(config: tuning.config)
                    .frame(height: 205)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(descriptor.name.uppercased())
                        .font(AppTheme.Fonts.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(descriptor.instructions)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CardContainer {
                    VStack(spacing: 2) {
                        StatRow(label: "Best Score", value: "\(stats.bestScore)")
                        StatRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                        if stats.gamesPlayed > 0 {
                            StatRow(label: "Average Score", value: String(format: "%.1f", stats.averageScore))
                        }
                    }
                }

                Spacer()
                PrimaryButton(title: "PLAY", systemImage: "play.fill") {
                    router.startGame(descriptor.id)
                }
                .accessibilityHint("The first block starts sliding immediately; tap once to dismiss the hint")
            }
            .padding(AppTheme.Metrics.screenPadding)
        }
        .navigationTitle(descriptor.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTuning = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Tower Stack tuning")
            }
        }
        .sheet(isPresented: $showTuning) {
            TowerStackDebugSettingsView(store: tuning)
        }
        #endif
    }
}

/// Small original illustration of a stepped pseudo-3D tower using the game's own hue cycle.
private struct TowerStackPreviewIllustration: View {
    let config: TowerStackGameConfig

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let projection = TowerStackProjection(
                sceneSize: CGSize(width: size.width, height: size.height * 1.6),
                config: config
            )
            let camera = TowerStackWorldPoint(x: 0, y: config.blockHeight * 6, z: 0)
            let footprints: [TowerStackFootprint] = [
                TowerStackFootprint(centerX: 0.00, centerZ: 0.00, width: 1.00, depth: 1.00),
                TowerStackFootprint(centerX: 0.04, centerZ: 0.00, width: 0.92, depth: 1.00),
                TowerStackFootprint(centerX: 0.04, centerZ: -0.03, width: 0.92, depth: 0.94),
                TowerStackFootprint(centerX: 0.08, centerZ: -0.03, width: 0.84, depth: 0.94),
                TowerStackFootprint(centerX: 0.08, centerZ: 0.00, width: 0.84, depth: 0.88),
                TowerStackFootprint(centerX: 0.05, centerZ: 0.00, width: 0.78, depth: 0.88),
            ]
            ZStack {
                LinearGradient(
                    colors: TowerStackPalette.backgroundStops.map { Color(uiColor: $0.color) },
                    startPoint: .top,
                    endPoint: .bottom
                )
                Canvas { context, _ in
                    let pedestal = projection.projectBlock(config.initialFootprint, bottomY: -3, topY: 0, camera: camera)
                    draw(pedestal, colors: TowerStackPalette.pedestal, in: &context, height: size.height * 1.6)
                    for (index, footprint) in footprints.enumerated() {
                        let bottom = CGFloat(index) * config.blockHeight
                        let block = projection.projectBlock(footprint, bottomY: bottom, topY: bottom + config.blockHeight, camera: camera)
                        draw(block, colors: TowerStackPalette.colors(forBlockIndex: index, config: config), in: &context, height: size.height * 1.6)
                    }
                    let moving = footprints[5].moved(to: 0.9, along: .x)
                    let bottom = CGFloat(6) * config.blockHeight
                    let block = projection.projectBlock(moving, bottomY: bottom, topY: bottom + config.blockHeight, camera: camera)
                    draw(block, colors: TowerStackPalette.colors(forBlockIndex: 6, config: config), in: &context, height: size.height * 1.6)
                }
                .offset(y: -size.height * 0.42)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func draw(_ block: TowerStackProjectedBlock, colors: TowerStackBlockColors, in context: inout GraphicsContext, height: CGFloat) {
        let (left, right) = block.sideXIsLeft ? (block.sideX, block.sideZ) : (block.sideZ, block.sideX)
        context.fill(path(left, height: height), with: .color(Color(uiColor: colors.leftFace)))
        context.fill(path(right, height: height), with: .color(Color(uiColor: colors.rightFace)))
        context.fill(path(block.top, height: height), with: .color(Color(uiColor: colors.top)))
    }

    /// SpriteKit points are y-up; SwiftUI is y-down.
    private func path(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x, y: height - first.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: height - point.y))
        }
        path.closeSubpath()
        return path
    }
}
