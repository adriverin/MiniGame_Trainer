#if DEBUG
  import CoreGraphics

  /// Checkpoint A uses top-left coordinates: increasing depth always moves DOWN the screen.
  /// Ratios are measured from the source game image, excluding the surrounding video UI.
  struct LaneRushStaticRoadGeometry {
    let size: CGSize

    var horizonY: CGFloat { size.height * 0.67 }
    var bottomY: CGFloat { size.height }
    var playerGroundY: CGFloat { size.height * 0.94 }
    var playerDepth: CGFloat { (playerGroundY - horizonY) / (bottomY - horizonY) }
    var scoreCenter: CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.303) }

    func y(at depth: CGFloat) -> CGFloat {
      horizonY + (bottomY - horizonY) * bounded(depth)
    }

    func roadWidth(at depth: CGFloat) -> CGFloat {
      size.width * (0.42 + 1.30 * bounded(depth))
    }

    /// Lanes: -1, 0, 1. Dividers: -0.5, 0.5. Road edges: -1.5, 1.5.
    func point(lateral: CGFloat, depth: CGFloat) -> CGPoint {
      CGPoint(x: size.width / 2 + lateral * roadWidth(at: depth) / 3, y: y(at: depth))
    }

    var playerFrame: CGRect {
      playerFrame(lateral: 0)
    }

    func playerFrame(lateral: CGFloat) -> CGRect {
      let width = roadWidth(at: playerDepth) / 3 * 0.69
      let height = width / 1.20
      let centerX = LaneRushActorLaneProjection(road: self).position(
        lateral: lateral, depth: playerDepth
      ).x
      return CGRect(
        x: centerX - width / 2, y: playerGroundY - height, width: width, height: height)
    }

    private func bounded(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
  }

  /// Vehicle centers follow the road's lane spacing in the distance, then smoothly
  /// saturate near the player so foreground actors remain readable in the viewport.
  struct LaneRushActorLaneProjection {
    let road: LaneRushStaticRoadGeometry

    static let smoothSaturationStartFraction: CGFloat = 0.22
    static let smoothSaturationEndFraction: CGFloat = 0.34
    static let foregroundMaximumSpreadFraction: CGFloat = 0.30
    static let minimumVisibleBodyMarginFraction: CGFloat = 0.025

    func laneSpread(atDepth depth: CGFloat) -> CGFloat {
      let rawSpread = road.roadWidth(at: depth) / 3
      let width = road.size.width
      let start = width * Self.smoothSaturationStartFraction
      let end = width * Self.smoothSaturationEndFraction
      let maximum = width * Self.foregroundMaximumSpreadFraction

      guard rawSpread > start else { return rawSpread }
      guard rawSpread < end else { return maximum }

      let progress = (rawSpread - start) / (end - start)
      let eased = 1.5 * progress - 0.5 * progress * progress * progress
      return start + (maximum - start) * eased
    }

    func position(lateral: CGFloat, depth: CGFloat) -> CGPoint {
      CGPoint(
        x: road.size.width / 2 + lateral * laneSpread(atDepth: depth),
        y: road.y(at: depth))
    }
  }

  enum LaneRushVehicleDepth: String, CaseIterable {
    case far
    case mid
    case near

    var distanceAhead: CGFloat {
      switch self {
      case .far: 100
      case .mid: 86
      case .near: 50
      }
    }

    static func launchValue(arguments: [String] = CommandLine.arguments) -> Self? {
      guard let index = arguments.firstIndex(of: "-laneRushVehicleDepth"),
        arguments.indices.contains(index + 1)
      else { return nil }
      return Self(rawValue: arguments[index + 1].lowercased())
    }

  }

  enum LaneRushPlayerCheckpoint: Equatable {
    case lane(LaneRushLane)
    case transition(LaneRushLaneCommand)

    static func launchValue(arguments: [String] = CommandLine.arguments) -> Self? {
      if let index = arguments.firstIndex(of: "-laneRushPlayerLane"),
        arguments.indices.contains(index + 1),
        let lane = lane(named: arguments[index + 1])
      {
        return .lane(lane)
      }

      if let index = arguments.firstIndex(of: "-laneRushPlayerTransition"),
        arguments.indices.contains(index + 1)
      {
        switch arguments[index + 1].lowercased() {
        case "left": return .transition(.left)
        case "right": return .transition(.right)
        default: return nil
        }
      }

      return nil
    }

    var controller: LaneRushPlayerController {
      switch self {
      case .lane(let lane):
        return LaneRushPlayerController(lane: lane)
      case .transition(let command):
        var controller = LaneRushPlayerController()
        controller.command(command)
        controller.update(deltaTime: controller.config.laneChangeDuration / 2)
        return controller
      }
    }

    private static func lane(named value: String) -> LaneRushLane? {
      switch value.lowercased() {
      case "left": return .left
      case "center": return .center
      case "right": return .right
      default: return nil
      }
    }
  }

  enum LaneRushCheckpointLaunch {
    static var isEnabled: Bool {
      CommandLine.arguments.contains("-laneRushStaticRoad")
        || LaneRushVehicleDepth.launchValue() != nil
        || LaneRushPlayerCheckpoint.launchValue() != nil
        || LaneRushDynamicCheckpoint.launchValue() != nil
    }
  }

  struct LaneRushDynamicCheckpoint: Equatable {
    let forcedDistance: Double?

    static func launchValue(arguments: [String] = CommandLine.arguments) -> Self? {
      guard arguments.contains("-laneRushDynamicMotion") else { return nil }
      guard let index = arguments.firstIndex(of: "-laneRushForceDistance"),
        arguments.indices.contains(index + 1),
        let distance = Double(arguments[index + 1]), distance.isFinite
      else {
        return Self(forcedDistance: nil)
      }
      return Self(forcedDistance: max(0, distance))
    }

    var simulation: LaneRushDynamicSimulation {
      LaneRushDynamicSimulation(
        distanceMeters: forcedDistance ?? 0,
        startsPaused: forcedDistance != nil)
    }
  }

  struct LaneRushPlayerPresentation: Equatable {
    let frame: CGRect
    let leanDegrees: CGFloat
    let logicalLateral: CGFloat
  }

  extension LaneRushPlayerController {
    func presentation(on road: LaneRushStaticRoadGeometry) -> LaneRushPlayerPresentation {
      LaneRushPlayerPresentation(
        frame: road.playerFrame(lateral: lateralPosition),
        leanDegrees: leanDegrees,
        logicalLateral: lateralPosition)
    }
  }

  struct LaneRushRoadMarkingProjection {
    let road: LaneRushStaticRoadGeometry

    static let visibleDistance: Double = 100
    static let dashLengthMeters: Double = 8

    func depth(distanceAhead: Double) -> CGFloat {
      let progress = min(1, max(0, 1 - distanceAhead / Self.visibleDistance))
      let value = CGFloat(progress)
      return value * value * value
    }

    func depthRange(distanceAhead: Double) -> ClosedRange<CGFloat>? {
      guard distanceAhead > 0,
        distanceAhead - Self.dashLengthMeters < Self.visibleDistance
      else { return nil }
      let far = depth(distanceAhead: distanceAhead)
      let near = depth(distanceAhead: max(0, distanceAhead - Self.dashLengthMeters))
      return far...near
    }
  }

  /// A single bounded transform shared by every deterministic Checkpoint B state.
  /// Position is anchored at the traffic car's front bumper on the road surface.
  struct LaneRushVehicleProjection {
    let road: LaneRushStaticRoadGeometry

    static let visibleDistance: CGFloat = 100
    static let nearDepth: CGFloat = 0.50
    static let farWidthFraction: CGFloat = 0.090
    static let nearWidthFraction: CGFloat = 0.247
    static let maximumLaneOccupancy: CGFloat = 0.88

    var maximumVehicleScale: CGFloat {
      Self.nearWidthFraction / Self.farWidthFraction
    }

    func normalizedDepth(distanceAhead: CGFloat) -> CGFloat {
      bounded(1 - distanceAhead / Self.visibleDistance)
    }

    func position(lane: CGFloat, distanceAhead: CGFloat) -> CGPoint {
      LaneRushActorLaneProjection(road: road).position(
        lateral: lane, depth: normalizedDepth(distanceAhead: distanceAhead))
    }

    func vehicleScale(atDepth depth: CGFloat) -> CGFloat {
      vehicleWidth(atDepth: depth) / (road.size.width * Self.farWidthFraction)
    }

    func vehicleWidth(atDepth depth: CGFloat) -> CGFloat {
      let progress = scaleProgress(atDepth: depth)
      let eased = sqrt(progress)
      let fraction =
        Self.farWidthFraction
        + (Self.nearWidthFraction - Self.farWidthFraction) * eased
      return road.size.width * fraction
    }

    func vehicleHeight(atDepth depth: CGFloat) -> CGFloat {
      let progress = scaleProgress(atDepth: depth)
      let heightToWidth = 0.70 + 0.65 * progress
      return vehicleWidth(atDepth: depth) * heightToWidth
    }

    func laneWidth(atDepth depth: CGFloat) -> CGFloat {
      road.roadWidth(at: depth) / 3
    }

    func vehicleFrame(lane: CGFloat, distanceAhead: CGFloat) -> CGRect {
      let depth = normalizedDepth(distanceAhead: distanceAhead)
      let position = position(lane: lane, distanceAhead: distanceAhead)
      let width = vehicleWidth(atDepth: depth)
      let height = vehicleHeight(atDepth: depth)
      return CGRect(
        x: position.x - width / 2, y: position.y - height,
        width: width, height: height)
    }

    private func scaleProgress(atDepth depth: CGFloat) -> CGFloat {
      min(1, bounded(depth) / Self.nearDepth)
    }

    private func bounded(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
  }
#endif
