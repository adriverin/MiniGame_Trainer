import XCTest

@testable import MiniGameTrainer

final class LaneRushActorLaneProjectionTests: XCTestCase {
  private let size = CGSize(width: 420, height: 912)

  func testForegroundCentersAreSymmetricAndPlayerBodyRemainsVisible() {
    let road = LaneRushStaticRoadGeometry(size: size)
    let projection = LaneRushActorLaneProjection(road: road)
    let left = projection.position(lateral: -1, depth: road.playerDepth)
    let center = projection.position(lateral: 0, depth: road.playerDepth)
    let right = projection.position(lateral: 1, depth: road.playerDepth)

    XCTAssertEqual(left.x, size.width * 0.20, accuracy: 0.0001)
    XCTAssertEqual(center.x, size.width * 0.50, accuracy: 0.0001)
    XCTAssertEqual(right.x, size.width * 0.80, accuracy: 0.0001)
    XCTAssertEqual(center.x - left.x, right.x - center.x, accuracy: 0.0001)

    let allowedMargin = size.width * LaneRushActorLaneProjection.minimumVisibleBodyMarginFraction
    for lane in LaneRushLane.allCases {
      let frame = road.playerFrame(lateral: lane.lateral)
      XCTAssertGreaterThanOrEqual(frame.minX, allowedMargin)
      XCTAssertLessThanOrEqual(frame.maxX, size.width - allowedMargin)
    }
  }

  func testLaneSpreadIsFiniteMonotonicAndBoundedAcrossDepth() {
    let projection = makeProjection()
    let maximum = size.width * LaneRushActorLaneProjection.foregroundMaximumSpreadFraction
    var previous: CGFloat = 0

    for index in 0...1000 {
      let depth = CGFloat(index) / 1000
      let spread = projection.laneSpread(atDepth: depth)
      XCTAssertTrue(spread.isFinite)
      XCTAssertGreaterThanOrEqual(spread, 0)
      XCTAssertGreaterThanOrEqual(spread, previous)
      XCTAssertLessThanOrEqual(spread, maximum)

      let left = projection.position(lateral: -1, depth: depth)
      let center = projection.position(lateral: 0, depth: depth)
      let right = projection.position(lateral: 1, depth: depth)
      XCTAssertEqual(center.x, size.width / 2, accuracy: 0.0001)
      XCTAssertEqual(center.x - left.x, right.x - center.x, accuracy: 0.0001)
      previous = spread
    }
  }

  func testLaneSpreadSaturationIsContinuousWithoutAClampCorner() {
    let projection = makeProjection()
    let step: CGFloat = 1 / 2000
    let spreads = (0...2000).map {
      projection.laneSpread(atDepth: CGFloat($0) * step)
    }
    let maximumRawStep = size.width * (1.30 / 3) * step + 0.0001

    for index in 1..<spreads.count {
      XCTAssertLessThanOrEqual(spreads[index] - spreads[index - 1], maximumRawStep)
    }

    for index in 2..<spreads.count {
      let previousStep = spreads[index - 1] - spreads[index - 2]
      let currentStep = spreads[index] - spreads[index - 1]
      XCTAssertLessThan(abs(currentStep - previousStep), 0.002)
    }
  }

  func testFarAndMidUseRawRoadSpreadAndNearUsesBoundedSpread() {
    let road = LaneRushStaticRoadGeometry(size: size)
    let projection = LaneRushActorLaneProjection(road: road)

    for depth: CGFloat in [0, 0.14] {
      XCTAssertEqual(
        projection.laneSpread(atDepth: depth),
        road.roadWidth(at: depth) / 3,
        accuracy: 0.0001)
    }
    XCTAssertEqual(
      projection.laneSpread(atDepth: 0.50),
      size.width * LaneRushActorLaneProjection.foregroundMaximumSpreadFraction,
      accuracy: 0.0001
    )
  }

  func testPlayerAndTrafficShareTheSameLaneCentersAtPlayerDepth() {
    let road = LaneRushStaticRoadGeometry(size: size)
    let actorProjection = LaneRushActorLaneProjection(road: road)
    let trafficProjection = LaneRushVehicleProjection(road: road)
    let distanceAhead = LaneRushVehicleProjection.visibleDistance * (1 - road.playerDepth)

    for lane: CGFloat in [-1, 0, 1] {
      XCTAssertEqual(
        trafficProjection.position(lane: lane, distanceAhead: distanceAhead),
        actorProjection.position(lateral: lane, depth: road.playerDepth)
      )
    }
  }

  private func makeProjection() -> LaneRushActorLaneProjection {
    LaneRushActorLaneProjection(road: LaneRushStaticRoadGeometry(size: size))
  }
}
