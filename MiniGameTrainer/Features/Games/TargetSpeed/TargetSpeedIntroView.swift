import SwiftUI

struct TargetSpeedIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TargetSpeedTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TargetSpeedGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                TargetSpeedPreviewIllustration(config: tuning.config)
                    .frame(height: 220)
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
                        StatRow(label: "Best Score", value: stats.gamesPlayed > 0 ? "\(stats.bestScore)" : "–")
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
                .accessibilityHint("Starts Target Speed immediately")
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
                    .accessibilityLabel("Target Speed tuning")
            }
        }
        .sheet(isPresented: $showTuning) { TargetSpeedDebugSettingsView(store: tuning) }
        #endif
    }
}

private struct TargetSpeedPreviewIllustration: View {
    let config: TargetSpeedGameConfig

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Color(config.backgroundColor)
                TargetSpeedBullseyeView(diameter: size * 0.42)
                    .offset(x: -size * 0.18, y: size * 0.08)
                TargetSpeedBullseyeView(diameter: size * 0.22)
                    .offset(x: size * 0.22, y: -size * 0.16)
                TargetSpeedBullseyeView(diameter: size * 0.12)
                    .offset(x: size * 0.08, y: size * 0.22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct TargetSpeedBullseyeView: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.92, green: 0.14, blue: 0.16))
            Circle().fill(Color.white.opacity(0.96)).frame(width: diameter * 0.62, height: diameter * 0.62)
            Circle().fill(Color(red: 0.92, green: 0.14, blue: 0.16)).frame(width: diameter * 0.28, height: diameter * 0.28)
            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(Color(red: 0.35, green: 0.92, blue: 0.38), lineWidth: max(2, diameter * 0.045))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}
