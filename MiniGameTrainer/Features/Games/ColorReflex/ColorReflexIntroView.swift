import SwiftUI

struct ColorReflexIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = ColorReflexTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { ColorReflexGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                ColorReflexPreviewIllustration()
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
                .accessibilityHint("Starts Color Reflex immediately")
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
