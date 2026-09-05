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
        for (score, expected) in [(0, 2...3), (25, 3...4), (75, 3...5), (125, 3...5)] {
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
        XCTAssertTrue(lanes.allSatisfy { $0.speed >= 0.20 && $0.speed <= 0.48 })
        var run = 1
        for index in 1..<lanes.count {
            run = lanes[index].direction == lanes[index - 1].direction ? run + 1 : 1
            XCTAssertLessThanOrEqual(run, 3)
        }
    }

    func testVehicleSpacingDoesNotOverlapAndMeetsMinimum() {
        let config = JumpyGameConfig.reference
        for row in rows(seed: 7, count: 500) {
            guard case .road(let lane) = row.kind else { continue }
            let centers = lane.vehicleCenters(margin: config.trafficMargin).sorted()
            for index in 1..<centers.count {
                XCTAssertGreaterThanOrEqual(centers[index] - centers[index - 1] - lane.vehicleWidth + 1e-6, lane.spacing)
            }
            let wrapDistance = 1 + config.trafficMargin * 2 - (centers.last! - centers.first!)
            XCTAssertGreaterThanOrEqual(wrapDistance - lane.vehicleWidth + 1e-6, lane.spacing)
        }
    }

    func testTrafficRecyclePreservesSpacingAndDirection() {
        var lane = JumpyLane(id: 1, worldRow: 2, direction: .right, speed: 0.4, vehicleWidth: 0.16, spacing: 0.30, phaseOffset: 0.2, vehicleCount: 3, phase: 1.45)
        let before = lane.vehicleCenters(margin: 0.24)
        lane.advance(by: 1, margin: 0.24)
        let after = lane.vehicleCenters(margin: 0.24)
        XCTAssertEqual(before.count, after.count)
        XCTAssertTrue(after.allSatisfy { (-0.24...1.24).contains($0) })
        XCTAssertEqual(lane.direction, .right)
        XCTAssertEqual(lane.spacing, 0.30)
    }

    func testEveryVehicleInLaneAdvancesInConfiguredDirection() {
        for direction in [JumpyLaneDirection.left, .right] {
            var lane = JumpyLane(id: 1, worldRow: 2, direction: direction, speed: 0.25, vehicleWidth: 0.16, spacing: 0.30, phaseOffset: 0.1, vehicleCount: 2, phase: 0.3)
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
        let oneFifty = model.values(at: 150)
        let huge = model.values(at: 10_000)
        XCTAssertLessThan(zero.speed.lowerBound, fifty.speed.lowerBound)
        XCTAssertLessThan(fifty.speed.upperBound, hundred.speed.upperBound)
        XCTAssertLessThan(hundred.gap.lowerBound, zero.gap.lowerBound)
        XCTAssertEqual(oneFifty, huge)
        XCTAssertEqual(oneFifty.speed, 0.32...0.48)
    }

    private func rows(seed: UInt64, count: Int = 100) -> [JumpyWorldRow] {
        var config = JumpyGameConfig.reference
        config.randomSeed = seed
        var generator = JumpyLaneGenerator(config: config)
        return (0..<count).map { generator.nextRow(at: $0) }
    }
}
