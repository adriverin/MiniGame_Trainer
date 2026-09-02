import SpriteKit
import SwiftUI

/// Entry point registered in `PianoGameModule`; resolves dependencies and creates the view model once.
struct PianoGameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var tuning = PianoTuningStore.shared

    var body: some View {
        PianoGameContentView(
            viewModel: PianoGameViewModel(
                config: tuning.config,
                debugOptions: tuning.debugOptions,
                feedback: environment.feedback
            )
        )
    }
}

private struct PianoGameContentView: View {
    @StateObject private var viewModel: PianoGameViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: @autoclosure @escaping () -> PianoGameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        GeometryReader { proxy in
            // The scene covers the whole screen; the reader itself respects the safe area so the
            // HUD button can be laid out below the Dynamic Island.
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
                    .accessibilityLabel("Piano game area")
                } else {
                    AppTheme.Colors.background.ignoresSafeArea()
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            viewModel.pause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.white.opacity(0.12)))
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
                    PianoPauseOverlay(
                        onResume: viewModel.resume,
                        onRestart: viewModel.restart,
                        onQuit: {
                            viewModel.tearDown()
                            router.quitToIntro()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .onAppear {
            viewModel.onFinish = { result in
                GameSessionHost(router: router, statistics: statistics).finish(result)
            }
        }
        .onDisappear {
            viewModel.tearDown()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                viewModel.pause()
            }
        }
    }
}

private struct PianoPauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
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
