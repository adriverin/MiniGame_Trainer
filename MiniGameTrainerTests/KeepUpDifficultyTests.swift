import XCTest
@testable import MiniGameTrainer

final class KeepUpDifficultyTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)
    private let model = KeepUpDifficultyModel(config: .reference)

    private func makeLogic(
        scoreOverride: Int? = nil,
        _ mutate: (inout KeepUpGameConfig) -> Void = { _ in }
    ) -> KeepUpGameLogic {
        var config = KeepUpGameConfig.reference
        mutate(&config)
        let logic = KeepUpGameLogic(config: config, sceneSize: sceneSize)
        logic.physicsScoreOverride = scoreOverride
        logic.start()
        return logic
    }

    @discardableResult
    private func autoCatch(
        _ logic: KeepUpGameLogic,
        targetScore: Int,
        hz: Double = 120,
        platformY: CGFloat? = nil,
        offset: CGFloat = 0
    ) -> Int {
        let y = platformY ?? logic.geometry.sceneSize.height * logic.config.startingPlatformYRatio
        var frames = 0
        while logic.score < targetScore, !logic.isFinished, frames < targetScore * 1_000 + 2_000 {
            let targetX = logic.ballPosition.x - offset * logic.geometry.effectiveCatchRadius
            logic.setPlatformPosition(CGPoint(x: targetX, y: y))
            logic.update(deltaTime: 1 / hz)
            frames += 1
        }
        return frames
    }

    func testReferenceAnchors() {
        XCTAssertEqual(model.physicsSpeedScale(forScore: 0), 1.00, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 10), 1.00, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 20), 1.08, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 30), 1.40, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 40), 2.15, accuracy: 1e-12)
    }

    func testMonotonicDifficultyAtCalibratedAnchors() {
        XCTAssertGreaterThanOrEqual(model.physicsSpeedScale(forScore: 10), model.physicsSpeedScale(forScore: 0))
        XCTAssertGreaterThanOrEqual(model.physicsSpeedScale(forScore: 20), model.physicsSpeedScale(forScore: 10))
        XCTAssertGreaterThanOrEqual(model.physicsSpeedScale(forScore: 30), model.physicsSpeedScale(forScore: 20))
        XCTAssertGreaterThanOrEqual(model.physicsSpeedScale(forScore: 40), model.physicsSpeedScale(forScore: 30))
        XCTAssertGreaterThan(model.physicsSpeedScale(forScore: 20), model.physicsSpeedScale(forScore: 0))
        XCTAssertGreaterThan(model.physicsSpeedScale(forScore: 40), model.physicsSpeedScale(forScore: 20))
    }

    func testInterpolationBetweenAnchors() {
        XCTAssertEqual(model.physicsSpeedScale(forScore: 25), 1.24, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 35), 1.775, accuracy: 1e-12)
    }

    func testScoreOneHundredDoesNotExceedConfiguredMaximum() {
        let cap = model.physicsSpeedScale(forScore: 40)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 100), cap, accuracy: 1e-12)
        XCTAssertEqual(model.physicsSpeedScale(forScore: 10_000), cap, accuracy: 1e-12)
        XCTAssertEqual(
            model.gravity(forScore: 100, sceneHeight: 852),
            model.gravity(forScore: 40, sceneHeight: 852),
            accuracy: 1e-12
        )
    }

    func testNegativeScoreMatchesScoreZero() {
        XCTAssertEqual(model.physicsSpeedScale(forScore: -5), model.physicsSpeedScale(forScore: 0), accuracy: 1e-12)
    }

    func testTimeScaleAppliesVelocityLinearAndGravityQuadratic() {
        let height: CGFloat = 852
        let width: CGFloat = 393
        let s40 = model.physicsSpeedScale(forScore: 40)
        XCTAssertEqual(
            model.bounceImpulse(forScore: 40, sceneHeight: height),
            model.bounceImpulse(forScore: 0, sceneHeight: height) * s40,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            model.gravity(forScore: 40, sceneHeight: height),
            model.gravity(forScore: 0, sceneHeight: height) * s40 * s40,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            model.maximumHorizontalBounceSpeed(forScore: 40, sceneWidth: width),
            model.maximumHorizontalBounceSpeed(forScore: 0, sceneWidth: width) * s40,
            accuracy: 1e-9
        )
    }

    func testLogicExposesScoreDependentPhysics() {
        let early = makeLogic(scoreOverride: 0)
        let late = makeLogic(scoreOverride: 40)
        let s40 = model.physicsSpeedScale(forScore: 40)
        XCTAssertEqual(early.physicsSpeedScale, 1, accuracy: 1e-12)
        XCTAssertEqual(late.physicsSpeedScale, s40, accuracy: 1e-12)
        XCTAssertEqual(late.gravity, early.gravity * s40 * s40, accuracy: 1e-6)
        XCTAssertEqual(late.bounceImpulse, early.bounceImpulse * s40, accuracy: 1e-6)
        XCTAssertEqual(late.maximumHorizontalBounceSpeed, early.maximumHorizontalBounceSpeed * s40, accuracy: 1e-6)
    }

    func testStandardizedAnchorTimingsUseTheSamePlatformY() {
        let platformY = sceneSize.height * KeepUpGameConfig.reference.startingPlatformYRatio
        let offset: CGFloat = 0.35
        var report: [String] = []
        var previousCycle = TimeInterval.infinity
        for score in [0, 10, 20, 30, 40] {
            let sample = measureCycle(score: score, platformY: platformY, offset: offset)
            XCTAssertGreaterThan(sample.up, 0)
            XCTAssertGreaterThan(sample.down, 0)
            XCTAssertGreaterThan(sample.cycle, 0)
            XCTAssertLessThanOrEqual(sample.cycle, previousCycle + 0.002)
            previousCycle = sample.cycle
            XCTAssertEqual(sample.platformY, platformY, accuracy: 0.5)
            report.append(
                String(
                    format: "score %d  s=%.2f  up=%.3f  down=%.3f  cycle=%.3f  |VX|=%.1f",
                    score,
                    Double(model.physicsSpeedScale(forScore: score)),
                    sample.up,
                    sample.down,
                    sample.cycle,
                    Double(abs(sample.vx))
                )
            )
        }
        XCTAssertEqual(report.count, 5)
        let slow = measureCycle(score: 0, platformY: platformY, offset: 0)
        let fast = measureCycle(score: 40, platformY: platformY, offset: 0)
        XCTAssertEqual(slow.cycle / fast.cycle, 2.15, accuracy: 0.08)
        XCTAssertEqual(slow.up / fast.up, 2.15, accuracy: 0.08)
        _ = report
    }

    func testTimeScalingPreservesSpatialTrajectory() {
        let slow = makeLogic(scoreOverride: 0) {
            $0.startingHorizontalVelocityWidthRatio = 0.28
            $0.startingVerticalVelocityHeightRatio = 2.0
            $0.startingBallYRatio = 0.48
            $0.startingPlatformYRatio = 0
        }
        let fast = makeLogic(scoreOverride: 40) {
            $0.startingHorizontalVelocityWidthRatio = 0.28
            $0.startingVerticalVelocityHeightRatio = 2.0
            $0.startingBallYRatio = 0.48
            $0.startingPlatformYRatio = 0
        }
        slow.setPlatformPosition(.zero)
        fast.setPlatformPosition(.zero)
        let scale = model.physicsSpeedScale(forScore: 40)
        var slowPath: [(TimeInterval, CGPoint)] = []
        var fastPath: [(TimeInterval, CGPoint)] = []
        let step = 1.0 / 240.0
        for _ in 0..<240 {
            slow.update(deltaTime: step)
            slowPath.append((slow.elapsedTime, slow.ballPosition))
        }
        for _ in 0..<120 {
            fast.update(deltaTime: step)
            fastPath.append((fast.elapsedTime, fast.ballPosition))
        }
        XCTAssertGreaterThan(slow.ceilingContactCount, 0)
        XCTAssertGreaterThan(fast.ceilingContactCount, 0)
        XCTAssertEqual(slow.score, 0)
        XCTAssertEqual(fast.score, 0)
        for sample in fastPath where sample.0 > 0.02 && sample.0 < 0.20 {
            let target = sample.0 * Double(scale)
            guard let index = slowPath.indices.dropFirst().dropLast().first(where: { slowPath[$0].0 >= target }) else { continue }
            let later = slowPath[index]
            let earlier = slowPath[index - 1]
            let span = later.0 - earlier.0
            let t = span > 0 ? (target - earlier.0) / span : 0
            let expected = CGPoint(
                x: earlier.1.x + (later.1.x - earlier.1.x) * t,
                y: earlier.1.y + (later.1.y - earlier.1.y) * t
            )
            XCTAssertEqual(sample.1.x, expected.x, accuracy: 2.0, "X drifted at t=\(sample.0)")
            XCTAssertEqual(sample.1.y, expected.y, accuracy: 2.0, "Y drifted at t=\(sample.0)")
        }
    }

    func testEarlyAndLateDifficultyAreEquivalentAtSixtyAndOneTwentyHertz() {
        for score in [0, 40] {
            func run(hz: Double) -> KeepUpGameLogic {
                let logic = makeLogic(scoreOverride: score) {
                    $0.startingHorizontalVelocityWidthRatio = 0.22
                    $0.startingVerticalVelocityHeightRatio = -0.20
                    $0.startingBallYRatio = 0.42
                    $0.startingPlatformYRatio = 0.20
                }
                let y = sceneSize.height * 0.20
                let duration = 0.85
                let frames = Int((duration * hz).rounded())
                for frame in 0..<frames {
                    let time = Double(frame) / hz
                    let wave = y + 18 * CGFloat(sin(time * 6))
                    logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x, y: wave))
                    logic.update(deltaTime: 1 / hz)
                }
                return logic
            }
            let sixty = run(hz: 60)
            let oneTwenty = run(hz: 120)
            XCTAssertEqual(sixty.score, oneTwenty.score, "score mismatch at physics score \(score)")
            XCTAssertEqual(sixty.ceilingContactCount, oneTwenty.ceilingContactCount, "ceiling mismatch at \(score)")
            XCTAssertGreaterThan(sixty.ceilingContactCount, 0)
            XCTAssertGreaterThan(sixty.score, 0)
            XCTAssertEqual(sixty.ballPosition.x, oneTwenty.ballPosition.x, accuracy: 2.5)
            XCTAssertEqual(sixty.ballPosition.y, oneTwenty.ballPosition.y, accuracy: 2.5)
            XCTAssertEqual(sixty.ballVelocity.dx, oneTwenty.ballVelocity.dx, accuracy: 4.0)
            XCTAssertEqual(sixty.ballVelocity.dy, oneTwenty.ballVelocity.dy, accuracy: 4.0)
        }
    }

    func testTwoHundredCatchesRemainStableAtCappedDifficulty() {
        let logic = makeLogic(scoreOverride: 100) { $0.startingHorizontalVelocityWidthRatio = 0.22 }
        let frames = autoCatch(logic, targetScore: 200)
        XCTAssertEqual(logic.score, 200, "Auto-catch timed out after \(frames) frames")
        XCTAssertEqual(logic.physicsSpeedScale, model.physicsSpeedScale(forScore: 40), accuracy: 1e-12)
        XCTAssertFalse(logic.isFinished)
        XCTAssertTrue(logic.ballPosition.x.isFinite && logic.ballPosition.y.isFinite)
        XCTAssertTrue(logic.ballVelocity.dx.isFinite && logic.ballVelocity.dy.isFinite)
        XCTAssertLessThanOrEqual(logic.ballPosition.y, logic.geometry.maximumBallY + 1e-4)
    }

    func testStandardizedImpactOffsetHorizontalSpeedScales() {
        let platformY = sceneSize.height * KeepUpGameConfig.reference.startingPlatformYRatio
        let early = measureCycle(score: 0, platformY: platformY, offset: 0.5)
        let late = measureCycle(score: 40, platformY: platformY, offset: 0.5)
        XCTAssertGreaterThan(abs(early.vx), 0)
        XCTAssertEqual(abs(late.vx) / abs(early.vx), 2.15, accuracy: 0.12)
    }

    private struct CycleSample {
        var up: TimeInterval
        var down: TimeInterval
        var cycle: TimeInterval
        var vx: CGFloat
        var platformY: CGFloat
    }

    private func measureCycle(score: Int, platformY: CGFloat, offset: CGFloat) -> CycleSample {
        let logic = makeLogic(scoreOverride: score) { $0.startingHorizontalVelocityWidthRatio = 0 }
        autoCatch(logic, targetScore: 1, platformY: platformY, offset: offset)
        let vx = logic.ballVelocity.dx
        let bounceTime = logic.elapsedTime
        var up: TimeInterval = 0
        let ceilingsAtBounce = logic.ceilingContactCount
        var frames = 0
        while logic.ceilingContactCount == ceilingsAtBounce, !logic.isFinished, frames < 4_000 {
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x - offset * logic.geometry.effectiveCatchRadius, y: platformY))
            logic.update(deltaTime: 1.0 / 240.0)
            frames += 1
        }
        up = logic.elapsedTime - bounceTime
        let scoreAfterBounce = logic.score
        while logic.score == scoreAfterBounce, !logic.isFinished, frames < 8_000 {
            logic.setPlatformPosition(CGPoint(x: logic.ballPosition.x - offset * logic.geometry.effectiveCatchRadius, y: platformY))
            logic.update(deltaTime: 1.0 / 240.0)
            frames += 1
        }
        let down = logic.lastCeilingToPlatformTime
        return CycleSample(up: up, down: down, cycle: up + down, vx: vx, platformY: logic.lastCatchPlatformY)
    }
}
