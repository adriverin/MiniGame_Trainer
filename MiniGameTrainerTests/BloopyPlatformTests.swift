import XCTest
@testable import MiniGameTrainer

final class BloopyPlatformTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testFreshPlatformStaysPeachAfterFirstLanding() {
        let logic = makeIsolatedLandingLogic()
        let platformID = logic.platforms[0].id
        XCTAssertEqual(logic.platforms[0].appearance, .peach)
        XCTAssertEqual(logic.platforms[0].landingCount, 0)

        forceLanding(on: logic, platformID: platformID)
        let platform = logic.platforms.first { $0.id == platformID }
        XCTAssertEqual(logic.landingCount, 1)
        XCTAssertEqual(platform?.landingCount, 1)
        XCTAssertEqual(platform?.appearance, .peach)
    }

    func testSecondLandingTurnsPlatformRed() {
        let logic = makeIsolatedLandingLogic()
        let platformID = logic.platforms[0].id

        forceLanding(on: logic, platformID: platformID)
        XCTAssertEqual(logic.platforms.first { $0.id == platformID }?.appearance, .peach)

        logic.placeBallForTesting(
            position: CGPoint(x: logic.platforms[0].worldX, y: logic.ballPosition.y + 80),
            velocity: CGVector(dx: 0, dy: -40)
        )
        forceLanding(on: logic, platformID: platformID)

        let platform = logic.platforms.first { $0.id == platformID }
        XCTAssertEqual(logic.landingCount, 2)
        XCTAssertEqual(platform?.landingCount, 2)
        XCTAssertEqual(platform?.appearance, .red)
    }

    func testRedThresholdIsTwoLandings() {
        XCTAssertEqual(BloopyPlatform.redLandingThreshold, 2)
        var platform = BloopyPlatform(id: 1, worldX: 50, worldY: 20, width: 40, landingCount: 1)
        XCTAssertEqual(platform.appearance, .peach)
        platform.landingCount = 2
        XCTAssertEqual(platform.appearance, .red)
        platform.landingCount = 3
        XCTAssertEqual(platform.appearance, .red)
    }

    func testOnePhysicalLandingDoesNotIncrementTwiceFromOverlappingFrames() {
        let logic = makeIsolatedLandingLogic()
        let platform = logic.platforms[0]
        let top = logic.geometry.platformTop(worldY: platform.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius + 6),
            velocity: CGVector(dx: 0, dy: -180)
        )
        for _ in 0..<8 {
            logic.update(deltaTime: 1 / 240)
        }
        XCTAssertEqual(logic.landingCount, 1)
        XCTAssertEqual(logic.platforms[0].landingCount, 1)
        XCTAssertEqual(logic.platforms[0].appearance, .peach)
    }

    func testLandingCountBelongsToOnePlatformID() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let platformA = BloopyPlatform(id: 11, worldX: 120, worldY: 80, width: 50)
        let platformB = BloopyPlatform(id: 12, worldX: 240, worldY: 80, width: 50)
        logic.replacePlatformsForTesting([platformA, platformB])
        forceLanding(on: logic, platformID: platformA.id)
        forceLanding(on: logic, platformID: platformA.id)
        XCTAssertEqual(logic.platforms.first { $0.id == 11 }?.appearance, .red)
        XCTAssertEqual(logic.platforms.first { $0.id == 12 }?.appearance, .peach)
        XCTAssertEqual(logic.platforms.first { $0.id == 12 }?.landingCount, 0)
    }

    func testRecycledPlatformResetsDurability() {
        var generator = BloopyPlatformGenerator(config: .deterministic())
        let geometry = BloopyGeometry(sceneSize: sceneSize, config: .deterministic())
        let first = generator.initialPlatforms(geometry: geometry)[0]
        let next = generator.next(after: first, score: 0, geometry: geometry)
        XCTAssertNotEqual(next.id, first.id)
        XCTAssertEqual(next.landingCount, 0)
        XCTAssertEqual(next.appearance, .peach)
        XCTAssertTrue(next.isActive)
    }

    func testRedPlatformRemainsLandable() {
        let logic = makeIsolatedLandingLogic()
        let platformID = logic.platforms[0].id
        forceLanding(on: logic, platformID: platformID)
        forceLanding(on: logic, platformID: platformID)
        XCTAssertEqual(logic.platforms.first { $0.id == platformID }?.appearance, .red)
        XCTAssertTrue(logic.platforms.first { $0.id == platformID }?.isCollidable == true)

        logic.placeBallForTesting(
            position: CGPoint(x: logic.platforms[0].worldX, y: logic.ballPosition.y + 80),
            velocity: CGVector(dx: 0, dy: -40)
        )
        forceLanding(on: logic, platformID: platformID)
        XCTAssertEqual(logic.landingCount, 3)
        XCTAssertEqual(logic.platforms.first { $0.id == platformID }?.landingCount, 3)
        XCTAssertTrue(logic.platforms.first { $0.id == platformID }?.isCollidable == true)
    }

    func testStartingPlatformIsPeachAndDoesNotCountAsALanding() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.landingCount, 0)
        XCTAssertEqual(logic.platforms[0].appearance, .peach)
        XCTAssertEqual(logic.platforms[0].landingCount, 0)
    }

    func testGeneratedPlatformsStayInsideHorizontalPlayableBounds() {
        let seeds: [UInt64] = [17_602, 1, 42, 99, 1_234, 98_765]
        for seed in seeds {
            var config = BloopyGameConfig.deterministic(seed: seed)
            config.lookaheadPlatformCount = 8
            let geometry = BloopyGeometry(sceneSize: sceneSize, config: config)
            var generator = BloopyPlatformGenerator(config: config)
            var current = generator.initialPlatforms(geometry: geometry)[0]
            for score in [0, 50, 100, 200, 300, 400, 500, 600] {
                for _ in 0..<16 {
                    assertPlatformInsideBounds(current, geometry: geometry)
                    let next = generator.next(after: current, score: score, geometry: geometry)
                    assertPlatformInsideBounds(next, geometry: geometry)
                    current = next
                }
            }
        }
    }

    func testLiveGeneratedPlatformsStayInsideHorizontalBounds() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        for _ in 0..<400 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            for platform in logic.platforms {
                assertPlatformInsideBounds(platform, geometry: logic.geometry)
            }
        }
    }

    func testPlatformCountStaysBoundedOnLongAutoSteer() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var maxCount = 0
        var frames = 0
        while logic.state == .playing, frames < 10_000 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            maxCount = max(maxCount, logic.platforms.count)
            frames += 1
            XCTAssertTrue(logic.ballPosition.x.isFinite)
            XCTAssertTrue(logic.ballPosition.y.isFinite)
            XCTAssertFalse(logic.ballPosition.x.isNaN)
        }
        XCTAssertGreaterThanOrEqual(logic.score, 20, "Auto-steer should reach at least score 20")
        XCTAssertLessThan(maxCount, 28, "Platform count must stay bounded")
        XCTAssertLessThanOrEqual(logic.trailSamples.count, logic.trailCapacity)
    }

    func testLookaheadNeverExposesEmptyWorld() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        for _ in 0..<400 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            let ceiling = logic.cameraY + sceneSize.height
            let above = logic.platforms.filter { $0.worldY > logic.ballPosition.y }
            XCTAssertFalse(above.isEmpty)
            XCTAssertGreaterThan(logic.platforms.map(\.worldY).max() ?? 0, ceiling - 40)
        }
    }

    func testFailureWaitsUntilBallIsBelowCamera() {
        var config = BloopyGameConfig.deterministic()
        config.failureMarginHeightRatio = 0.02
        let logic = BloopyGameLogic(config: config, sceneSize: sceneSize)
        logic.start()
        logic.setHorizontalInput(.left)
        var frames = 0
        while logic.state == .playing, frames < 4_000 {
            logic.setHorizontalInput(frames % 2 == 0 ? .left : .right)
            logic.update(deltaTime: 1 / 60)
            frames += 1
        }
        if logic.state == .playing {
            while logic.score < 30, logic.state == .playing, frames < 6_000 {
                logic.applyAutoSteer()
                logic.update(deltaTime: 1 / 60)
                frames += 1
            }
            for _ in 0..<600 where logic.state == .playing {
                logic.setHorizontalInput(.left)
                logic.update(deltaTime: 1 / 240)
            }
        }
        if logic.isFinished {
            XCTAssertLessThan(logic.ballPosition.y + BloopyGeometry(sceneSize: sceneSize, config: config).ballRadius, logic.cameraY + 20)
        }
    }

    private func makeIsolatedLandingLogic() -> BloopyGameLogic {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let platform = BloopyPlatform(id: 501, worldX: 195, worldY: 90, width: 70)
        logic.replacePlatformsForTesting([platform])
        return logic
    }

    private func forceLanding(on logic: BloopyGameLogic, platformID: Int) {
        guard let platform = logic.platforms.first(where: { $0.id == platformID }) else {
            XCTFail("missing platform \(platformID)")
            return
        }
        let top = logic.geometry.platformTop(worldY: platform.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius + 18),
            velocity: CGVector(dx: 0, dy: -240)
        )
        let before = logic.landingCount
        var frames = 0
        while logic.landingCount == before, frames < 24 {
            logic.update(deltaTime: 1 / 60)
            frames += 1
        }
        XCTAssertEqual(logic.landingCount, before + 1)
        XCTAssertEqual(logic.lastLanding?.platformID, platformID)
    }

    private func assertPlatformInsideBounds(_ platform: BloopyPlatform, geometry: BloopyGeometry, file: StaticString = #filePath, line: UInt = #line) {
        let minX = platform.worldX - platform.width / 2
        let maxX = platform.worldX + platform.width / 2
        XCTAssertGreaterThanOrEqual(minX, geometry.playablePlatformMinX(width: platform.width) - platform.width / 2 - 1e-6, file: file, line: line)
        XCTAssertGreaterThanOrEqual(minX, geometry.platformHorizontalMargin - 1e-6, file: file, line: line)
        XCTAssertLessThanOrEqual(maxX, geometry.width - geometry.platformHorizontalMargin + 1e-6, file: file, line: line)
        XCTAssertGreaterThanOrEqual(platform.worldX, geometry.playablePlatformMinX(width: platform.width) - 1e-6, file: file, line: line)
        XCTAssertLessThanOrEqual(platform.worldX, geometry.playablePlatformMaxX(width: platform.width) + 1e-6, file: file, line: line)
    }
}
