import SpriteKit
import SwiftUI

struct JellyCutGameView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        JellyCutGameContentView(
            viewModel: JellyCutGameViewModel(feedback: environment.feedback)
        )
    }
}

private struct JellyCutGameContentView: View {
    @StateObject private var viewModel: JellyCutGameViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: @autoclosure @escaping () -> JellyCutGameViewModel) {
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
                    .accessibilityLabel("JELLY CUT game area. Swipe a straight line across the jelly.")
                }

                VStack {
                    HStack {
                        Spacer()
                        Button { viewModel.pause() } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.white.opacity(0.16)))
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
                    pauseOverlay
                }
            }
        }
        .background(Color(red: 0.75, green: 0.03, blue: 0.36).ignoresSafeArea())
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

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Paused").font(AppTheme.Fonts.title).foregroundStyle(.white).padding(.bottom, 12)
                PrimaryButton(title: "Resume", systemImage: "play.fill", action: viewModel.resume)
                PrimaryButton(title: "Restart", systemImage: "arrow.counterclockwise", style: .outlined, action: viewModel.restart)
                PrimaryButton(title: "Quit", systemImage: "xmark", style: .outlined) {
                    viewModel.tearDown()
                    router.quitToIntro()
                }
            }
            .padding(32)
            .frame(maxWidth: 360)
        }
        .accessibilityAddTraits(.isModal)
    }
}
