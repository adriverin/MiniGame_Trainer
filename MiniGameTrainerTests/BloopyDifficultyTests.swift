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

    func testGeneratedPlatformsRemainReachableWithoutWrapping() {
        let seeds: [UInt64] = [17_602, 1, 42, 99, 7, 4_096]
        let sceneSize = CGSize(width: 390, height: 844)
        for seed in seeds {
            let config = BloopyGameConfig.deterministic(seed: seed)
            let geometry = BloopyGeometry(sceneSize: sceneSize, config: config)
            var generator = BloopyPlatformGenerator(config: config)
            var current = generator.initialPlatforms(geometry: geometry)[0]
            for score in [0, 50, 100, 200, 300, 400, 500, 600] {
                for _ in 0..<12 {
                    let next = generator.next(after: current, score: score, geometry: geometry)
                    XCTAssertTrue(
                        generator.isReachable(from: current, to: next, geometry: geometry),
                        "unreachable at score \(score) seed \(seed)"
                    )
                    XCTAssertLessThan(
                        next.worldY - current.worldY,
                        BloopyDifficultyModel(config: config).bounceHeight(sceneHeight: 844)
                    )
                    let linearGap = abs(current.worldX - next.worldX) - current.width / 2 - next.width / 2
                    let wrapGap = min(
                        abs(current.worldX - next.worldX),
                        geometry.width - abs(current.worldX - next.worldX)
                    ) - current.width / 2 - next.width / 2
                    if wrapGap + 1 < linearGap {
                        XCTAssertTrue(
                            generator.isReachable(from: current, to: next, geometry: geometry),
                            "reachability must use the real on-screen path, not the wrap shortcut"
                        )
                    }
                    current = next
                }
            }
        }
    }

    func testFragileProbabilityIsZeroBeforeThresholdThenClamped() {
        let model = BloopyDifficultyModel(config: .reference)
        XCTAssertEqual(BloopyGameConfig.reference.fragileStartScore, 80)
        XCTAssertEqual(model.fragileProbability(forScore: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 79), 0, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 80), 0.20, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 400), 0.24, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 600), 0.24, accuracy: 1e-12)
        let mid = model.fragileProbability(forScore: 240)
        XCTAssertGreaterThan(mid, 0.20)
        XCTAssertLessThan(mid, 0.24)
        for score in [0, 40, 80, 160, 240, 400, 800] {
            let probability = model.fragileProbability(forScore: score)
            XCTAssertGreaterThanOrEqual(probability, 0)
            XCTAssertLessThanOrEqual(probability, 1)
        }
    }

    func testFragileProbabilityClampsOutOfRangeConfigValues() {
        var config = BloopyGameConfig.reference
        config.fragileStartScore = 50
        config.fragileProbabilityAtStart = -0.4
        config.fragileProbabilityHighScore = 1.8
        config.fragileProbabilityRampEndScore = 150
        let model = BloopyDifficultyModel(config: config)
        XCTAssertEqual(model.fragileProbability(forScore: 49), 0, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 50), 0, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 150), 1, accuracy: 1e-12)
        XCTAssertEqual(model.fragileProbability(forScore: 100), 0.5, accuracy: 1e-12)
    }

    func testPreThresholdGenerationProducesNoFragilePlatforms() {
        let config = BloopyGameConfig.deterministic()
        let geometry = BloopyGeometry(sceneSize: CGSize(width: 390, height: 844), config: config)
        var generator = BloopyPlatformGenerator(config: config)
        var current = generator.initialPlatforms(geometry: geometry)[0]
        XCTAssertEqual(current.kind, .stable)
        var fragile = 0
        for _ in 0..<120 {
            let next = generator.next(after: current, score: 0, geometry: geometry)
            if next.kind == .fragile { fragile += 1 }
            current = next
        }
        XCTAssertEqual(fragile, 0)
    }

    func testEligibleGenerationProducesBothKindsAndIsDeterministic() {
        let sceneSize = CGSize(width: 390, height: 844)
        func kinds(seed: UInt64, score: Int, count: Int) -> [BloopyPlatformKind] {
            let config = BloopyGameConfig.deterministic(seed: seed)
            let geometry = BloopyGeometry(sceneSize: sceneSize, config: config)
            var generator = BloopyPlatformGenerator(config: config)
            var current = generator.initialPlatforms(geometry: geometry)[0]
            return (0..<count).map { _ in
                let next = generator.next(after: current, score: score, geometry: geometry)
                current = next
                return next.kind
            }
        }

        let first = kinds(seed: 17_602, score: 120, count: 80)
        let replay = kinds(seed: 17_602, score: 120, count: 80)
        XCTAssertEqual(first, replay)
        XCTAssertTrue(first.contains(.stable))
        XCTAssertTrue(first.contains(.fragile))

        let high = kinds(seed: 17_602, score: 500, count: 80)
        XCTAssertTrue(high.contains(.stable))
        XCTAssertTrue(high.contains(.fragile))

        let early = kinds(seed: 17_602, score: 0, count: 80)
        XCTAssertTrue(early.allSatisfy { $0 == .stable })
    }

    func testLiveEarlyClimbSpawnsOnlyStablePlatforms() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: CGSize(width: 390, height: 844))
        logic.start()
        var frames = 0
        while logic.score < BloopyGameConfig.reference.fragileStartScore, logic.state == .playing, frames < 4_000 {
            for platform in logic.platforms {
                XCTAssertEqual(platform.kind, .stable, "fragile platform \(platform.id) spawned at score \(logic.score)")
            }
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            frames += 1
        }
        XCTAssertGreaterThanOrEqual(logic.score, 20)
    }

    func testFragileDistributionEarlyEligibleAndHighScore() {
        let sceneSize = CGSize(width: 390, height: 844)
        func countFragile(score: Int, sample: Int = 400) -> Int {
            let config = BloopyGameConfig.deterministic(seed: 4_096)
            let geometry = BloopyGeometry(sceneSize: sceneSize, config: config)
            var generator = BloopyPlatformGenerator(config: config)
            var current = generator.initialPlatforms(geometry: geometry)[0]
            return (0..<sample).reduce(0) { partial, _ in
                let next = generator.next(after: current, score: score, geometry: geometry)
                current = next
                return partial + (next.kind == .fragile ? 1 : 0)
            }
        }

        XCTAssertEqual(countFragile(score: 0), 0)
        XCTAssertEqual(countFragile(score: 79), 0)
        let eligible = countFragile(score: 120)
        let high = countFragile(score: 500)
        XCTAssertGreaterThan(eligible, 0)
        XCTAssertLessThan(eligible, 400)
        XCTAssertGreaterThan(high, 0)
        XCTAssertLessThan(high, 400)
    }

    func testFragileAssignmentUsesInjectedSeedAndNotAProductionFixedSeed() {
        XCTAssertNil(BloopyGameConfig.reference.randomSeed)
        XCTAssertEqual(BloopyGameConfig.deterministic().randomSeed, 17_602)
        let model = BloopyDifficultyModel(config: .reference)
        XCTAssertEqual(model.platformKind(forScore: 0, roll: 0), .stable)
        XCTAssertEqual(model.platformKind(forScore: 80, roll: 0), .fragile)
        XCTAssertEqual(model.platformKind(forScore: 80, roll: 0.199), .fragile)
        XCTAssertEqual(model.platformKind(forScore: 80, roll: 0.20), .stable)
    }

    func testReachabilityDoesNotTreatOppositeEdgesAsNeighbors() {
        let config = BloopyGameConfig.deterministic()
        let geometry = BloopyGeometry(sceneSize: CGSize(width: 390, height: 844), config: config)
        let generator = BloopyPlatformGenerator(config: config)
        let left = BloopyPlatform(id: 1, worldX: 30, worldY: 40, width: 40)
        let right = BloopyPlatform(id: 2, worldX: 360, worldY: 160, width: 40)
        XCTAssertFalse(generator.isReachable(from: left, to: right, geometry: geometry))
    }
}
