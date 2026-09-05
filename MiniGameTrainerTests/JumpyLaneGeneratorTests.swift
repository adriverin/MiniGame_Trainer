import XCTest
@testable import MiniGameTrainer

final class JumpyLaneGeneratorTests: XCTestCase {
    func testSeededGenerationIsDeterministicAndDifferentSeedsDiffer() {
        let first = rows(seed: 42)
        XCTAssertEqual(first, rows(seed: 42))
        XCTAssertNotEqual(first, rows(seed: 43))
    }

    func testProductionConfigurationDoesNotUseFixedSeed() {
        XCTAssertNil(JumpyGameConfig.reference.randomSeed)
    }

    func testStartIsSafeAndEverySafeRowHasNoTraffic() {
        let generated = rows(seed: 1, count: 300)
        XCTAssertEqual(generated.first?.kind, .safe)
        for row in generated {
            if case .safe = row.kind { continue }
            if case .road = row.kind { continue }
            XCTFail("Invalid row kind")
        }
    }

    func testRoadGroupsRespectDifficultyRanges() {
        for (score, expected) in [(0, 2...3), (25, 3...5), (75, 5...8), (125, 5...8)] {
            var config = JumpyGameConfig.reference
            config.randomSeed = UInt64(score + 1)
            var generator = JumpyLaneGenerator(config: config)
            var run = 0
            var runs: [Int] = []
            for row in 0..<300 {
                switch generator.nextRow(at: row, difficultyScore: score).kind {
                case .road: run += 1
                case .safe:
                    if run > 0 { runs.append(run); run = 0 }
                }
            }
            XCTAssertFalse(runs.isEmpty)
            XCTAssertTrue(runs.allSatisfy(expected.contains), "score \(score): \(runs)")
        }
    }

    func testLaneSpeedsDirectionsAndMaximumDirectionRunAreValid() {
        let generated = rows(seed: 99, count: 500)
        let lanes = generated.compactMap { row -> JumpyLane? in
            if case .road(let lane) = row.kind { return lane }
            return nil
        }
        XCTAssertTrue(lanes.allSatisfy { $0.speed >= 0.18 && $0.speed <= 0.42 })
        var run = 1
        for index in 1..<lanes.count {
            run = lanes[index].direction == lanes[index - 1].direction ? run + 1 : 1
            XCTAssertLessThanOrEqual(run, 3)
        }
    }

    func testGroupedVehiclePatternHasPositiveInternalGapsAndCrossableOpenings() {
        let config = JumpyGameConfig.reference
        for row in rows(seed: 7, count: 500) {
            guard case .road(let lane) = row.kind else { continue }
            let gaps = lane.bumperGaps()
            let groupStarts = Set(lane.groupStartIndices)
            let crossingGap = config.playerWidthRatio * config.playerHitboxScale + lane.speed * CGFloat(config.hopDuration) + config.trafficSafetyGap
            for index in gaps.indices {
                let followingIndex = (index + 1) % gaps.count
                if groupStarts.contains(followingIndex) {
                    XCTAssertGreaterThanOrEqual(gaps[index] + 1e-6, crossingGap)
                } else {
                    XCTAssertGreaterThanOrEqual(gaps[index] + 1e-6, 0.025)
                    XCTAssertLessThanOrEqual(gaps[index], 0.055 + 1e-6)
                }
            }
        }
    }

    func testTrafficRecyclePreservesSpacingAndDirection() {
        var lane = testLane(direction: .right, speed: 0.4, phase: 1.45)
        let before = lane.vehicleCenters(margin: 0.24)
        lane.advance(by: 1, margin: 0.24)
        let after = lane.vehicleCenters(margin: 0.24)
        XCTAssertEqual(before.count, after.count)
        XCTAssertTrue(after.allSatisfy { (-0.24...1.40).contains($0) })
        XCTAssertEqual(lane.direction, .right)
        XCTAssertEqual(lane.vehicleOffsets, [0.20, 0.66, 1.12])
    }

    func testEveryVehicleInLaneAdvancesInConfiguredDirection() {
        for direction in [JumpyLaneDirection.left, .right] {
            var lane = testLane(direction: direction, speed: 0.25, phase: 0.3)
            let before = lane.vehicleCenters(margin: 0.24)
            lane.advance(by: 0.1, margin: 0.24)
            let after = lane.vehicleCenters(margin: 0.24)
            for index in before.indices {
                XCTAssertEqual(after[index] - before[index], CGFloat(direction.rawValue) * 0.025, accuracy: 1e-6)
            }
        }
    }

    func testDifficultyIncreasesAndCapsAtOneFifty() {
        let model = JumpyDifficultyModel(config: .reference)
        let zero = model.values(at: 0)
        let fifty = model.values(at: 50)
        let hundred = model.values(at: 100)
        let oneHundred = model.values(at: 100)
        let huge = model.values(at: 10_000)
        XCTAssertLessThan(zero.speed.lowerBound, fifty.speed.lowerBound)
        XCTAssertLessThan(fifty.speed.upperBound, hundred.speed.upperBound)
        XCTAssertLessThan(hundred.groupOpening.lowerBound, zero.groupOpening.lowerBound)
        XCTAssertEqual(oneHundred.speed, huge.speed)
        XCTAssertEqual(oneHundred.speed, 0.24...0.42)
        XCTAssertEqual(huge.roadGroupLength, 5...8)
        XCTAssertEqual(huge.carsPerGroup, 2...4)
    }

    func testPairedSafeRowsOccurOnlyAfterScoreTwentyAndNeverExceedTwo() {
        var config = JumpyGameConfig.reference
        config.randomSeed = 88
        var generator = JumpyLaneGenerator(config: config)
        let low = (0..<200).map { generator.nextRow(at: $0, difficultyScore: 10) }
        XCTAssertFalse(zip(low, low.dropFirst()).contains { $0.isSafe && $1.isSafe })

        config.randomSeed = 88
        generator = JumpyLaneGenerator(config: config)
        let high = (0..<1_000).map { generator.nextRow(at: $0, difficultyScore: 50) }
        XCTAssertTrue(zip(high, high.dropFirst()).contains { $0.isSafe && $1.isSafe })
        XCTAssertFalse(zip(zip(high, high.dropFirst()), high.dropFirst(2)).contains { $0.0.isSafe && $0.1.isSafe && $1.isSafe })
    }

    private func rows(seed: UInt64, count: Int = 100) -> [JumpyWorldRow] {
        var config = JumpyGameConfig.reference
        config.randomSeed = seed
        var generator = JumpyLaneGenerator(config: config)
        return (0..<count).map { generator.nextRow(at: $0) }
    }

    private func testLane(direction: JumpyLaneDirection, speed: CGFloat, phase: CGFloat) -> JumpyLane {
        JumpyLane(
            id: 1,
            worldRow: 2,
            direction: direction,
            speed: speed,
            vehicleWidth: 0.16,
            vehicleOffsets: [0.20, 0.66, 1.12],
            groupStartIndices: [0, 1, 2],
            cycleLength: 1.64,
            phase: phase
        )
    }
}

private extension JumpyWorldRow {
    var isSafe: Bool {
        if case .safe = kind { return true }
        return false
    }
}
