import XCTest

@testable import MiniGameTrainer

final class LaneRushCollisionAndFailureTests: XCTestCase {
  func testSameLaneAtCollisionDepthCollidesAndAdjacentLaneDoesNot() {
    let hit = makeLogic(obstacleLane: .center, distance: 18.2)
    hit.update(deltaTime: 0.001)
    XCTAssertEqual(hit.state, .failing)
    XCTAssertEqual(hit.drainEvents(), [.collided])

    let miss = makeLogic(obstacleLane: .left, distance: 18.2)
    miss.update(deltaTime: 0.001)
    XCTAssertEqual(miss.state, .running)
    XCTAssertTrue(miss.drainEvents().isEmpty)
  }

  func testClearLateralNearMissSurvives() {
    var player = LaneRushPlayerController(lane: .right)
    XCTAssertFalse(player.command(.right))
    let logic = makeLogic(obstacleLane: .center, distance: 18.2)
    logic.setPlayerForTesting(player)
    logic.update(deltaTime: 0.01)
    XCTAssertEqual(logic.state, .running)
  }

  func testMidTransitionLogicalOverlapCollides() {
    var player = LaneRushPlayerController()
    XCTAssertTrue(player.command(.left))
    player.update(deltaTime: player.config.laneChangeDuration / 2)
    XCTAssertEqual(player.lateralPosition, -0.5, accuracy: 0.000_001)
    let logic = makeLogic(obstacleLane: .left, distance: 18.2)
    logic.setPlayerForTesting(player)
    logic.update(deltaTime: 0.001)
    XCTAssertEqual(logic.state, .failing)
  }

  func testSweptCollisionCatchesHighSpeedCrossing() {
    var config = LaneRushGameConfig.reference
    config.startingDistance = 1000
    let logic = LaneRushGameLogic(config: config)
    logic.replaceTrafficForTesting([wave(lane: .center, distance: 30)])
    logic.update(deltaTime: config.maximumFrameDelta)
    XCTAssertEqual(logic.state, .failing)
    XCTAssertLessThan(logic.trafficWaves[0].distanceAhead, 30)
  }

  func testTwoSimultaneousImpactsCompleteExactlyOnce() {
    let logic = LaneRushGameLogic()
    logic.replaceTrafficForTesting([
      LaneRushTrafficWave(
        id: 1,
        distanceAhead: 18.2,
        obstacles: [
          obstacle(id: 1, lane: .center),
          obstacle(id: 2, lane: .center),
        ],
        safeLane: .left)
    ])
    logic.update(deltaTime: 0.001)
    XCTAssertEqual(logic.drainEvents(), [.collided])
    for _ in 0..<10 { logic.update(deltaTime: 0.1) }
    XCTAssertEqual(logic.drainEvents(), [.finished])
    logic.update(deltaTime: 10)
    XCTAssertTrue(logic.drainEvents().isEmpty)
  }

  func testFailureFreezesScoreTrafficAndInputAndClearsPendingCommand() {
    let logic = makeLogic(obstacleLane: .center, distance: 18.2)
    XCTAssertTrue(logic.requestLaneChange(.left))
    XCTAssertTrue(logic.requestLaneChange(.right))
    XCTAssertNotNil(logic.player.pendingCommand)
    logic.update(deltaTime: 0.001)
    XCTAssertNil(logic.player.pendingCommand)
    XCTAssertFalse(logic.requestLaneChange(.right))
    let frozenDistance = logic.distanceMeters
    let frozenTraffic = logic.trafficWaves
    let frozenPlayer = logic.player
    logic.update(deltaTime: 0.2)
    XCTAssertEqual(logic.distanceMeters, frozenDistance)
    XCTAssertEqual(logic.trafficWaves, frozenTraffic)
    XCTAssertEqual(logic.player, frozenPlayer)
  }

  func testFailureDelayIsPauseSafe() {
    let logic = makeLogic(obstacleLane: .center, distance: 18.2)
    logic.update(deltaTime: 0.001)
    logic.update(deltaTime: 0.2)
    let elapsed = logic.failureElapsed
    logic.pause()
    XCTAssertEqual(logic.state, .pausedFailing)
    logic.update(deltaTime: 100)
    XCTAssertEqual(logic.failureElapsed, elapsed)
    logic.resume()
    XCTAssertEqual(logic.state, .failing)
    for _ in 0..<10 { logic.update(deltaTime: 0.1) }
    XCTAssertEqual(logic.state, .finished)
  }

  private func makeLogic(
    obstacleLane: LaneRushLane,
    distance: Double
  ) -> LaneRushGameLogic {
    let logic = LaneRushGameLogic()
    logic.replaceTrafficForTesting([wave(lane: obstacleLane, distance: distance)])
    return logic
  }

  private func wave(lane: LaneRushLane, distance: Double) -> LaneRushTrafficWave {
    LaneRushTrafficWave(
      id: 1,
      distanceAhead: distance,
      obstacles: [obstacle(id: 1, lane: lane)],
      safeLane: lane == .center ? .left : .center)
  }

  private func obstacle(id: Int, lane: LaneRushLane) -> LaneRushTrafficObstacle {
    LaneRushTrafficObstacle(id: id, lane: lane, appearance: .orangeCoupe)
  }
}
