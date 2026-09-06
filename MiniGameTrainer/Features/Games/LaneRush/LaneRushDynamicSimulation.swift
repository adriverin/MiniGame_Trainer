import Foundation

struct LaneRushDifficultyModel: Equatable {
  let baseSpeed: Double
  let accelerationCoefficient: Double

  static let reference = LaneRushDifficultyModel(
    baseSpeed: 15,
    accelerationCoefficient: 0.038
  )

  func forwardSpeed(at distanceMeters: Double) -> Double {
    baseSpeed + accelerationCoefficient * max(0, distanceMeters.isFinite ? distanceMeters : 0)
  }
}

struct LaneRushDynamicConfig: Equatable {
  let maximumDeltaTime: TimeInterval
  let oncomingFactor: Double
  let trafficStartDistance: Double
  let trafficPassDistance: Double

  static let reference = LaneRushDynamicConfig(
    maximumDeltaTime: 1.0 / 15.0,
    oncomingFactor: 4.25,
    trafficStartDistance: 100,
    trafficPassDistance: 18.1818181818
  )
}

struct LaneRushRoadMarkingFlow: Equatable {
  static let spacingMeters: Double = 18
  static let initialOffsetMeters: Double = 13
  static let markingCount = 7

  private(set) var distancesAhead: [Double]

  init(playerDistance: Double = 0) {
    distancesAhead = (0..<Self.markingCount).map {
      Self.initialOffsetMeters + Double($0) * Self.spacingMeters
    }
    advance(by: playerDistance)
  }

  var cycleLength: Double { Self.spacingMeters * Double(Self.markingCount) }

  mutating func advance(by playerForwardDelta: Double) {
    guard playerForwardDelta.isFinite, playerForwardDelta > 0 else { return }
    for index in distancesAhead.indices {
      distancesAhead[index] -= playerForwardDelta
      while distancesAhead[index] <= 0 {
        distancesAhead[index] += cycleLength
      }
    }
  }
}

struct LaneRushDynamicSimulation: Equatable {
  let difficulty: LaneRushDifficultyModel
  let config: LaneRushDynamicConfig
  private(set) var distanceMeters: Double
  private(set) var roadMarkings: LaneRushRoadMarkingFlow
  private(set) var trafficDistanceAhead: Double
  private(set) var player: LaneRushPlayerController
  private(set) var isPaused: Bool
  private(set) var lastTimestamp: TimeInterval?

  init(
    distanceMeters: Double = 0,
    startsPaused: Bool = false,
    difficulty: LaneRushDifficultyModel = .reference,
    config: LaneRushDynamicConfig = .reference
  ) {
    self.difficulty = difficulty
    self.config = config
    self.distanceMeters = max(0, distanceMeters.isFinite ? distanceMeters : 0)
    roadMarkings = LaneRushRoadMarkingFlow(playerDistance: self.distanceMeters)
    trafficDistanceAhead = config.trafficStartDistance
    player = LaneRushPlayerController()
    isPaused = startsPaused
    lastTimestamp = nil
  }

  var displayedDistance: Int { Int(floor(distanceMeters)) }
  var forwardSpeed: Double { difficulty.forwardSpeed(at: distanceMeters) }
  var trafficClosingSpeed: Double { forwardSpeed * config.oncomingFactor }

  @discardableResult
  mutating func command(_ command: LaneRushLaneCommand) -> Bool {
    player.command(command)
  }

  mutating func update(at timestamp: TimeInterval) {
    guard timestamp.isFinite else { return }
    guard !isPaused else {
      lastTimestamp = nil
      return
    }
    guard let previous = lastTimestamp else {
      lastTimestamp = timestamp
      return
    }
    lastTimestamp = timestamp
    advance(deltaTime: timestamp - previous)
  }

  mutating func advance(deltaTime: TimeInterval) {
    guard !isPaused, deltaTime.isFinite, deltaTime > 0 else { return }
    let delta = min(deltaTime, config.maximumDeltaTime)
    let playerForwardDelta = forwardSpeed * delta
    distanceMeters += playerForwardDelta
    roadMarkings.advance(by: playerForwardDelta)
    advanceTraffic(byPlayerDistance: playerForwardDelta)
    player.update(deltaTime: delta)
  }

  mutating func pause() {
    isPaused = true
    lastTimestamp = nil
  }

  mutating func resume(at timestamp: TimeInterval) {
    guard timestamp.isFinite else { return }
    isPaused = false
    lastTimestamp = timestamp
  }

  private mutating func advanceTraffic(byPlayerDistance distance: Double) {
    guard distance.isFinite, distance > 0 else { return }
    trafficDistanceAhead -= distance * config.oncomingFactor
    let cycleLength = config.trafficStartDistance - config.trafficPassDistance
    while trafficDistanceAhead <= config.trafficPassDistance {
      trafficDistanceAhead += cycleLength
    }
  }
}
