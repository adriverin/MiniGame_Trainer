import XCTest

@testable import MiniGameTrainer

final class LaneRushVehicleProjectionTests: XCTestCase {
  private let size = CGSize(width: 420, height: 912)

  func testScaleIsMonotonicFiniteAndBounded() {
    let projection = makeProjection()
    let far = projection.vehicleScale(atDepth: 0)
    let mid = projection.vehicleScale(atDepth: 0.14)
    let near = projection.vehicleScale(atDepth: LaneRushVehicleProjection.nearDepth)
    XCTAssertLessThan(far, mid)
    XCTAssertLessThan(mid, near)

    var previous = far
    for index in 0...100 {
      let scale = projection.vehicleScale(atDepth: CGFloat(index) / 100)
      XCTAssertTrue(scale.isFinite)
      XCTAssertGreaterThanOrEqual(scale, previous)
      XCTAssertLessThanOrEqual(scale, projection.maximumVehicleScale)
      previous = scale
    }
  }

  func testLogicalDistanceMapsToExpectedOrderedDepths() {
    let projection = makeProjection()
    let far = projection.normalizedDepth(distanceAhead: LaneRushVehicleDepth.far.distanceAhead)
    let mid = projection.normalizedDepth(distanceAhead: LaneRushVehicleDepth.mid.distanceAhead)
    let near = projection.normalizedDepth(distanceAhead: LaneRushVehicleDepth.near.distanceAhead)
    XCTAssertEqual(far, 0, accuracy: 0.0001)
    XCTAssertEqual(mid, 0.14, accuracy: 0.0001)
    XCTAssertEqual(near, 0.50, accuracy: 0.0001)
    XCTAssertLessThan(far, mid)
    XCTAssertLessThan(mid, near)
  }

  func testLaneCentersAreCenteredAndSymmetric() {
    let projection = makeProjection()
    for state in LaneRushVehicleDepth.allCases {
      let left = projection.position(lane: -1, distanceAhead: state.distanceAhead)
      let center = projection.position(lane: 0, distanceAhead: state.distanceAhead)
      let right = projection.position(lane: 1, distanceAhead: state.distanceAhead)
      XCTAssertEqual(center.x, size.width / 2, accuracy: 0.0001)
      XCTAssertEqual(center.x - left.x, right.x - center.x, accuracy: 0.0001)
      XCTAssertEqual(left.y, center.y, accuracy: 0.0001)
      XCTAssertEqual(center.y, right.y, accuracy: 0.0001)
    }
  }

  func testVehicleWidthStaysInsideItsProjectedLane() {
    let projection = makeProjection()
    for index in 0...100 {
      let depth = CGFloat(index) / 100
      let width = projection.vehicleWidth(atDepth: depth)
      let laneWidth = projection.laneWidth(atDepth: depth)
      XCTAssertLessThanOrEqual(
        width / laneWidth,
        LaneRushVehicleProjection.maximumLaneOccupancy,
        "Depth \(depth) exceeds the configured lane occupancy")
    }

    for state in [LaneRushVehicleDepth.far, .mid] {
      for lane: CGFloat in [-1, 1] {
        let frame = projection.vehicleFrame(lane: lane, distanceAhead: state.distanceAhead)
        let depth = projection.normalizedDepth(distanceAhead: state.distanceAhead)
        let laneLeft = projection.road.point(lateral: lane - 0.5, depth: depth).x
        let laneRight = projection.road.point(lateral: lane + 0.5, depth: depth).x
        XCTAssertGreaterThan(frame.minX, laneLeft)
        XCTAssertLessThan(frame.maxX, laneRight)
      }
    }
  }

  func testLaunchArgumentSelectsOnlyNamedDepthStates() {
    XCTAssertEqual(
      LaneRushVehicleDepth.launchValue(arguments: ["app", "-laneRushVehicleDepth", "far"]),
      .far)
    XCTAssertEqual(
      LaneRushVehicleDepth.launchValue(arguments: ["app", "-laneRushVehicleDepth", "MID"]),
      .mid)
    XCTAssertNil(
      LaneRushVehicleDepth.launchValue(arguments: ["app", "-laneRushVehicleDepth", "other"]))
    XCTAssertNil(LaneRushVehicleDepth.launchValue(arguments: ["app"]))
  }

  private func makeProjection() -> LaneRushVehicleProjection {
    LaneRushVehicleProjection(road: LaneRushStaticRoadGeometry(size: size))
  }
}
