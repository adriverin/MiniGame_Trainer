import Combine
import Foundation

struct LaneRushDebugOptions: Equatable {
  var showOverlay = false
  var disableCollisions = false
  var autoDrive = false
  var holdCollision = false
  var forceCenterCollision = false
  var freezeMotion = false
  var forcedDifficultyDistance: Double?
  var trafficSnapshotOffset: Double?

  static let none = LaneRushDebugOptions()
}

@MainActor
final class LaneRushTuningStore: ObservableObject {
  static let shared = LaneRushTuningStore()
  @Published var config = LaneRushGameConfig.reference
  @Published var debugOptions = LaneRushDebugOptions.none

  func resetToReference() {
    config = .reference
    debugOptions = .none
  }
}
