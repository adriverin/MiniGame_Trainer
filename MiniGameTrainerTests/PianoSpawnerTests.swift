import XCTest
@testable import MiniGameTrainer

final class PianoSpawnerTests: XCTestCase {
    func testGeneratedLanesAreWithinRange() {
        var config = PianoGameConfig.deterministic(seed: 1)
        config.doubleTileProbability = 0.5
        config.doubleTileUnlockScore = 0
        var spawner = PianoSpawner(config: config)
        for _ in 0..<5000 {
            let plan = spawner.nextRow(score: 100)
            for lane in plan.lanes {
                XCTAssertTrue((0..<config.laneCount).contains(lane))
            }
            if let extra = plan.extraLane {
                XCTAssertNotEqual(extra, plan.primaryLane)
            }
        }
    }

    func testPrimaryLaneNeverRepeatsPreviousPrimary() {
        var spawner = PianoSpawner(config: .deterministic(seed: 3))
        var previous: Int?
        for _ in 0..<5000 {
            let plan = spawner.nextRow(score: 0)
            if let previous {
                XCTAssertNotEqual(plan.primaryLane, previous)
            }
            previous = plan.primaryLane
        }
    }

    func testRepeatsAllowedWhenConfigured() {
        var config = PianoGameConfig.deterministic(seed: 3)
        config.allowSameLaneAsPrevious = true
        var spawner = PianoSpawner(config: config)
        var repeats = 0
        var previous: Int?
        for _ in 0..<2000 {
            let plan = spawner.nextRow(score: 0)
            if plan.primaryLane == previous { repeats += 1 }
            previous = plan.primaryLane
        }
        XCTAssertGreaterThan(repeats, 0)
    }

    func testNoDoublesBeforeUnlockAndRoughlyExpectedRateAfter() {
        var config = PianoGameConfig.deterministic(seed: 9)
        config.doubleTileUnlockScore = 15
        config.doubleTileProbability = 0.15
        var spawner = PianoSpawner(config: config)
        for _ in 0..<1000 {
            XCTAssertNil(spawner.nextRow(score: 14).extraLane)
        }
        var doubles = 0
        let total = 20_000
        for _ in 0..<total {
            if spawner.nextRow(score: 15).extraLane != nil { doubles += 1 }
        }
        let rate = Double(doubles) / Double(total)
        XCTAssertEqual(rate, 0.15, accuracy: 0.02)
    }

    func testLaneDistributionIsRoughlyUniform() {
        var config = PianoGameConfig.deterministic(seed: 11)
        config.doubleTileProbability = 0
        var spawner = PianoSpawner(config: config)
        var counts = [Int](repeating: 0, count: config.laneCount)
        let total = 40_000
        for _ in 0..<total {
            counts[spawner.nextRow(score: 0).primaryLane] += 1
        }
        for count in counts {
            XCTAssertEqual(Double(count) / Double(total), 0.25, accuracy: 0.02)
        }
    }

    func testSeededSequencesAreReproducible() {
        var a = PianoSpawner(config: .deterministic(seed: 2024))
        var b = PianoSpawner(config: .deterministic(seed: 2024))
        let plansA = (0..<200).map { a.nextRow(score: $0) }
        let plansB = (0..<200).map { b.nextRow(score: $0) }
        XCTAssertEqual(plansA, plansB)
    }

    func testSeededRandomNumberGeneratorIsDeterministic() {
        var a = SeededRandomNumberGenerator(seed: 99)
        var b = SeededRandomNumberGenerator(seed: 99)
        var c = SeededRandomNumberGenerator(seed: 100)
        let valuesA = (0..<10).map { _ in a.next() }
        let valuesB = (0..<10).map { _ in b.next() }
        let valuesC = (0..<10).map { _ in c.next() }
        XCTAssertEqual(valuesA, valuesB)
        XCTAssertNotEqual(valuesA, valuesC)
    }
}
