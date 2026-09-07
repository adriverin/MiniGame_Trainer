import Foundation

struct LaneRushGameConfig: Equatable {
  var maximumFrameDelta: TimeInterval = 1.0 / 15.0
  var maximumSimulationStep: TimeInterval = 1.0 / 240.0
  var oncomingFactor: Double = 4.25
  var trafficVisibleDistance: Double = 100
  var minimumGenerationDistance: Double = 280
  var generationLeadTime: TimeInterval = 1.35
  var spacingJitterFraction: Double = 0.08
  var reactionMargin: TimeInterval = 0.14
  var collisionDistance: Double = 18.181_818_181_8
  var playerHalfWidth: Double = 0.27
  var vehicleHalfWidth: Double = 0.27
  var longitudinalHalfExtent: Double = 2.2
  var trafficCullDistance: Double = 8
  var failureDelay: TimeInterval = 0.58
  var startingDistance: Double = 0
  var randomSeed: UInt64?

  static let reference = LaneRushGameConfig()
}

struct LaneRushTrafficDifficultyModel: Equatable {
  struct Anchor: Equatable {
    let distance: Double
    let spacing: Double
    let doubleProbability: Double
  }

  static let referenceAnchors: [Anchor] = [
    Anchor(distance: 0, spacing: 104, doubleProbability: 0.04),
    Anchor(distance: 250, spacing: 92, doubleProbability: 0.16),
    Anchor(distance: 500, spacing: 82, doubleProbability: 0.28),
    Anchor(distance: 750, spacing: 74, doubleProbability: 0.40),
    Anchor(distance: 1000, spacing: 68, doubleProbability: 0.48),
  ]

  let anchors: [Anchor]

  init(anchors: [Anchor] = Self.referenceAnchors) {
    self.anchors = anchors.sorted { $0.distance < $1.distance }
  }

  func values(at distance: Double) -> LaneRushTrafficDifficulty {
    guard let first = anchors.first, let last = anchors.last else {
      return LaneRushTrafficDifficulty(waveSpacing: 90, doubleProbability: 0.1)
    }
    let value = max(0, distance.isFinite ? distance : 0)
    if value <= first.distance {
      return LaneRushTrafficDifficulty(
        waveSpacing: first.spacing, doubleProbability: first.doubleProbability)
    }
    if value >= last.distance {
      return LaneRushTrafficDifficulty(
        waveSpacing: last.spacing, doubleProbability: last.doubleProbability)
    }
    for (lower, upper) in zip(anchors, anchors.dropFirst()) where value <= upper.distance {
      let progress = (value - lower.distance) / (upper.distance - lower.distance)
      return LaneRushTrafficDifficulty(
        waveSpacing: lower.spacing + (upper.spacing - lower.spacing) * progress,
        doubleProbability: lower.doubleProbability
          + (upper.doubleProbability - lower.doubleProbability) * progress)
    }
    return LaneRushTrafficDifficulty(
      waveSpacing: last.spacing, doubleProbability: last.doubleProbability)
  }
}
