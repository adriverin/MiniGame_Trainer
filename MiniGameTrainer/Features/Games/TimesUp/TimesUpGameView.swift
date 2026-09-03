import SpriteKit
import SwiftUI

struct TimesUpGameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var tuning = TimesUpTuningStore.shared

    var body: some View {
        TimesUpGameContentView(
            viewModel: TimesUpGameViewModel(
                config: tuning.config,
                debugOptions: tuning.debugOptions,
                feedback: environment.feedback
            )
        )
    }
}

private struct TimesUpGameContentView: View {
    @StateObject private var viewModel: TimesUpGameViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: @autoclosure @escaping () -> TimesUpGameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        GeometryReader { proxy in
            let fullSize = CGSize(
                width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            )
            ZStack {
                if let scene = viewModel.scene(for: fullSize) {
                    SpriteView(
                        scene: scene,
                        preferredFramesPerSecond: UIScreen.main.maximumFramesPerSecond,
                        options: [.ignoresSiblingOrder]
                    )
                    .ignoresSafeArea()
                    .accessibilityLabel("TIME'S UP game area. Tap when you think the hidden timer has ended.")
                } else {
                    AppTheme.Colors.background.ignoresSafeArea()
                }

                VStack {
                    HStack {
                        Spacer()
                        Button { viewModel.pause() } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                        }
                        .accessibilityLabel("Pause")
                        .opacity(viewModel.phase == .running && viewModel.levelFeedback == nil && viewModel.sessionSummary == nil ? 1 : 0)
                        .disabled(viewModel.phase != .running || viewModel.levelFeedback != nil || viewModel.sessionSummary != nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }

                if let feedback = viewModel.levelFeedback {
                    TimesUpFeedbackOverlay(
                        result: feedback,
                        summary: viewModel.sessionSummary,
                        levelCount: viewModel.config.resolvedLevelCount,
                        onAdvance: {
                            if viewModel.sessionSummary != nil {
                                viewModel.confirmSessionResults()
                            } else {
                                viewModel.startNextLevel()
                            }
                        }
                    )
                }

                if viewModel.phase == .paused {
                    TimesUpPauseOverlay(
                        onResume: viewModel.resume,
                        onRestart: viewModel.restart,
                        onQuit: {
                            viewModel.tearDown()
                            router.quitToIntro()
                        }
                    )
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .onAppear {
            viewModel.onFinish = { result in
                GameSessionHost(router: router, statistics: statistics).finish(result)
            }
        }
        .onDisappear { viewModel.tearDown() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
    }
}

private struct TimesUpFeedbackOverlay: View {
    let result: TimesUpLevelResult
    let summary: TimesUpSessionSummary?
    let levelCount: Int
    let onAdvance: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                if let summary {
                    Text("FINAL RESULTS")
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ForEach(summary.results, id: \.levelIndex) { item in
                        HStack {
                            Text("Level \(item.levelIndex)")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text(TimesUpFormatter.seconds(item.signedError, signed: item.direction == .late))
                                .foregroundStyle(AppTheme.Colors.success)
                                .monospacedDigit()
                        }
                        .font(AppTheme.Fonts.body)
                    }
                    Text("AVERAGE")
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, 8)
                    Text(TimesUpFormatter.seconds(summary.averageAbsoluteError))
                        .font(AppTheme.Fonts.display(52).monospacedDigit())
                        .foregroundStyle(AppTheme.Colors.accent)
                } else {
                    Text("LEVEL \(result.levelIndex) OF \(levelCount)")
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("You missed by...")
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(TimesUpFormatter.seconds(result.signedError, signed: result.direction == .late))
                        .font(AppTheme.Fonts.display(64).monospacedDigit())
                        .foregroundStyle(AppTheme.Colors.success)
                    Text(TimesUpFormatter.directionCopy(result.direction))
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.success)
                }

                PrimaryButton(
                    title: summary == nil ? "NEXT LEVEL" : "RESULTS",
                    systemImage: summary == nil ? "arrow.right" : "chart.bar.fill",
                    action: onAdvance
                )
                .padding(.top, 12)
            }
            .padding(32)
            .frame(maxWidth: 360)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct TimesUpPauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Paused")
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.bottom, 8)
                Text("The current interval will restart. A paused hidden timer is not scored.")
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                PrimaryButton(title: "Resume", systemImage: "play.fill", action: onResume)
                PrimaryButton(title: "Restart", systemImage: "arrow.counterclockwise", style: .outlined, action: onRestart)
                PrimaryButton(title: "Quit", systemImage: "xmark", style: .outlined, action: onQuit)
            }
            .padding(32)
            .frame(maxWidth: 360)
        }
        .accessibilityAddTraits(.isModal)
    }
}
