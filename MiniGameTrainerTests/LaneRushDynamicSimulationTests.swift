import XCTest

@testable import MiniGameTrainer

final class LaneRushDynamicSimulationTests: XCTestCase {
  func testDistanceStartsAtZeroIncreasesAndDisplayedScoreFloors() {
    var simulation = LaneRushDynamicSimulation()
    XCTAssertEqual(simulation.distanceMeters, 0)
    XCTAssertEqual(simulation.displayedDistance, 0)

    simulation.advance(deltaTime: 1.0 / 60.0)
    XCTAssertGreaterThan(simulation.distanceMeters, 0)

    let forced = LaneRushDynamicSimulation(distanceMeters: 249.99, startsPaused: true)
    XCTAssertEqual(forced.displayedDistance, 249)
  }

  func testReferenceSpeedAnchorsAreMonotonicAndUncappedThroughOneKilometre() {
    let model = LaneRushDifficultyModel.reference
    let anchors: [(distance: Double, speed: Double)] = [
      (0, 15), (150, 20.7), (250, 24.5), (500, 34),
      (750, 43.5), (1000, 53),
    ]

    var previous = -Double.infinity
    for anchor in anchors {
      let speed = model.forwardSpeed(at: anchor.distance)
      XCTAssertEqual(speed, anchor.speed, accuracy: 0.000_001)
      XCTAssertGreaterThan(speed, previous)
      previous = speed
    }
    XCTAssertGreaterThan(model.forwardSpeed(at: 1100), anchors.last!.speed)
  }

  func testScoreTrajectoryMatchesMeasuredSourceMilestones() {
    let source: [(time: Double, distance: Double)] = [
      (8.5, 148), (13, 251), (19, 421),
      (25, 632), (31, 888), (34, 1020),
    ]
    var simulation = LaneRushDynamicSimulation()
    var elapsed = 0.0
    let step = 1.0 / 120.0

    for milestone in source {
      while elapsed + step / 2 < milestone.time {
        simulation.advance(deltaTime: step)
        elapsed += step
      }
      XCTAssertEqual(
        simulation.distanceMeters, milestone.distance,
        accuracy: milestone.distance * 0.025,
        "Trajectory mismatch at \(milestone.time) seconds")
    }
  }

  func testPauseFreezesEveryDynamicStateAndResumeDoesNotCatchUp() {
    var simulation = LaneRushDynamicSimulation()
    XCTAssertTrue(simulation.command(.left))
    simulation.update(at: 10)
    simulation.update(at: 10.05)
    XCTAssertNotNil(simulation.player.transition)
    simulation.pause()
    let frozen = simulation

    simulation.update(at: 1_000)
    XCTAssertEqual(simulation.distanceMeters, frozen.distanceMeters)
    XCTAssertEqual(simulation.roadMarkings, frozen.roadMarkings)
    XCTAssertEqual(simulation.trafficDistanceAhead, frozen.trafficDistanceAhead)
    XCTAssertEqual(simulation.player, frozen.player)

    simulation.resume(at: 1_000)
    simulation.update(at: 1_000)
    XCTAssertEqual(simulation.distanceMeters, frozen.distanceMeters)
    XCTAssertEqual(simulation.roadMarkings, frozen.roadMarkings)
    XCTAssertEqual(simulation.trafficDistanceAhead, frozen.trafficDistanceAhead)
    XCTAssertEqual(simulation.player, frozen.player)

    simulation.update(at: 1_000.05)
    XCTAssertGreaterThan(simulation.distanceMeters, frozen.distanceMeters)
    XCTAssertNotEqual(simulation.roadMarkings, frozen.roadMarkings)
    XCTAssertLessThan(simulation.trafficDistanceAhead, frozen.trafficDistanceAhead)
    XCTAssertNotEqual(simulation.player, frozen.player)
  }

  func testRoadMarkingsRecycleIndividuallyWithConstantWorldSpacing() {
    var flow = LaneRushRoadMarkingFlow()
    let initial = flow.distancesAhead
    flow.advance(by: 20)

    XCTAssertGreaterThan(flow.distancesAhead[0], initial[0])
    for index in 1..<flow.distancesAhead.count {
      XCTAssertEqual(flow.distancesAhead[index], initial[index] - 20, accuracy: 0.000_001)
    }
    XCTAssertTrue(flow.distancesAhead.allSatisfy { $0 > 0 && $0 <= flow.cycleLength })

    let ordered = flow.distancesAhead.sorted()
    for pair in zip(ordered, ordered.dropFirst()) {
      XCTAssertEqual(pair.1 - pair.0, LaneRushRoadMarkingFlow.spacingMeters, accuracy: 0.000_001)
    }
    XCTAssertEqual(
      ordered[0] + flow.cycleLength - ordered[ordered.count - 1],
      LaneRushRoadMarkingFlow.spacingMeters,
      accuracy: 0.000_001)
  }

