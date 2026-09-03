import CoreGraphics
import XCTest
@testable import MiniGameTrainer

final class TargetSpeedGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    private func makeLogic(
        seed: UInt64 = 1,
        mutate: (inout TargetSpeedGameConfig) -> Void = { _ in }
    ) -> TargetSpeedGameLogic {
        var config = TargetSpeedGameConfig.reference
        mutate(&config)
        return TargetSpeedGameLogic(config: config, sceneSize: sceneSize, seed: seed)
    }

    func testSuccessfulHitRemovesTargetOnceAndAddsExactValue() {
        let logic = makeLogic()
        logic.lifetimeOverride = 2
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 195, y: 360)
        logic.radiusOverride = 40
        logic.start(at: 0)
        logic.update(at: 0.35)
        XCTAssertEqual(logic.liveTargets(at: 0.35).count, 1)
        let target = logic.liveTargets(at: 0.35)[0]
        let outcome = logic.handleTap(at: target.center, time: 0.50)
        XCTAssertEqual(outcome, .hit(id: target.id, score: 1, points: 1))
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.lives, 3)
        XCTAssertEqual(logic.hits, 1)
        XCTAssertTrue(logic.liveTargets(at: 0.50).allSatisfy { $0.id != target.id })
        XCTAssertEqual(logic.handleTap(at: target.center, time: 0.51), .ignored)
        XCTAssertEqual(logic.score, 1)
    }

    func testExpiredTouchDoesNotScoreAndMissProcessesOnce() {
        let logic = makeLogic()
        logic.lifetimeOverride = 0.40
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 195, y: 360)
        logic.radiusOverride = 40
        logic.start(at: 0)
        logic.update(at: 0.35)
        let target = logic.liveTargets(at: 0.35)[0]
        logic.update(at: 0.76)
        XCTAssertEqual(logic.lives, 2)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.misses, 1)
        XCTAssertEqual(logic.handleTap(at: target.center, time: 0.80), .ignored)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.misses, 1)
        XCTAssertEqual(logic.lives, 2)
    }

    func testExactDeadlineIsInclusiveHit() {
        let logic = makeLogic()
        logic.lifetimeOverride = 0.50
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 195, y: 360)
        logic.radiusOverride = 40
        logic.start(at: 0)
        logic.update(at: 0.35)
        let target = logic.liveTargets(at: 0.35)[0]
        XCTAssertEqual(target.expiresAt, 0.85, accuracy: 1e-12)
        let outcome = logic.handleTap(at: target.center, time: target.expiresAt)
        XCTAssertEqual(outcome, .hit(id: target.id, score: 1, points: 1))
        XCTAssertEqual(logic.lives, 3)
        XCTAssertEqual(logic.misses, 0)
    }

    func testTouchJustAfterDeadlineIsAMiss() {
        let logic = makeLogic()
        logic.lifetimeOverride = 0.50
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 195, y: 360)
        logic.radiusOverride = 40
        logic.start(at: 0)
        logic.update(at: 0.35)
        let target = logic.liveTargets(at: 0.35)[0]
        logic.update(at: target.expiresAt + 0.0001)
        XCTAssertEqual(logic.lives, 2)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.handleTap(at: target.center, time: target.expiresAt + 0.0001), .ignored)
    }

    func testMissDropsExactlyOneLifeOnce() {
        let logic = makeLogic()
        logic.lifetimeOverride = 0.30
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.start(at: 0)
        logic.update(at: 0.35)
        XCTAssertEqual(logic.lives, 3)
        logic.update(at: 0.66)
        XCTAssertEqual(logic.lives, 2)
        logic.update(at: 0.70)
        logic.update(at: 0.80)
        XCTAssertEqual(logic.lives, 2)
        XCTAssertEqual(logic.misses, 1)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .playing)
    }

    func testLastLifeEndsTheSessionExactlyOnce() {
        let logic = makeLogic()
        logic.lifetimeOverride = 0.20
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.livesOverride = 1
        logic.start(at: 0)
        logic.update(at: 0.35)
        XCTAssertEqual(logic.lives, 1)
        logic.update(at: 0.56)
        XCTAssertEqual(logic.lives, 0)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.endReason, .outOfLives)
        XCTAssertTrue(logic.hasTerminated)
        logic.update(at: 0.80)
        XCTAssertEqual(logic.misses, 1)
        XCTAssertTrue(logic.isFinished)
    }

    func testBackgroundTapIsIgnored() {
        let logic = makeLogic()
        logic.lifetimeOverride = 2
        logic.spawnIntervalOverride = 10
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 195, y: 360)
        logic.radiusOverride = 30
        logic.start(at: 0)
        logic.update(at: 0.35)
        XCTAssertEqual(logic.handleTap(at: CGPoint(x: 20, y: 20), time: 0.40), .ignored)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.lives, 3)
        XCTAssertEqual(logic.ignoredTaps, 1)
        XCTAssertEqual(logic.liveTargets(at: 0.40).count, 1)
    }

    func testRapidTapsEachScoreOnce() {
        let logic = makeLogic()
        logic.lifetimeOverride = 2
        logic.spawnIntervalOverride = 0.05
        logic.maxActiveOverride = 3
        logic.start(at: 0)
        var seen = Set<Int>()
        for step in 0..<40 {
            let time = 0.35 + Double(step) * (1.0 / 120.0)
            logic.update(at: time)
            for target in logic.liveTargets(at: time) where !seen.contains(target.id) {
                let before = logic.score
                let outcome = logic.handleTap(at: target.center, time: time)
                if case .hit(let id, _, _) = outcome {
                    XCTAssertFalse(seen.contains(id))
                    seen.insert(id)
                    XCTAssertEqual(logic.score, before + 1)
                    XCTAssertEqual(logic.handleTap(at: target.center, time: time + 0.0001), .ignored)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(seen.count, 3)
        XCTAssertEqual(logic.score, seen.count)
    }

    func testSixtyAndOneTwentyHertzProduceIdenticalState() {
        func run(hz: Double) -> (Int, Int, Int, Int) {
            let logic = makeLogic(seed: 9)
            logic.lifetimeOverride = 0.80
            logic.spawnIntervalOverride = 0.25
            logic.maxActiveOverride = 3
            logic.start(at: 0)
            let dt = 1 / hz
            var time = 0.0
            while time <= 2.4 {
                logic.update(at: time)
                if let target = logic.liveTargets(at: time).first, time >= 0.50, logic.score < 3 {
                    _ = logic.handleTap(at: target.center, time: time)
                }
                time += dt
            }
            return (logic.score, logic.lives, logic.hits, logic.liveTargets(at: 2.4).count)
        }
        let at60 = run(hz: 60)
        let at120 = run(hz: 120)
        XCTAssertEqual(at60.0, at120.0)
        XCTAssertEqual(at60.1, at120.1)
        XCTAssertEqual(at60.2, at120.2)
        XCTAssertEqual(at60.3, at120.3)
    }

    func testLongRunStaysFinitePastScore1000() {
        let logic = makeLogic(seed: 3)
        logic.autoPlayToScore(1000)
        XCTAssertGreaterThanOrEqual(logic.score, 1000)
        XCTAssertLessThanOrEqual(logic.liveTargets(at: logic.lastSimulationTimestamp ?? 0).count, logic.config.maximumActiveTargets)
        XCTAssertGreaterThanOrEqual(logic.score, 0)
        for target in logic.targets {
            XCTAssertGreaterThan(target.radius, 0)
            XCTAssertGreaterThan(target.lifetime, 0)
            XCTAssertFalse(target.radius.isNaN)
            XCTAssertFalse(target.lifetime.isNaN)
        }
        let snap = logic.difficultySnapshot(at: 10_000)
        XCTAssertEqual(snap.lifetime, TargetSpeedGameConfig.reference.minimumLifetime, accuracy: 1e-12)
        XCTAssertEqual(snap.spawnInterval, TargetSpeedGameConfig.reference.minimumSpawnInterval, accuracy: 1e-12)
        XCTAssertEqual(snap.maxActive, TargetSpeedGameConfig.reference.maximumActiveTargets)
    }
}

private extension TargetSpeedGameLogic {
    func autoPlayToScore(_ goal: Int) {
        start(at: 0)
        var time = 0.0
        let dt = 1.0 / 60.0
        var guardCount = 0
        while score < goal, state == .playing, guardCount < 80_000 {
            update(at: time)
            if let target = liveTargets(at: time).min(by: { $0.spawnedAt < $1.spawnedAt }),
               target.elapsed(at: time) >= 0.05 {
                _ = hit(id: target.id, at: time)
            }
            time += dt
            guardCount += 1
        }
        XCTAssertGreaterThanOrEqual(score, goal, "auto-play failed to reach \(goal)")
    }
}
