import SwiftUI

struct LaneRushGameView: View {
  @EnvironmentObject private var environment: AppEnvironment
  @ObservedObject private var tuning = LaneRushTuningStore.shared

  var body: some View {
    LaneRushGameContentView(
      viewModel: LaneRushGameViewModel(
        config: tuning.config,
        debugOptions: tuning.debugOptions,
        feedback: environment.feedback))
  }
}

private struct LaneRushGameContentView: View {
  @StateObject private var viewModel: LaneRushGameViewModel
  @EnvironmentObject private var router: AppRouter
  @EnvironmentObject private var statistics: StatisticsStore
  @Environment(\.scenePhase) private var scenePhase

  init(viewModel: @autoclosure @escaping () -> LaneRushGameViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel())
  }

  var body: some View {
    GeometryReader { proxy in
      TimelineView(.animation) { timeline in
        ZStack {
          Canvas { context, size in
            let road = LaneRushStaticRoadGeometry(size: size)
            LaneRushRoadRenderer(
              size: size,
              vehicles: viewModel.renderState.vehicles,
              roadMarkings: viewModel.renderState.roadMarkings,
              playerPresentation: viewModel.renderState.player.presentation(on: road),
              score: viewModel.renderState.score,
              failureProgress: viewModel.renderState.failureProgress
            ).draw(in: &context)
          }
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
              .onEnded { value in
                guard
                  let command = LaneRushGestureInterpreter().command(
                    start: value.startLocation,
                    end: value.location,
                    gameplayWidth: proxy.size.width)
                else { return }
                _ = viewModel.command(command)
              }
          )
          .onChange(of: timeline.date) { _, date in
            viewModel.update(at: date.timeIntervalSinceReferenceDate)
          }

          VStack {
            HStack {
              Spacer()
              Button {
                viewModel.pause()
              } label: {
                Image(systemName: "pause.fill")
                  .font(.system(size: 15, weight: .bold))
                  .foregroundStyle(.white.opacity(0.9))
                  .frame(width: 40, height: 40)
                  .background(Circle().fill(.black.opacity(0.34)))
              }
              .accessibilityLabel("Pause")
              .opacity(viewModel.phase == .running || viewModel.phase == .failing ? 1 : 0)
              .disabled(viewModel.phase != .running && viewModel.phase != .failing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
          }

          if viewModel.phase == .paused {
            LaneRushPauseOverlay(
              onResume: viewModel.resume,
              onRestart: viewModel.restart,
              onQuit: {
                viewModel.tearDown()
                router.quitToIntro()
              })
          }

          #if DEBUG
            if viewModel.debugOptions.showOverlay {
              VStack {
                HStack {
                  Text(debugText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                  Spacer()
                }
                Spacer()
              }
              .padding(.top, 52)
              .padding(.horizontal, 10)
              .allowsHitTesting(false)
            }
          #endif
        }
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .accessibilityLabel(
      "LANE RUSH game area. Score \(viewModel.renderState.score) metres. "
        + "Tap either side or swipe horizontally to change lanes."
    )
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

  private var debugText: String {
    let logic = viewModel.logic
    let distance = String(format: "%.1f", logic.distanceMeters)
    let speed = String(format: "%.1f", logic.currentSpeed)
    return "distance \(distance)  speed \(speed)\n"
      + "waves \(logic.trafficWaves.count)  cars \(logic.renderState.vehicles.count)  passed \(logic.carsPassed)\n"
      + "lane \(logic.player.lane.rawValue)  changes \(logic.laneChanges)  \(String(describing: logic.state))"
  }
}

private struct LaneRushPauseOverlay: View {
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
        PrimaryButton(
          title: "Restart", systemImage: "arrow.counterclockwise",
          style: .outlined, action: onRestart)
        PrimaryButton(
          title: "Quit", systemImage: "xmark", style: .outlined,
          action: onQuit)
      }
      .padding(32)
      .frame(maxWidth: 360)
    }
    .accessibilityAddTraits(.isModal)
  }
}
