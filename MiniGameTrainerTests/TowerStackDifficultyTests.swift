import XCTest
@testable import MiniGameTrainer

final class TowerStackDifficultyTests: XCTestCase {
    private let model = TowerStackDifficultyModel(config: .reference)

    func testSpeedIncreasesMonotonicallyWithScore() {
        XCTAssertGreaterThan(model.speed(forScore: 10), model.speed(forScore: 0))
        XCTAssertGreaterThan(model.speed(forScore: 50), model.speed(forScore: 10))
        XCTAssertGreaterThan(model.speed(forScore: 100), model.speed(forScore: 50))
        XCTAssertGreaterThan(model.speed(forScore: 170), model.speed(forScore: 100))
    }

    func testSpeedIsLinearInScore() {
        let config = TowerStackGameConfig.reference
        for score in [0, 25, 50, 75, 100, 125, 150, 170] {
            let expected = config.initialSpeed * (1 + config.speedGrowthPerPoint * CGFloat(score))
            XCTAssertEqual(model.speed(forScore: score), expected, accuracy: 1e-9)
        }
    }

    func testReferenceAnchorsRelativeSpeed() {
        // Reference placement intervals: 0.957 s (score 1–10) → 0.450 s (160–170), ≈ 2.1× faster.
        let ratio = model.speed(forScore: 165) / model.speed(forScore: 5)
        XCTAssertEqual(ratio, 2.1, accuracy: 0.15)
        // Direct tracking of block 2 gave ≈ 1.4 widths/s.
        XCTAssertEqual(model.speed(forScore: 1), 1.4, accuracy: 0.05)
    }

    func testSpeedIsCapped() {
        let config = TowerStackGameConfig.reference
        XCTAssertEqual(model.speed(forScore: 10_000), config.maximumSpeed)
        XCTAssertLessThanOrEqual(model.speed(forScore: 173), config.maximumSpeed)
        XCTAssertLessThan(model.speed(forScore: 173), config.maximumSpeed, "Reference run must not hit the cap")
    }

    func testTravelAndCameraDurationShrinkWithScore() {
        XCTAssertGreaterThan(model.travelTime(forScore: 0), model.travelTime(forScore: 100))
        XCTAssertEqual(model.travelTime(forScore: 0), 1.3 / 1.4, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(model.cameraStepDuration(forScore: 5_000), TowerStackGameConfig.reference.minimumCameraStepDuration)
    }

    func testNegativeScoreIsClampedToInitialSpeed() {
        XCTAssertEqual(model.speed(forScore: -5), model.speed(forScore: 0))
    }
}
