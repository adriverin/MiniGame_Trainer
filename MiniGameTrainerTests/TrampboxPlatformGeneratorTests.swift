import XCTest
@testable import MiniGameTrainer

final class TrampboxPlatformGeneratorTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    func testSameSeedProducesSameSequence() {
        let config = TrampboxGameConfig.deterministic(seed: 2026)
        let geometry = TrampboxGeometry(sceneSize: sceneSize, config: config)
        var a = TrampboxPlatformGenerator(config: config)
        var b = TrampboxPlatformGenerator(config: config)
        XCTAssertEqual(a.initialPlatforms(geometry: geometry), b.initialPlatforms(geometry: geometry))
    }

    func testDifferentSeedsProduceDifferentSequence() {
        let configA = TrampboxGameConfig.deterministic(seed: 1)
        let configB = TrampboxGameConfig.deterministic(seed: 2)
        let geometryA = TrampboxGeometry(sceneSize: sceneSize, config: configA)
        let geometryB = TrampboxGeometry(sceneSize: sceneSize, config: configB)
        var a = TrampboxPlatformGenerator(config: configA)
        var b = TrampboxPlatformGenerator(config: configB)
        XCTAssertNotEqual(a.initialPlatforms(geometry: geometryA).map(\.centerX), b.initialPlatforms(geometry: geometryB).map(\.centerX))
    }

    func testThousandsOfGeneratedPlatformsStayReachableAndOnScreen() {
        let config = TrampboxGameConfig.deterministic(seed: 99)
        let geometry = TrampboxGeometry(sceneSize: sceneSize, config: config)
        var generator = TrampboxPlatformGenerator(config: config)
        var current = generator.initialPlatforms(geometry: geometry)[0]
        for score in 1...10_000 {
            let next = generator.next(after: current, score: score, geometry: geometry)
            XCTAssertLessThanOrEqual(abs(next.centerX - current.centerX), generator.maximumReach(from: current, geometry: geometry) + 0.001)
            XCTAssertGreaterThanOrEqual(next.centerX - next.width / 2, -0.001)
            XCTAssertLessThanOrEqual(next.centerX + next.width / 2, geometry.width + 0.001)
            current = next
        }
    }

    func testInitialSequenceHasConfiguredCountAndIncreasingLevels() {
        var config = TrampboxGameConfig.deterministic()
        config.visiblePlatformCount = 9
        let geometry = TrampboxGeometry(sceneSize: sceneSize, config: config)
        var generator = TrampboxPlatformGenerator(config: config)
        let platforms = generator.initialPlatforms(geometry: geometry)
        XCTAssertEqual(platforms.count, 9)
        XCTAssertEqual(platforms.map(\.scoreLevel), Array(0..<9))
        XCTAssertEqual(Set(platforms.map(\.id)).count, 9)
    }

    func testVisualProjectionParametersDoNotChangeLogicalSequenceOrReachability() {
        let baseline = TrampboxGameConfig.deterministic(seed: 55)
        var altered = baseline
        altered.farScale = 0.2
        altered.nearTopDepthToWidthRatio = 0.9
        altered.approachRotationDegrees = 9
        altered.departureRotationDegrees = 170
        altered.foregroundScaleMultiplier = 2.8

        let baselineGeometry = TrampboxGeometry(sceneSize: sceneSize, config: baseline)
        let alteredGeometry = TrampboxGeometry(sceneSize: sceneSize, config: altered)
        var baselineGenerator = TrampboxPlatformGenerator(config: baseline)
        var alteredGenerator = TrampboxPlatformGenerator(config: altered)
        let baselinePlatforms = baselineGenerator.initialPlatforms(geometry: baselineGeometry)
        let alteredPlatforms = alteredGenerator.initialPlatforms(geometry: alteredGeometry)
        XCTAssertEqual(baselinePlatforms, alteredPlatforms)
        XCTAssertEqual(
            baselineGenerator.maximumReach(from: baselinePlatforms[0], geometry: baselineGeometry),
            alteredGenerator.maximumReach(from: alteredPlatforms[0], geometry: alteredGeometry),
            accuracy: 0.001
        )
    }
}
