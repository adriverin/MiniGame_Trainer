import Foundation

struct LaneRushTrafficFairness {
  static func requiredTime(
    from source: LaneRushLane,
    to target: LaneRushLane,
    laneChangeDuration: TimeInterval,
    reactionMargin: TimeInterval
  ) -> TimeInterval {
    let transitions = abs(target.rawValue - source.rawValue)
    guard transitions > 0 else { return 0 }
    return Double(transitions) * laneChangeDuration + reactionMargin
  }

  static func isReachable(
    from source: LaneRushLane,
    to target: LaneRushLane,
    gap: Double,
    closingSpeed: Double,
    laneChangeDuration: TimeInterval = LaneRushPlayerConfig.reference.laneChangeDuration,
    reactionMargin: TimeInterval
  ) -> Bool {
    guard gap >= 0, closingSpeed > 0 else { return source == target }
    return gap / closingSpeed + 1e-9
      >= requiredTime(
        from: source,
        to: target,
        laneChangeDuration: laneChangeDuration,
        reactionMargin: reactionMargin)
  }
}

struct LaneRushTrafficGenerator {
  let config: LaneRushGameConfig
  let difficulty: LaneRushTrafficDifficultyModel
  private(set) var previousSafeLane: LaneRushLane = .center
  private(set) var nextWaveID = 0
  private(set) var nextObstacleID = 0
  private(set) var rng: AnyRandomNumberGenerator

  init(
    config: LaneRushGameConfig = .reference,
    difficulty: LaneRushTrafficDifficultyModel = .init()
  ) {
    self.config = config
    self.difficulty = difficulty
    rng = .seeded(config.randomSeed)
  }

  mutating func spacing(at playerDistance: Double) -> Double {
    let base = difficulty.values(at: playerDistance).waveSpacing
    let jitter = randomDouble(in: -config.spacingJitterFraction...config.spacingJitterFraction)
    return base * (1 + jitter)
  }

  mutating func makeWave(
    distanceAhead: Double,
    precedingGap: Double,
    playerDistance: Double,
    closingSpeed: Double
  ) -> LaneRushTrafficWave {
    let values = difficulty.values(at: playerDistance)
    let wantsDouble = randomDouble(in: 0...1) < values.doubleProbability
    var lanes: [LaneRushLane]
    var safeLane: LaneRushLane

    if wantsDouble {
      safeLane = randomLane()
      lanes = LaneRushLane.allCases.filter { $0 != safeLane }
    } else {
      let blocked = randomLane()
      lanes = [blocked]
      let options = LaneRushLane.allCases.filter { $0 != blocked }
      safeLane = options[randomInt(upperBound: options.count)]
    }

    if !LaneRushTrafficFairness.isReachable(
      from: previousSafeLane,
      to: safeLane,
      gap: precedingGap,
      closingSpeed: closingSpeed,
      reactionMargin: config.reactionMargin)
    {
      safeLane = previousSafeLane
      if wantsDouble {
        lanes = LaneRushLane.allCases.filter { $0 != safeLane }
      } else {
        let options = LaneRushLane.allCases.filter { $0 != safeLane }
        lanes = [options[randomInt(upperBound: options.count)]]
      }
    }

    let waveID = nextWaveID
    nextWaveID += 1
    let obstacles = lanes.map { lane -> LaneRushTrafficObstacle in
      defer { nextObstacleID += 1 }
      return LaneRushTrafficObstacle(
        id: nextObstacleID,
        lane: lane,
        appearance: LaneRushVehicleAppearance(
          color: LaneRushVehicleColor.allCases[
            randomInt(
              upperBound: LaneRushVehicleColor.allCases.count)],
          body: LaneRushVehicleBody.allCases[
            randomInt(
              upperBound: LaneRushVehicleBody.allCases.count)]))
    }
    previousSafeLane = safeLane
    return LaneRushTrafficWave(
      id: waveID,
      distanceAhead: distanceAhead,
      obstacles: obstacles,
      safeLane: safeLane)
  }

  private mutating func randomLane() -> LaneRushLane {
    LaneRushLane.allCases[randomInt(upperBound: LaneRushLane.allCases.count)]
  }

  private mutating func randomInt(upperBound: Int) -> Int {
    Int.random(in: 0..<upperBound, using: &rng)
  }

  private mutating func randomDouble(in range: ClosedRange<Double>) -> Double {
    Double.random(in: range, using: &rng)
  }
}
