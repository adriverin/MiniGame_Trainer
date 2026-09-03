import XCTest
@testable import MiniGameTrainer

final class TargetSpeedDifficultyTests: XCTestCase {
    func testReferenceAnchors() {
        let model = TargetSpeedDifficultyModel(config: .reference)
        XCTAssertEqual(model.lifetime(forScore: 0), 1.40, accuracy: 1e-12)
        XCTAssertEqual(model.lifetime(forScore: 50), 1.30, accuracy: 1e-12)
        XCTAssertEqual(model.lifetime(forScore: 100), 1.25, accuracy: 1e-12)
        XCTAssertEqual(model.lifetime(forScore: 200), 1.20, accuracy: 1e-12)
        XCTAssertEqual(model.lifetime(forScore: 400), 1.15, accuracy: 1e-12)
        XCTAssertEqual(model.lifetime(forScore: 700), 1.10, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 0), 0.50, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 50), 0.36, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 200), 0.24, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 700), 0.20, accuracy: 1e-12)
        XCTAssertEqual(model.maxActive(forScore: 0), 1)
        XCTAssertEqual(model.maxActive(forScore: 50), 2)
        XCTAssertEqual(model.maxActive(forScore: 200), 3)
        XCTAssertEqual(model.maxActive(forScore: 400), 4)
        XCTAssertEqual(model.maxActive(forScore: 700), 5)
    }

    func testLinearInterpolationBetweenAnchors() {
        let model = TargetSpeedDifficultyModel(config: .reference)
        XCTAssertEqual(model.lifetime(forScore: 25), 1.35, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 25), 0.43, accuracy: 1e-12)
    }

    func testMonotonicDifficulty() {
        let model = TargetSpeedDifficultyModel(config: .reference)
        var previousLife = model.lifetime(forScore: 0)
        var previousSpawn = model.spawnInterval(forScore: 0)
        var previousActive = model.maxActive(forScore: 0)
        for score in 1...800 {
            let life = model.lifetime(forScore: score)
            let spawn = model.spawnInterval(forScore: score)
            let active = model.maxActive(forScore: score)
            XCTAssertLessThanOrEqual(life, previousLife + 1e-12, "lifetime \(score)")
            XCTAssertLessThanOrEqual(spawn, previousSpawn + 1e-12, "spawn \(score)")
            XCTAssertGreaterThanOrEqual(active, previousActive)
            previousLife = life
            previousSpawn = spawn
            previousActive = active
        }
    }

    func testCapAfterHighestEvidenceRange() {
        let model = TargetSpeedDifficultyModel(config: .reference)
        XCTAssertEqual(model.lifetime(forScore: 1_000), 1.10, accuracy: 1e-12)
        XCTAssertEqual(model.spawnInterval(forScore: 1_000), 0.20, accuracy: 1e-12)
        XCTAssertEqual(model.maxActive(forScore: 1_000), 5)
        XCTAssertGreaterThan(model.lifetime(forScore: 10_000), 0)
    }

    func testSizeWeightsRemainNormalized() {
        let model = TargetSpeedDifficultyModel(config: .reference)
        for score in [0, 50, 100, 200, 350, 500, 700, 1200] {
            let weights = model.sizeWeights(forScore: score)
            XCTAssertEqual(weights.count, 4)
            XCTAssertEqual(weights.reduce(0, +), 1, accuracy: 1e-9, "score \(score)")
            XCTAssertTrue(weights.allSatisfy { $0 >= -1e-12 })
        }
    }
}
