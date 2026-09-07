import CoreGraphics
import Foundation

enum LaneRushVehicleColor: Int, CaseIterable, Equatable {
  case orange
  case cream
  case blue
  case red

  var bodyHex: UInt32 {
    switch self {
    case .orange: 0xED6329
    case .cream: 0xE5D7B7
    case .blue: 0x4963A8
    case .red: 0xC84C5A
    }
  }

  var darkHex: UInt32 {
    switch self {
    case .orange: 0xB83F1D
    case .cream: 0xB9A989
    case .blue: 0x34477D
    case .red: 0x913641
    }
  }
}

enum LaneRushVehicleBody: Int, CaseIterable, Equatable {
  case coupe
  case utility
}

struct LaneRushVehicleAppearance: Equatable {
  let color: LaneRushVehicleColor
  let body: LaneRushVehicleBody

  static let orangeCoupe = LaneRushVehicleAppearance(color: .orange, body: .coupe)
}

struct LaneRushTrafficObstacle: Identifiable, Equatable {
  let id: Int
  let lane: LaneRushLane
  let appearance: LaneRushVehicleAppearance
}

struct LaneRushTrafficWave: Identifiable, Equatable {
  let id: Int
  var distanceAhead: Double
  let obstacles: [LaneRushTrafficObstacle]
  let safeLane: LaneRushLane

  var blockedLanes: Set<LaneRushLane> { Set(obstacles.map(\.lane)) }
  var isDouble: Bool { obstacles.count == 2 }
}

struct LaneRushTrafficDifficulty: Equatable {
  let waveSpacing: Double
  let doubleProbability: Double
}

enum LaneRushGameState: Equatable {
  case running
  case paused
  case failing
  case pausedFailing
  case finished
}

enum LaneRushGameEvent: Equatable {
  case collided
  case finished
}

struct LaneRushSessionSummary: Equatable {
  let distance: Int
  let carsPassed: Int
  let laneChanges: Int
  let duration: TimeInterval
  let maximumSpeed: Double
}

struct LaneRushRenderedVehicle: Identifiable, Equatable {
  let id: Int
  let lane: LaneRushLane
  let distanceAhead: Double
  let appearance: LaneRushVehicleAppearance
}

struct LaneRushRenderState: Equatable {
  let score: Int
  let roadMarkings: [Double]
  let player: LaneRushPlayerController
  let vehicles: [LaneRushRenderedVehicle]
  let state: LaneRushGameState
  let failureProgress: CGFloat
}
