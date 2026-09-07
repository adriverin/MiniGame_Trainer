import XCTest

@testable import MiniGameTrainer

final class LaneRushTrafficGeneratorTests: XCTestCase {
  func testDifficultyAnchorsAndInterpolation() {
    let model = LaneRushTrafficDifficultyModel()
    let expected: [(Double, Double, Double)] = [
      (0, 104, 0.04), (250, 92, 0.16), (500, 82, 0.28),
      (750, 74, 0.40), (1000, 68, 0.48),
    ]
    for item in expected {
      let value = model.values(at: item.0)
      XCTAssertEqual(value.waveSpacing, item.1, accuracy: 0.000_001)
      XCTAssertEqual(value.doubleProbability, item.2, accuracy: 0.000_001)
    }
    let midpoint = model.values(at: 375)
    XCTAssertEqual(midpoint.waveSpacing, 87, accuracy: 0.000_001)
    XCTAssertEqual(midpoint.doubleProbability, 0.22, accuracy: 0.000_001)
  }

  func testSingleAndDoubleWaveShapes() {
    let single = makeGenerator(seed: 1, doubleProbability: 0)
    let double = makeGenerator(seed: 1, doubleProbability: 1)
    var singleGenerator = single
    var doubleGenerator = double
    let singleWave = makeWave(using: &singleGenerator)
    let doubleWave = makeWave(using: &doubleGenerator)

    XCTAssertEqual(singleWave.obstacles.count, 1)
    XCTAssertEqual(doubleWave.obstacles.count, 2)
    XCTAssertEqual(Set(doubleWave.obstacles.map(\.lane)).count, 2)
    XCTAssertFalse(singleWave.blockedLanes.contains(singleWave.safeLane))
    XCTAssertFalse(doubleWave.blockedLanes.contains(doubleWave.safeLane))
    XCTAssertEqual(doubleWave.blockedLanes.count, 2)
  }

  func testSeededGenerationIsStableAndDifferentSeedsDiffer() {
    var first = makeGenerator(seed: 42, doubleProbability: 0.5)
    var replay = makeGenerator(seed: 42, doubleProbability: 0.5)
    var different = makeGenerator(seed: 43, doubleProbability: 0.5)
    let firstWaves = (0..<30).map { _ in makeWave(using: &first) }
    let replayWaves = (0..<30).map { _ in makeWave(using: &replay) }
    let differentWaves = (0..<30).map { _ in makeWave(using: &different) }

    XCTAssertEqual(firstWaves, replayWaves)
    XCTAssertNotEqual(firstWaves, differentWaves)
    XCTAssertNil(LaneRushGameConfig.reference.randomSeed)
  }

  func testThousandsOfWavesNeverCreateTripleOrInvalidLane() {
    for seed in 0..<40 {
      var config = LaneRushGameConfig.reference
      config.randomSeed = UInt64(seed)
      var generator = LaneRushTrafficGenerator(config: config)
      for index in 0..<100 {
        let distance = Double((index % 5) * 250)
        let closing = LaneRushDifficultyModel.reference.forwardSpeed(at: distance)
          * config.oncomingFactor
        let spacing = generator.spacing(at: distance)
        let wave = generator.makeWave(
          distanceAhead: 100 + spacing,
          precedingGap: spacing,
          playerDistance: distance,
          closingSpeed: closing)
        XCTAssertTrue((1...2).contains(wave.obstacles.count))
        XCTAssertEqual(Set(wave.obstacles.map(\.lane)).count, wave.obstacles.count)
        XCTAssertFalse(wave.blockedLanes.contains(wave.safeLane))
        XCTAssertTrue(wave.obstacles.allSatisfy { LaneRushLane.allCases.contains($0.lane) })
      }
    }
  }

  func testFairnessRemainsReachableAcrossTenThousandTransitions() {
    let distances: [Double] = [0, 250, 500, 750, 1000]
    for seed in 0..<100 {
      var config = LaneRushGameConfig.reference
      config.randomSeed = UInt64(seed)
      var generator = LaneRushTrafficGenerator(config: config)
      var previousSafe = LaneRushLane.center
      for index in 0..<100 {
        let distance = distances[index % distances.count]
        let closing = LaneRushDifficultyModel.reference.forwardSpeed(at: distance)
          * config.oncomingFactor
        let spacing = generator.spacing(at: distance)
        let wave = generator.makeWave(
          distanceAhead: 100 + spacing,
          precedingGap: spacing,
          playerDistance: distance,
          closingSpeed: closing)
        XCTAssertTrue(
          LaneRushTrafficFairness.isReachable(
            from: previousSafe,
            to: wave.safeLane,
            gap: spacing,
            closingSpeed: closing,
            reactionMargin: config.reactionMargin),
          "Unreachable seed \(seed), transition \(index), distance \(distance)")
        previousSafe = wave.safeLane
      }
    }
  }

  func testGenerationAheadStableModelsAndIndividualCulling() {
    var config = LaneRushGameConfig.reference
    config.randomSeed = 77
    let logic = LaneRushGameLogic(config: config)
    logic.collisionDetectionEnabled = false
    XCTAssertGreaterThanOrEqual(
      logic.trafficWaves.map(\.distanceAhead).max() ?? 0,
      config.minimumGenerationDistance)
    let stableIDs = logic.trafficWaves.map(\.id)
    let stableObstacles = logic.trafficWaves.map(\.obstacles)
    logic.update(deltaTime: 1.0 / 120.0)
    XCTAssertEqual(logic.trafficWaves.prefix(stableIDs.count).map(\.id), stableIDs)
    XCTAssertEqual(
      logic.trafficWaves.prefix(stableObstacles.count).map(\.obstacles), stableObstacles)

    let passing = LaneRushTrafficWave(
      id: 999,
      distanceAhead: config.trafficCullDistance + 0.1,
      obstacles: [
        LaneRushTrafficObstacle(
          id: 999, lane: .left,
          appearance: LaneRushVehicleAppearance(color: .red, body: .coupe))
      ],
      safeLane: .center)
    logic.replaceTrafficForTesting([passing])
    logic.update(deltaTime: 0.01)
    XCTAssertEqual(logic.carsPassed, 1)
    XCTAssertFalse(logic.trafficWaves.contains { $0.id == passing.id })
    XCTAssertLessThan(logic.trafficWaves.count, 20)
  }

  private func makeGenerator(
    seed: UInt64,
    doubleProbability: Double
  ) -> LaneRushTrafficGenerator {
    var config = LaneRushGameConfig.reference
    config.randomSeed = seed
    let difficulty = LaneRushTrafficDifficultyModel(anchors: [
      .init(distance: 0, spacing: 90, doubleProbability: doubleProbability)
    ])
    return LaneRushTrafficGenerator(config: config, difficulty: difficulty)
  }

  private func makeWave(using generator: inout LaneRushTrafficGenerator) -> LaneRushTrafficWave {
    let spacing = generator.spacing(at: 0)
    return generator.makeWave(
      distanceAhead: 100 + spacing,
      precedingGap: spacing,
      playerDistance: 0,
      closingSpeed: 15 * 4.25)
  }
}
