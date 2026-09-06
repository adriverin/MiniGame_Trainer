import XCTest

@testable import MiniGameTrainer

final class LaneRushPlayerControlTests: XCTestCase {
  func testInitialLaneIsCenter() {
    let player = LaneRushPlayerController()
    XCTAssertEqual(player.lane, .center)
    XCTAssertEqual(player.lane.rawValue, 1)
    XCTAssertEqual(player.lateralPosition, 0)
    XCTAssertNil(player.transition)
  }

  func testTapsAndHorizontalSwipesProduceOneCommand() throws {
    let gestures = LaneRushGestureInterpreter()
    let tapLeft = gestures.command(
      start: CGPoint(x: 40, y: 100), end: CGPoint(x: 42, y: 101),
      gameplayWidth: 420)
    let tapRight = gestures.command(
      start: CGPoint(x: 380, y: 100), end: CGPoint(x: 378, y: 101),
      gameplayWidth: 420)
    let swipeLeft = gestures.command(
      start: CGPoint(x: 380, y: 100), end: CGPoint(x: 280, y: 102),
      gameplayWidth: 420)
    let swipeRight = gestures.command(
      start: CGPoint(x: 40, y: 100), end: CGPoint(x: 140, y: 102),
      gameplayWidth: 420)
    let vertical = gestures.command(
      start: CGPoint(x: 300, y: 100), end: CGPoint(x: 305, y: 180),
      gameplayWidth: 420)

    XCTAssertEqual(tapLeft, .left)
    XCTAssertEqual(tapRight, .right)
    XCTAssertEqual(
      swipeLeft, .left,
      "A recognized swipe must not also execute the right-side tap"
    )
    XCTAssertEqual(
      swipeRight, .right,
      "A recognized swipe must not also execute the left-side tap"
    )
    XCTAssertNil(vertical)

    for (command, expectedLane) in [
      (tapLeft, LaneRushLane.left), (tapRight, .right),
      (swipeLeft, .left), (swipeRight, .right),
    ] {
      var player = LaneRushPlayerController()
      XCTAssertTrue(player.command(try XCTUnwrap(command)))
      player.update(deltaTime: player.config.laneChangeDuration)
      XCTAssertEqual(player.lane, expectedLane)
    }

    var verticalPlayer = LaneRushPlayerController()
    if let vertical { verticalPlayer.command(vertical) }
    XCTAssertEqual(verticalPlayer.lane, .center)
    XCTAssertNil(verticalPlayer.transition)
  }

  func testBoundariesDoNotWrapOrSkipLanes() {
    var left = LaneRushPlayerController(lane: .left)
    XCTAssertFalse(left.command(.left))
    XCTAssertEqual(left.lane, .left)
    XCTAssertNil(left.transition)

    var right = LaneRushPlayerController(lane: .right)
    XCTAssertFalse(right.command(.right))
    XCTAssertEqual(right.lane, .right)
    XCTAssertNil(right.transition)

    var center = LaneRushPlayerController()
    XCTAssertTrue(center.command(.right))
    XCTAssertEqual(center.transition?.source, .center)
    XCTAssertEqual(center.transition?.target, .right)
  }

  func testInterpolationStartsAtSourcePassesBetweenAndEndsExactlyAtTarget() {
    let road = LaneRushStaticRoadGeometry(size: CGSize(width: 420, height: 912))
    var player = LaneRushPlayerController()
    let start = player.presentation(on: road)

    XCTAssertTrue(player.command(.left))
    XCTAssertEqual(player.lateralPosition, 0)
    player.update(deltaTime: player.config.laneChangeDuration / 2)
    let midpoint = player.presentation(on: road)
    XCTAssertGreaterThan(player.lateralPosition, -1)
    XCTAssertLessThan(player.lateralPosition, 0)

    player.update(deltaTime: player.config.laneChangeDuration / 2)
    let end = player.presentation(on: road)
    XCTAssertEqual(player.lane, .left)
    XCTAssertEqual(player.lateralPosition, -1)
    XCTAssertNil(player.transition)
    XCTAssertEqual(start.frame.minY, midpoint.frame.minY, accuracy: 0.0001)
    XCTAssertEqual(midpoint.frame.minY, end.frame.minY, accuracy: 0.0001)
    XCTAssertEqual(start.frame.width, midpoint.frame.width, accuracy: 0.0001)
    XCTAssertEqual(midpoint.frame.width, end.frame.width, accuracy: 0.0001)
    XCTAssertEqual(start.frame.height, midpoint.frame.height, accuracy: 0.0001)
    XCTAssertEqual(midpoint.frame.height, end.frame.height, accuracy: 0.0001)
  }

