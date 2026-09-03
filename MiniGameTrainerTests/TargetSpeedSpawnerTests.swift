import CoreGraphics
import XCTest
@testable import MiniGameTrainer

final class TargetSpeedSpawnerTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    private func makeLogic(seed: UInt64 = 2, mutate: (inout TargetSpeedGameConfig) -> Void = { _ in }) -> TargetSpeedGameLogic {
        var config = TargetSpeedGameConfig.reference
        mutate(&config)
        return TargetSpeedGameLogic(config: config, sceneSize: sceneSize, seed: seed)
    }

    func testGeneratedRadiiStayInsideConfiguredBands() {
        let logic = makeLogic(seed: 11)
        logic.spawnIntervalOverride = 0.05
        logic.lifetimeOverride = 4
        logic.maxActiveOverride = 5
        logic.start(at: 0)
        var time = 0.0
        var seen: [TargetSpeedSizeTier: Int] = [:]
        while time < 8 {
            logic.update(at: time)
            for target in logic.liveTargets(at: time) {
                let diameter = (target.radius * 2) / sceneSize.width
                let range = TargetSpeedGameConfig.reference.diameterRange(for: target.sizeTier)
                XCTAssertGreaterThanOrEqual(diameter, range.lowerBound - 0.002, "tier \(target.sizeTier)")
                XCTAssertLessThanOrEqual(diameter, range.upperBound + 0.002, "tier \(target.sizeTier)")
                XCTAssertGreaterThanOrEqual(diameter, 0.022 - 0.002)
                XCTAssertLessThanOrEqual(diameter, 0.228 + 0.002)
                seen[target.sizeTier, default: 0] += 1
            }
            if let target = logic.liveTargets(at: time).first {
                _ = logic.hit(id: target.id, at: time)
            }
            time += 1.0 / 60.0
        }
        XCTAssertFalse(seen.isEmpty)
    }

    func testEveryCenterAndRadiusStayInsidePlayfield() {
        let logic = makeLogic(seed: 4)
        logic.spawnIntervalOverride = 0.08
        logic.lifetimeOverride = 3
        logic.maxActiveOverride = 5
        logic.start(at: 0)
        var time = 0.0
        while time < 6 {
            logic.update(at: time)
            for target in logic.targets {
                XCTAssertTrue(
                    logic.geometry.isFullyContained(center: target.center, radius: target.radius),
                    "target \(target.id) escaped playfield"
                )
            }
            if let target = logic.liveTargets(at: time).first {
                _ = logic.hit(id: target.id, at: time)
            }
            time += 1.0 / 60.0
        }
    }

    func testSpawnedTargetsRespectMinimumSeparation() {
        let logic = makeLogic(seed: 7)
        logic.spawnIntervalOverride = 0.05
        logic.lifetimeOverride = 2.5
        logic.maxActiveOverride = 5
        logic.start(at: 0)
        var time = 0.0
        var sawDense = false
        while time < 5 {
            logic.update(at: time)
            let live = logic.liveTargets(at: time)
            if live.count >= 4 { sawDense = true }
            for i in 0..<live.count {
                for j in (i + 1)..<live.count {
                    let dx = live[i].center.x - live[j].center.x
                    let dy = live[i].center.y - live[j].center.y
                    let minimum = live[i].radius + live[j].radius + logic.geometry.overlapPadding
                    XCTAssertGreaterThanOrEqual(
                        hypot(dx, dy) + 1e-6,
                        minimum,
                        "targets \(live[i].id) and \(live[j].id) overlap"
                    )
                }
            }
            time += 1.0 / 60.0
        }
        XCTAssertTrue(sawDense)
    }

    func testSpawnerNeverExceedsConfiguredMaximum() {
        let logic = makeLogic(seed: 5)
        logic.spawnIntervalOverride = 0.02
        logic.lifetimeOverride = 1.5
        logic.maxActiveOverride = 4
        logic.start(at: 0)
        var time = 0.0
        while time < 4 {
            logic.update(at: time)
            XCTAssertLessThanOrEqual(logic.liveTargets(at: time).count, 4)
            time += 1.0 / 120.0
        }
    }

    func testSpawnCountIsTimestampDrivenNotFrameRateDriven() {
        func spawnCount(hz: Double) -> Int {
            let logic = makeLogic(seed: 8) { $0.maximumActiveTargets = 8 }
            logic.spawnIntervalOverride = 0.20
            logic.lifetimeOverride = 3
            logic.maxActiveOverride = 8
            logic.radiusOverride = 12
            logic.start(at: 0)
            var time = 0.0
            let dt = 1 / hz
            while time <= 1.40 {
                logic.update(at: time)
                time += dt
            }
            return logic.targets.count + logic.hits
        }
        XCTAssertEqual(spawnCount(hz: 60), spawnCount(hz: 120))
        XCTAssertEqual(spawnCount(hz: 60), 6)
    }

    func testNearestCenterWinsWhenTwoTargetsCoverThePoint() {
        var config = TargetSpeedGameConfig.reference
        config.overlapPaddingRatio = 0
        config.minimumHitRadiusRatio = 0
        let left = TargetSpeedTargetState(
            id: 1,
            center: CGPoint(x: 180, y: 360),
            radius: 80,
            spawnedAt: 0,
            expiresAt: 2,
            pointValue: 1,
            sizeTier: .large
        )
        let right = TargetSpeedTargetState(
            id: 2,
            center: CGPoint(x: 250, y: 360),
            radius: 80,
            spawnedAt: 0,
            expiresAt: 2,
            pointValue: 1,
            sizeTier: .large
        )
        let geometry = TargetSpeedGeometry(sceneSize: sceneSize, config: config)
        let chosen = geometry.nearestTarget(at: CGPoint(x: 200, y: 360), among: [left, right], time: 0.1)
        XCTAssertEqual(chosen?.id, 1)
    }
}
