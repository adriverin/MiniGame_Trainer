import XCTest
@testable import MiniGameTrainer

final class PianoDifficultyTests: XCTestCase {
    private let geometry = PianoGeometry(sceneSize: CGSize(width: 393, height: 852), config: .reference)

    func testSpeedGrowsLinearlyWithScore() {
        var config = PianoGameConfig.reference
        config.initialSpeed = 0.3
        config.speedIncreasePerPoint = 0.01
        config.maximumSpeed = 10
        let model = PianoDifficultyModel(config: config)

        XCTAssertEqual(model.speedRatio(forScore: 0), 0.3, accuracy: 1e-9)
        XCTAssertEqual(model.speedRatio(forScore: 10), 0.4, accuracy: 1e-9)
        XCTAssertEqual(model.speedRatio(forScore: 100), 1.3, accuracy: 1e-9)
        XCTAssertEqual(model.speed(forScore: 10, geometry: geometry), 0.4 * 852, accuracy: 1e-6)
    }

    func testSpeedNeverExceedsMaximum() {
        var config = PianoGameConfig.reference
        config.initialSpeed = 0.3
        config.speedIncreasePerPoint = 0.05
        config.maximumSpeed = 1.0
        let model = PianoDifficultyModel(config: config)

        XCTAssertEqual(model.speedRatio(forScore: 14), 1.0, accuracy: 1e-9)
        XCTAssertEqual(model.speedRatio(forScore: 500), 1.0, accuracy: 1e-9)
        for score in stride(from: 0, through: 1000, by: 25) {
            XCTAssertLessThanOrEqual(model.speedRatio(forScore: score), config.maximumSpeed)
        }
    }

    func testNegativeScoreIsTreatedAsZero() {
        let model = PianoDifficultyModel(config: .reference)
        XCTAssertEqual(model.speedRatio(forScore: -5), model.speedRatio(forScore: 0))
    }

    func testSpawnIntervalShrinksAsSpeedGrows() {
        let model = PianoDifficultyModel(config: .reference)
        let slow = model.spawnInterval(forScore: 0, geometry: geometry)
        let fast = model.spawnInterval(forScore: 100, geometry: geometry)
        XCTAssertGreaterThan(slow, fast)
        // Rows are contiguous: interval == rowHeight / speed.
        XCTAssertEqual(slow, geometry.rowHeight / model.speed(forScore: 0, geometry: geometry), accuracy: 1e-9)
    }

    func testReferenceValuesMatchRecordingEstimates() {
        // 0.343 h/s at score 0 and ≈1.28 h/s at 157 (see GAME_ANALYSIS.md).
        let model = PianoDifficultyModel(config: .reference)
        XCTAssertEqual(model.speedRatio(forScore: 0), 0.343, accuracy: 0.001)
        XCTAssertEqual(model.speedRatio(forScore: 157), 1.285, accuracy: 0.01)
        XCTAssertEqual(model.spawnInterval(forScore: 0, geometry: geometry), 0.191 / 0.343, accuracy: 0.01)
    }

    func testGeometryResolvesRatios() {
        let config = PianoGameConfig.reference
        XCTAssertEqual(geometry.laneWidth, 393.0 / 4, accuracy: 1e-9)
        XCTAssertEqual(geometry.rowHeight, 852 * config.rowHeightRatio, accuracy: 1e-9)
        XCTAssertEqual(geometry.tileSize.height, geometry.rowHeight - geometry.seam, accuracy: 1e-9)
        XCTAssertEqual(geometry.playfieldTop, 852 * config.playfieldTopRatio, accuracy: 1e-9)
        XCTAssertEqual(geometry.missLineY, 852 * config.missLineRatio, accuracy: 1e-9)
        XCTAssertEqual(geometry.lane(forX: 0), 0)
        XCTAssertEqual(geometry.lane(forX: 392.9), 3)
        XCTAssertNil(geometry.lane(forX: 393))
        XCTAssertNil(geometry.lane(forX: -1))
        XCTAssertEqual(geometry.laneCenterX(1), geometry.laneWidth * 1.5, accuracy: 1e-9)
        let frame = geometry.tileFrame(lane: 2, rowTop: 100)
        XCTAssertEqual(frame.midX, geometry.laneCenterX(2), accuracy: 1e-9)
        XCTAssertEqual(frame.minY, 100 + geometry.seam / 2, accuracy: 1e-9)
    }
}