  func testRoadMarkingProjectionMovesDownAndGrowsTowardPlayer() throws {
    let projection = LaneRushRoadMarkingProjection(
      road: LaneRushStaticRoadGeometry(size: CGSize(width: 420, height: 912)))
    let far = try XCTUnwrap(projection.depthRange(distanceAhead: 100))
    let mid = try XCTUnwrap(projection.depthRange(distanceAhead: 86))
    let near = try XCTUnwrap(projection.depthRange(distanceAhead: 50))

    XCTAssertLessThan(far.lowerBound, mid.lowerBound)
    XCTAssertLessThan(mid.lowerBound, near.lowerBound)
    XCTAssertLessThan(far.upperBound - far.lowerBound, mid.upperBound - mid.lowerBound)
    XCTAssertLessThan(mid.upperBound - mid.lowerBound, near.upperBound - near.lowerBound)
  }

  func testDeterministicTrafficUsesConfiguredClosingSpeedAndRecycles() {
    var simulation = LaneRushDynamicSimulation()
    let initialSpeed = simulation.forwardSpeed
    let initialTraffic = simulation.trafficDistanceAhead
    simulation.advance(deltaTime: 0.05)

    XCTAssertEqual(
      simulation.trafficClosingSpeed, simulation.forwardSpeed * 4.25, accuracy: 0.000_001)
    XCTAssertEqual(
      initialTraffic - simulation.trafficDistanceAhead,
      initialSpeed * 4.25 * 0.05,
      accuracy: 0.000_001)

    let shortCycle = LaneRushDynamicConfig(
      maximumDeltaTime: 1.0 / 15.0,
      oncomingFactor: 4.25,
      trafficStartDistance: 100,
      trafficPassDistance: 98)
    var recycling = LaneRushDynamicSimulation(config: shortCycle)
    recycling.advance(deltaTime: 0.05)
    XCTAssertGreaterThan(recycling.trafficDistanceAhead, shortCycle.trafficPassDistance)
    XCTAssertLessThanOrEqual(recycling.trafficDistanceAhead, shortCycle.trafficStartDistance)
  }

  func testMovingVehicleProjectionIsMonotonicAndBounded() {
    let projection = LaneRushVehicleProjection(
      road: LaneRushStaticRoadGeometry(size: CGSize(width: 420, height: 912)))
    let distances: [CGFloat] = [100, 86, 70, 50, 30, 18.181_818]
    var previousFrame = projection.vehicleFrame(lane: 0, distanceAhead: distances[0])

    for distance in distances.dropFirst() {
      let frame = projection.vehicleFrame(lane: 0, distanceAhead: distance)
      XCTAssertGreaterThan(frame.maxY, previousFrame.maxY)
      XCTAssertGreaterThanOrEqual(frame.width, previousFrame.width)
      XCTAssertLessThanOrEqual(frame.width, 420 * LaneRushVehicleProjection.nearWidthFraction)
      XCTAssertLessThanOrEqual(
        projection.vehicleScale(
          atDepth: projection.normalizedDepth(distanceAhead: distance)),
        projection.maximumVehicleScale)
      previousFrame = frame
    }
  }

  func testLaneControlsRemainInteractiveDuringDynamicMotion() {
    var simulation = LaneRushDynamicSimulation()
    XCTAssertTrue(simulation.command(.left))
    XCTAssertTrue(simulation.command(.right))
    for _ in 0..<6 { simulation.advance(deltaTime: 0.06) }
    XCTAssertEqual(simulation.player.lane, .center)
    XCTAssertNil(simulation.player.transition)

    XCTAssertTrue(simulation.command(.right))
    for _ in 0..<3 { simulation.advance(deltaTime: 0.06) }
    XCTAssertEqual(simulation.player.lane, .right)
  }

  func testDynamicCheckpointParsesLiveAndForcedDistanceModes() {
    XCTAssertEqual(
      LaneRushDynamicCheckpoint.launchValue(arguments: ["app", "-laneRushDynamicMotion"]),
      LaneRushDynamicCheckpoint(forcedDistance: nil))
    XCTAssertEqual(
      LaneRushDynamicCheckpoint.launchValue(
        arguments: ["app", "-laneRushDynamicMotion", "-laneRushForceDistance", "500"]),
      LaneRushDynamicCheckpoint(forcedDistance: 500))
    XCTAssertEqual(
      LaneRushDynamicCheckpoint.launchValue(
        arguments: ["app", "-laneRushDynamicMotion", "-laneRushForceDistance", "-5"]),
      LaneRushDynamicCheckpoint(forcedDistance: 0))
    XCTAssertNil(LaneRushDynamicCheckpoint.launchValue(arguments: ["app"]))
  }
}
