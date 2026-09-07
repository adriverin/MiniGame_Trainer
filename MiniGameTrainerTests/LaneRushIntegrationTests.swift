import XCTest

@testable import MiniGameTrainer

@MainActor
final class LaneRushIntegrationTests: XCTestCase {
  func testRegistryAppendsLaneRushAsEighteenthGame() {
    XCTAssertEqual(GameRegistry.descriptors.count, 18)
    XCTAssertEqual(GameRegistry.descriptors.last?.id, "laneRush")
    XCTAssertEqual(GameRegistry.descriptors.last?.name, "LANE RUSH")
  }

  func testDistancePresentationAndResultMetrics() {
    let descriptor = LaneRushGameModule.descriptor
    XCTAssertEqual(descriptor.scorePresentation.label, "Distance")
    XCTAssertEqual(descriptor.scorePresentation.unit, "m")
    XCTAssertEqual(descriptor.scorePresentation.comparison, .higherIsBetter)
    XCTAssertEqual(descriptor.scorePresentation.formatted(0), "0 m")

    let result = LaneRushResultBuilder.makeResult(
      from: LaneRushSessionSummary(
        distance: 0,
        carsPassed: 12,
        laneChanges: 7,
        duration: 8.25,
        maximumSpeed: 31.44))
    XCTAssertEqual(result.gameID, "laneRush")
    XCTAssertEqual(result.score, 0)
    XCTAssertEqual(
      result.metrics.map(\.key),
      ["distance", "carsPassed", "laneChanges", "duration", "maximumSpeed"])
    XCTAssertEqual(result.metrics[0].value, "0 m")
    XCTAssertEqual(result.metrics[1].value, "12")
    XCTAssertEqual(result.metrics[2].value, "7")
    XCTAssertEqual(result.metrics[3].value, "8.2 s")
    XCTAssertEqual(result.metrics[4].value, "31.4 m/s")
  }

  func testStatisticsPersistHighestDistanceIncludingZero() {
    let suite = "LaneRushStatistics-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let store = StatisticsStore(userDefaults: defaults)
    store.record(result(distance: 0))
    store.record(result(distance: 480))
    store.record(result(distance: 320))
    XCTAssertEqual(store.statistics(for: "laneRush").gamesPlayed, 3)
    XCTAssertEqual(store.statistics(for: "laneRush").bestScore, 480)
    defaults.removePersistentDomain(forName: suite)
  }

  func testLaneRushInheritsFreeRewardedAndProAttempts() {
    let suite = "LaneRushAttempts-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let entitlement = StubEntitlement(isPro: false)
    let attempts = AttemptManager(
      userDefaults: defaults,
      clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)),
      calendar: calendar,
      entitlement: entitlement)
    for _ in 0..<7 { XCTAssertTrue(attempts.consumeAttempt(for: "laneRush")) }
    XCTAssertEqual(attempts.availability(for: "laneRush"), .exhausted)
    XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "laneRush"))
    XCTAssertEqual(attempts.availability(for: "laneRush"), .rewarded(remaining: 3))
    entitlement.isPro = true
    XCTAssertEqual(attempts.availability(for: "laneRush"), .proUnlimited)
    defaults.removePersistentDomain(forName: suite)
  }

  func testLaneChangesCountOnlyAtSuccessfulCompletion() {
    var config = LaneRushGameConfig.reference
    config.randomSeed = 3
    let logic = LaneRushGameLogic(config: config)
    logic.collisionDetectionEnabled = false
    XCTAssertTrue(logic.requestLaneChange(.left))
    XCTAssertEqual(logic.laneChanges, 0)
    for _ in 0..<3 { logic.update(deltaTime: 0.06) }
    XCTAssertEqual(logic.player.lane, .left)
    XCTAssertEqual(logic.laneChanges, 1)
    XCTAssertFalse(logic.requestLaneChange(.left))
    logic.update(deltaTime: 0.06)
    XCTAssertEqual(logic.laneChanges, 1)
  }

  func testRunningPauseFreezesAllProductionState() {
    let logic = LaneRushGameLogic()
    XCTAssertTrue(logic.requestLaneChange(.left))
    logic.update(deltaTime: 0.04)
    logic.pause()
    let distance = logic.distanceMeters
    let traffic = logic.trafficWaves
    let markings = logic.roadMarkings
    let player = logic.player
    let duration = logic.activeDuration
    logic.update(deltaTime: 100)
    XCTAssertEqual(logic.distanceMeters, distance)
    XCTAssertEqual(logic.trafficWaves, traffic)
    XCTAssertEqual(logic.roadMarkings, markings)
    XCTAssertEqual(logic.player, player)
    XCTAssertEqual(logic.activeDuration, duration)
    logic.resume()
    logic.update(deltaTime: 0.01)
    XCTAssertGreaterThan(logic.distanceMeters, distance)
  }

  private func result(distance: Int) -> GameResult {
    LaneRushResultBuilder.makeResult(
      from: LaneRushSessionSummary(
        distance: distance,
        carsPassed: 0,
        laneChanges: 0,
        duration: 1,
        maximumSpeed: 15))
  }
}
