import Combine
import Foundation

@MainActor
final class LaneRushGameViewModel: ObservableObject {
  enum Phase: Equatable {
    case running
    case paused
    case failing
    case finished
  }

  @Published private(set) var phase: Phase = .running
  @Published private(set) var renderState: LaneRushRenderState
  let config: LaneRushGameConfig
  private let feedback: FeedbackService
  private(set) var logic: LaneRushGameLogic
  var debugOptions: LaneRushDebugOptions
  var onFinish: ((GameResult) -> Void)?
  private var previousFrameTime: TimeInterval?

  init(
    config: LaneRushGameConfig,
    debugOptions: LaneRushDebugOptions,
    feedback: FeedbackService
  ) {
    self.config = config
    self.debugOptions = debugOptions
    self.feedback = feedback
    let logic = LaneRushGameLogic(config: config)
    logic.collisionDetectionEnabled = !debugOptions.disableCollisions
    logic.difficultyDistanceOverride = debugOptions.forcedDifficultyDistance
    #if DEBUG
      if let offset = debugOptions.trafficSnapshotOffset {
        logic.offsetTrafficForDebug(by: offset)
      }
    #endif
    if debugOptions.forceCenterCollision {
      logic.replaceTrafficForTesting([
        LaneRushTrafficWave(
          id: -1,
          distanceAhead: 72,
          obstacles: [
            LaneRushTrafficObstacle(
              id: -1, lane: .center, appearance: .orangeCoupe)
          ],
          safeLane: .left)
      ])
    }
    self.logic = logic
    renderState = logic.renderState
    feedback.prepare()
  }

  func update(at timestamp: TimeInterval) {
    guard timestamp.isFinite else { return }
    guard !debugOptions.freezeMotion else {
      previousFrameTime = nil
      return
    }
    guard phase == .running || phase == .failing else {
      previousFrameTime = nil
      return
    }
    guard let previousFrameTime else {
      self.previousFrameTime = timestamp
      return
    }
    self.previousFrameTime = timestamp
    #if DEBUG
      if debugOptions.autoDrive { driveTowardSafeLane() }
    #endif
    logic.update(deltaTime: timestamp - previousFrameTime)
    handleEvents()
    renderState = logic.renderState
  }

  @discardableResult
  func command(_ command: LaneRushLaneCommand) -> Bool {
    let accepted = logic.requestLaneChange(command)
    renderState = logic.renderState
    return accepted
  }

  func pause() {
    guard phase == .running || phase == .failing else { return }
    logic.pause()
    phase = .paused
    previousFrameTime = nil
    renderState = logic.renderState
  }

  func resume() {
    guard phase == .paused else { return }
    logic.resume()
    phase = logic.state == .failing ? .failing : .running
    previousFrameTime = nil
    renderState = logic.renderState
  }

  func restart() {
    let logic = LaneRushGameLogic(config: config)
    logic.collisionDetectionEnabled = !debugOptions.disableCollisions
    logic.difficultyDistanceOverride = debugOptions.forcedDifficultyDistance
    #if DEBUG
      if let offset = debugOptions.trafficSnapshotOffset {
        logic.offsetTrafficForDebug(by: offset)
      }
    #endif
    self.logic = logic
    phase = .running
    previousFrameTime = nil
    renderState = logic.renderState
  }

  func tearDown() {
    feedback.stop()
  }

  private func handleEvents() {
    for event in logic.drainEvents() {
      switch event {
      case .collided:
        phase = .failing
        feedback.gameFailed()
      case .finished:
        guard phase != .finished, !debugOptions.holdCollision else { continue }
        phase = .finished
        onFinish?(LaneRushResultBuilder.makeResult(from: logic.makeSummary()))
      }
    }
  }

  private func driveTowardSafeLane() {
    guard let safeLane = logic.nearestUpcomingSafeLane() else { return }
    let destination = logic.player.destinationLane
    guard destination != safeLane else { return }
    _ = logic.requestLaneChange(destination.rawValue < safeLane.rawValue ? .right : .left)
  }
}

@MainActor
enum LaneRushResultBuilder {
  static func makeResult(from summary: LaneRushSessionSummary) -> GameResult {
    GameResult(
      gameID: LaneRushGameModule.descriptor.id,
      score: summary.distance,
      scorePresentation: LaneRushGameModule.descriptor.scorePresentation,
      duration: summary.duration,
      metrics: [
        GameMetric(key: "distance", label: "Distance", value: "\(summary.distance) m"),
        GameMetric(key: "carsPassed", label: "Cars Passed", value: "\(summary.carsPassed)"),
        GameMetric(key: "laneChanges", label: "Lane Changes", value: "\(summary.laneChanges)"),
        GameMetric(
          key: "duration", label: "Duration",
          value: MetricFormatter.seconds(summary.duration)),
        GameMetric(
          key: "maximumSpeed", label: "Maximum Speed",
          value: String(format: "%.1f m/s", summary.maximumSpeed)),
      ])
  }
}