  func testOppositePendingCommandRunsImmediatelyAfterActiveTransition() {
    var player = LaneRushPlayerController()
    XCTAssertTrue(player.command(.left))
    XCTAssertTrue(player.command(.right))
    player.update(deltaTime: player.config.laneChangeDuration)
    XCTAssertEqual(player.lane, .left)
    XCTAssertEqual(player.transition?.source, .left)
    XCTAssertEqual(player.transition?.target, .center)
    XCTAssertEqual(player.lateralPosition, -1)

    player.update(deltaTime: player.config.laneChangeDuration)
    XCTAssertEqual(player.lane, .center)
    XCTAssertEqual(player.lateralPosition, 0)
    XCTAssertNil(player.transition)
  }

  func testTwoRapidRightCommandsTravelLeftThroughCenter() {
    var player = LaneRushPlayerController(lane: .left)
    XCTAssertTrue(player.command(.right))
    XCTAssertTrue(player.command(.right))
    player.update(deltaTime: player.config.laneChangeDuration)
    XCTAssertEqual(player.lane, .center)
    XCTAssertEqual(player.transition?.target, .right)
    XCTAssertEqual(player.lateralPosition, 0)

    player.update(deltaTime: player.config.laneChangeDuration)
    XCTAssertEqual(player.lane, .right)
    XCTAssertEqual(player.lateralPosition, 1)
    XCTAssertNil(player.transition)
  }

  func testInvalidPendingCommandIsDiscardedWithoutDelay() {
    var player = LaneRushPlayerController()
    XCTAssertTrue(player.command(.left))
    XCTAssertFalse(player.command(.left))
    XCTAssertNil(player.pendingCommand)
    player.update(deltaTime: player.config.laneChangeDuration)
    XCTAssertEqual(player.lane, .left)
    XCTAssertNil(player.transition)
    XCTAssertTrue(player.command(.right))
    XCTAssertEqual(player.transition?.target, .center)
  }

  func testPendingBufferHoldsOnlyOneValidCommand() {
    var player = LaneRushPlayerController()
    XCTAssertTrue(player.command(.left))
    XCTAssertTrue(player.command(.right))
    XCTAssertFalse(player.command(.right))
    XCTAssertEqual(player.pendingCommand, .right)
  }

  func testLeanHasDirectionAndReturnsPreciselyToNeutral() {
    var left = LaneRushPlayerController()
    XCTAssertEqual(left.leanDegrees, 0)
    left.command(.left)
    left.update(deltaTime: left.config.laneChangeDuration / 2)
    XCTAssertLessThan(left.leanDegrees, 0)
    XCTAssertLessThanOrEqual(abs(left.leanDegrees), left.config.maximumLeanDegrees)
    left.update(deltaTime: left.config.laneChangeDuration / 2)
    XCTAssertEqual(left.leanDegrees, 0)

    var right = LaneRushPlayerController()
    right.command(.right)
    right.update(deltaTime: right.config.laneChangeDuration / 2)
    XCTAssertGreaterThan(right.leanDegrees, 0)
    XCTAssertLessThanOrEqual(abs(right.leanDegrees), right.config.maximumLeanDegrees)
    right.update(deltaTime: right.config.laneChangeDuration / 2)
    XCTAssertEqual(right.leanDegrees, 0)
  }

  func testProjectedPlayerLanesAreSymmetricFixedAndInsideViewport() {
    let road = LaneRushStaticRoadGeometry(size: CGSize(width: 420, height: 912))
    let frames = LaneRushLane.allCases.map { road.playerFrame(lateral: $0.lateral) }
    XCTAssertEqual(frames[1].midX, road.size.width / 2, accuracy: 0.0001)
    XCTAssertEqual(
      frames[1].midX - frames[0].midX,
      frames[2].midX - frames[1].midX,
      accuracy: 0.0001
    )

    for (lane, frame) in zip(LaneRushLane.allCases, frames) {
      XCTAssertEqual(frame.minY, frames[0].minY, accuracy: 0.0001)
      XCTAssertEqual(frame.width, frames[0].width, accuracy: 0.0001)
      XCTAssertGreaterThan(frame.minX, 0)
      XCTAssertLessThan(frame.maxX, road.size.width)
      XCTAssertEqual(
        frame.midX,
        LaneRushActorLaneProjection(road: road).position(
          lateral: lane.lateral, depth: road.playerDepth
        ).x,
        accuracy: 0.0001)
    }
  }

  func testDebugCheckpointArgumentsSelectCompletedAndMidTransitionStates() {
    XCTAssertEqual(
      LaneRushPlayerCheckpoint.launchValue(
        arguments: ["app", "-laneRushPlayerLane", "left"]),
      .lane(.left)
    )
    XCTAssertEqual(
      LaneRushPlayerCheckpoint.launchValue(
        arguments: ["app", "-laneRushPlayerLane", "CENTER"]),
      .lane(.center)
    )
    XCTAssertEqual(
      LaneRushPlayerCheckpoint.launchValue(
        arguments: ["app", "-laneRushPlayerTransition", "right"]),
      .transition(.right)
    )
    XCTAssertNil(LaneRushPlayerCheckpoint.launchValue(arguments: ["app"]))
  }
}
