import SpriteKit
import SwiftUI

struct BloopyGameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var tuning = BloopyTuningStore.shared

    var body: some View {
        BloopyGameContentView(
            viewModel: BloopyGameViewModel(
                config: tuning.config,
                debugOptions: tuning.debugOptions,
                feedback: environment.feedback
            )
        )
    }
}

private struct BloopyGameContentView: View {
    @StateObject private var viewModel: BloopyGameViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: @autoclosure @escaping () -> BloopyGameViewModel) {
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
                    .accessibilityLabel("Bloopy game area. Tap left or right to steer the ball.")
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
                        .opacity(viewModel.phase == .running ? 1 : 0)
                        .disabled(viewModel.phase != .running)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }

                if viewModel.phase == .paused {
                    BloopyPauseOverlay(
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
        .background(Color(BloopyGameConfig.reference.backgroundColor).ignoresSafeArea())
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

private struct BloopyPauseOverlay: View {
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
                    .padding(.bottom, 12)
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
