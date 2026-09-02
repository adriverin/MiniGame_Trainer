import SwiftUI

struct TrampboxIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = TrampboxTuningStore.shared
    @State private var showTuning = false

    private var descriptor: MiniGameDescriptor { TrampboxGameModule.descriptor }
    private var stats: GameStatistics { statistics.statistics(for: descriptor.id) }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 12)
                TrampboxPreviewIllustration()
                    .frame(height: 205)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(descriptor.name)
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
                .accessibilityHint("Starts a countdown, then automatic bouncing")
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
                    .accessibilityLabel("Trampbox tuning")
            }
        }
        .sheet(isPresented: $showTuning) {
            TrampboxDebugSettingsView(store: tuning)
        }
        #endif
    }
}

private struct TrampboxPreviewIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.08, blue: 0.22), Color(red: 0.40, green: 0.27, blue: 0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                ForEach(0..<6, id: \.self) { index in
                    let progress = CGFloat(index) / 5
                    let width = 28 + progress * 76
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.opacity(0.92))
                        .frame(width: width, height: 7 + progress * 9)
                        .offset(
                            x: [-25, 30, -12, 38, -44, 12][index],
                            y: -78 + progress * 154
                        )
                }
                Circle()
                    .fill(Color.black)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 26, height: 26)
                    .offset(x: 18, y: 40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
