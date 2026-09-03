import XCTest
@testable import MiniGameTrainer

final class BloopyDifficultyTests: XCTestCase {
    func testWidthShrinksAndSpacingGrowsWithScore() {
        let model = BloopyDifficultyModel(config: .reference)
        XCTAssertEqual(model.platformWidthRatio(forScore: 0), 0.235, accuracy: 1e-9)
        XCTAssertEqual(model.platformWidthRatio(forScore: 50), 0.220, accuracy: 1e-9)
        XCTAssertEqual(model.platformWidthRatio(forScore: 500), 0.088, accuracy: 1e-9)
        XCTAssertEqual(model.platformWidthRatio(forScore: 600), 0.080, accuracy: 1e-9)
        XCTAssertLessThan(model.platformWidthRatio(forScore: 300), model.platformWidthRatio(forScore: 100))
        XCTAssertGreaterThan(model.verticalSpacingRatio(forScore: 400), model.verticalSpacingRatio(forScore: 0))
        XCTAssertEqual(model.verticalSpacingRatio(forScore: 500), model.verticalSpacingRatio(forScore: 600), accuracy: 1e-9)
    }

    func testPhysicsDoesNotScaleWithScore() {
        let model = BloopyDifficultyModel(config: .reference)
        XCTAssertEqual(model.gravity(sceneHeight: 844), 844 * 4.80, accuracy: 1e-9)
        XCTAssertEqual(model.bounceImpulse(sceneHeight: 844), 844 * 1.72, accuracy: 1e-9)
        let bounce = model.bounceHeight(sceneHeight: 844)
        XCTAssertGreaterThan(bounce, 844 * 0.27)
        XCTAssertLessThan(bounce, 844 * 0.34)
        XCTAssertGreaterThan(bounce, model.verticalSpacing(forScore: 500, sceneHeight: 844))
    }

    func testGeneratedPlatformsRemainReachableAtReferenceStages() {
        let config = BloopyGameConfig.deterministic()
        let geometry = BloopyGeometry(sceneSize: CGSize(width: 390, height: 844), config: config)
        var generator = BloopyPlatformGenerator(config: config)
        var current = generator.initialPlatforms(geometry: geometry)[0]
        for score in [0, 50, 100, 200, 300, 400, 500, 600] {
            for _ in 0..<8 {
                let next = generator.next(after: current, score: score, geometry: geometry)
                XCTAssertTrue(generator.isReachable(from: current, to: next, geometry: geometry), "unreachable at score \(score)")
                XCTAssertLessThan(next.worldY - current.worldY, BloopyDifficultyModel(config: config).bounceHeight(sceneHeight: 844))
                current = next
            }
        }
    }
}
