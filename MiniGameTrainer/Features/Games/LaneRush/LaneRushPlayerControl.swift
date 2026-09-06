import CoreGraphics
import Foundation

enum LaneRushLane: Int, CaseIterable, Equatable {
  case left = 0
  case center = 1
  case right = 2

  var lateral: CGFloat { CGFloat(rawValue - 1) }
}

enum LaneRushLaneCommand: Int, Equatable {
  case left = -1
  case right = 1
}

struct LaneRushPlayerConfig: Equatable {
  let laneChangeDuration: TimeInterval
  let swipeThreshold: CGFloat
  let maximumLeanDegrees: CGFloat

  static let reference = LaneRushPlayerConfig(
    laneChangeDuration: 0.18,
    swipeThreshold: 24,
    maximumLeanDegrees: 8
  )
}

struct LaneRushLaneTransition: Equatable {
  let source: LaneRushLane
  let target: LaneRushLane
  var elapsed: TimeInterval
}

struct LaneRushGestureInterpreter {
  let swipeThreshold: CGFloat

  init(config: LaneRushPlayerConfig = .reference) {
    swipeThreshold = config.swipeThreshold
  }

  func command(start: CGPoint, end: CGPoint, gameplayWidth: CGFloat) -> LaneRushLaneCommand? {
    let horizontal = end.x - start.x
    let vertical = end.y - start.y

    if hypot(horizontal, vertical) >= swipeThreshold {
      guard abs(horizontal) > abs(vertical) else { return nil }
      return horizontal < 0 ? .left : .right
    }

    return start.x < gameplayWidth / 2 ? .left : .right
  }
}

struct LaneRushPlayerController: Equatable {
  let config: LaneRushPlayerConfig
  private(set) var lane: LaneRushLane
  private(set) var lateralPosition: CGFloat
  private(set) var transition: LaneRushLaneTransition?
  private(set) var pendingCommand: LaneRushLaneCommand?

  init(lane: LaneRushLane = .center, config: LaneRushPlayerConfig = .reference) {
    self.config = config
    self.lane = lane
    lateralPosition = lane.lateral
  }

  var destinationLane: LaneRushLane { transition?.target ?? lane }

  var transitionProgress: CGFloat {
    guard let transition else { return 0 }
    return min(1, max(0, CGFloat(transition.elapsed / config.laneChangeDuration)))
  }

  var leanDegrees: CGFloat {
    guard let transition else { return 0 }
    let direction = CGFloat(transition.target.rawValue - transition.source.rawValue)
    return direction * config.maximumLeanDegrees * sin(.pi * transitionProgress)
  }

  @discardableResult
  mutating func command(_ command: LaneRushLaneCommand) -> Bool {
    if transition != nil {
      guard pendingCommand == nil,
        targetLane(from: destinationLane, command: command) != nil
      else { return false }
      pendingCommand = command
      return true
    }

    return begin(command)
  }

  mutating func update(deltaTime: TimeInterval) {
    var available = max(0, deltaTime)

    while var active = transition {
      let remaining = max(0, config.laneChangeDuration - active.elapsed)
      let consumed = min(available, remaining)
      active.elapsed += consumed
      available -= consumed

      let progress = min(1, max(0, CGFloat(active.elapsed / config.laneChangeDuration)))
      let eased = progress * progress * (3 - 2 * progress)
      lateralPosition =
        active.source.lateral
        + (active.target.lateral - active.source.lateral) * eased

      if active.elapsed < config.laneChangeDuration {
        transition = active
        break
      }

      lane = active.target
      lateralPosition = lane.lateral
      transition = nil

      if let pending = pendingCommand {
        pendingCommand = nil
        _ = begin(pending)
      }

      if available <= 0 { break }
    }
  }

  private mutating func begin(_ command: LaneRushLaneCommand) -> Bool {
    guard let target = targetLane(from: lane, command: command) else { return false }
    transition = LaneRushLaneTransition(source: lane, target: target, elapsed: 0)
    return true
  }

  private func targetLane(
    from source: LaneRushLane,
    command: LaneRushLaneCommand
  ) -> LaneRushLane? {
    LaneRushLane(rawValue: source.rawValue + command.rawValue)
  }
}
