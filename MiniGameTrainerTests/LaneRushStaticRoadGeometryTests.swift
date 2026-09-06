import XCTest

@testable import MiniGameTrainer

final class LaneRushStaticRoadGeometryTests: XCTestCase {
  func testRoadRunsDownwardAndCoversBottomAcrossPhoneSizes() {
    for size in [
      CGSize(width: 375, height: 667), CGSize(width: 420, height: 912),
      CGSize(width: 440, height: 956),
    ] {
      let road = LaneRushStaticRoadGeometry(size: size)
      XCTAssertGreaterThan(road.horizonY, size.height / 2)
      XCTAssertGreaterThan(road.playerFrame.minY, road.horizonY)
      XCTAssertGreaterThan(road.y(at: 1), road.y(at: 0))
      XCTAssertEqual(road.y(at: 1), size.height)
      XCTAssertLessThan(road.point(lateral: -1.5, depth: 1).x, 0)
      XCTAssertGreaterThan(road.point(lateral: 1.5, depth: 1).x, size.width)
      XCTAssertLessThan(road.playerFrame.maxY, size.height)
      XCTAssertLessThan(road.scoreCenter.y, road.horizonY)
    }
  }

  func testLaneEnvelopeWidensContinuouslyAndStaysBounded() {
    let road = LaneRushStaticRoadGeometry(size: .init(width: 420, height: 912))
    var previousWidth: CGFloat = 0
    var previousY: CGFloat = 0
    for index in 0...100 {
      let depth = CGFloat(index) / 100
      let left = road.point(lateral: -1.5, depth: depth).x
      let right = road.point(lateral: 1.5, depth: depth).x
      XCTAssertGreaterThan(right - left, previousWidth)
      XCTAssertGreaterThan(road.y(at: depth), previousY)
      for lane: CGFloat in [-1, 0, 1] {
        let x = road.point(lateral: lane, depth: depth).x
        XCTAssertGreaterThan(x, left)
        XCTAssertLessThan(x, right)
      }
      previousWidth = right - left
      previousY = road.y(at: depth)
    }
    XCTAssertEqual(road.point(lateral: 1, depth: -100), road.point(lateral: 1, depth: 0))
    XCTAssertEqual(road.point(lateral: 1, depth: 100), road.point(lateral: 1, depth: 1))
  }

  func testPlayerIsForegroundSizedAndFitsItsLaneAtGround() {
    let road = LaneRushStaticRoadGeometry(size: .init(width: 420, height: 912))
    let depth = (road.playerGroundY - road.horizonY) / (road.bottomY - road.horizonY)
    XCTAssertGreaterThan(road.playerFrame.width, road.size.width * 0.30)
    XCTAssertLessThan(road.playerFrame.width, road.size.width * 0.37)
    XCTAssertGreaterThan(road.playerFrame.width, road.playerFrame.height)
    XCTAssertGreaterThan(road.playerFrame.minX, road.point(lateral: -0.5, depth: depth).x)
    XCTAssertLessThan(road.playerFrame.maxX, road.point(lateral: 0.5, depth: depth).x)
  }
}
