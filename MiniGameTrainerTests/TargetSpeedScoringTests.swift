import CoreGraphics
import XCTest
@testable import MiniGameTrainer

final class TargetSpeedScoringTests: XCTestCase {
    func testConstantOnePointIndependentOfSizeAndReaction() {
        XCTAssertEqual(TargetSpeedScoring.points(forHit: .reference), 1)
        XCTAssertEqual(TargetSpeedScoring.points(diameterRatio: 0.193, reactionTime: 0.12), 1)
        XCTAssertEqual(TargetSpeedScoring.points(diameterRatio: 0.090, reactionTime: 0.40), 1)
        XCTAssertEqual(TargetSpeedScoring.points(diameterRatio: 0.030, reactionTime: 0.08), 1)
        XCTAssertEqual(TargetSpeedScoring.points(diameterRatio: 0.228, reactionTime: 1.10), 1)
    }

    func testVideoFixturesLargeMediumTinyAllAwardOne() {
        // Recording transitions at 10 fps: 0→1 (t=3.195, large), 2→3 (t=4.293, ~0.097),
        // 22→23 (t=13.578, ~0.046 still on screen). All measured deltas were +1.
        let logic = TargetSpeedGameLogic(
            config: .reference,
            sceneSize: CGSize(width: 390, height: 844),
            seed: 1
        )
        logic.lifetimeOverride = 2
        logic.spawnIntervalOverride = 0.01
        logic.maxActiveOverride = 1
        logic.positionOverride = CGPoint(x: 200, y: 360)
        let fixtures: [(CGFloat, TimeInterval)] = [
            (390 * 0.193 / 2, 0.20),
            (390 * 0.097 / 2, 0.35),
            (390 * 0.046 / 2, 0.15),
        ]
        logic.start(at: 0)
        var time: TimeInterval = 0.35
        for (index, fixture) in fixtures.enumerated() {
            logic.radiusOverride = fixture.0
            logic.update(at: time)
            guard let target = logic.liveTargets(at: time).last else {
                return XCTFail("Missing target \(index)")
            }
            let before = logic.score
            let tapTime = time + fixture.1
            let outcome = logic.handleTap(at: target.center, time: tapTime)
            XCTAssertEqual(outcome, .hit(id: target.id, score: before + 1, points: 1))
            time = tapTime + 0.02
        }
        XCTAssertEqual(logic.score, 3)
    }
}
