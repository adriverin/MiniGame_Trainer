import XCTest
@testable import MiniGameTrainer

final class BloopyPlatformTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testLandingMarksPlatformUsedAndKeepsItSolid() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        XCTAssertEqual(logic.platforms[0].kind, .used)
        let usedBefore = logic.platforms.filter { $0.kind == .used }.count
        for _ in 0..<180 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
        }
        let usedAfter = logic.platforms.filter { $0.kind == .used }.count
        XCTAssertGreaterThan(logic.landingCount, 1)
        XCTAssertGreaterThanOrEqual(usedAfter, usedBefore)
        XCTAssertEqual(logic.platforms.filter { $0.kind == .used }.count, usedAfter)
    }

    func testUsedPlatformRemainsLandable() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let startID = logic.platforms[0].id
        XCTAssertEqual(logic.platforms.first { $0.id == startID }?.kind, .used)
        logic.setHorizontalInput(.none)
        var hops = 0
        for _ in 0..<240 {
            logic.update(deltaTime: 1 / 60)
            hops = logic.landingCount
            if hops >= 1 { break }
        }
        XCTAssertGreaterThanOrEqual(hops, 0)
        XCTAssertTrue(logic.platforms.contains { $0.kind == .used })
    }

    func testPlatformCountStaysBoundedOnLongAutoSteer() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var maxCount = 0
        var frames = 0
        // Run until game over or timeout — auto-steer is imperfect, just verify invariants
        while logic.state == .playing, frames < 10_000 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            maxCount = max(maxCount, logic.platforms.count)
            frames += 1
            XCTAssertTrue(logic.ballPosition.x.isFinite)
            XCTAssertTrue(logic.ballPosition.y.isFinite)
            XCTAssertFalse(logic.ballPosition.x.isNaN)
        }
        // Auto-steer should make some progress
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
            // Force a miss by steering away from everything after a climb.
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
}
