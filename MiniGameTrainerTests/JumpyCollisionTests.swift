import XCTest
@testable import MiniGameTrainer

final class JumpyCollisionTests: XCTestCase {
    func testSweptCollisionDetectsFastVehicleBetweenFrames() {
        XCTAssertTrue(JumpyCollision.sweptAABB(
            playerFrom: CGPoint(x: 0.5, y: 0), playerTo: CGPoint(x: 0.5, y: 0),
            playerSize: CGSize(width: 0.07, height: 0.40),
            vehicleFrom: CGPoint(x: 0.1, y: 0), vehicleTo: CGPoint(x: 0.9, y: 0),
            vehicleSize: CGSize(width: 0.14, height: 0.44)
        ))
    }

    func testDifferentRowAndNearMissDoNotCollide() {
        XCTAssertFalse(JumpyCollision.sweptAABB(
            playerFrom: CGPoint(x: 0.5, y: 0), playerTo: CGPoint(x: 0.5, y: 0),
            playerSize: CGSize(width: 0.07, height: 0.40),
            vehicleFrom: CGPoint(x: 0.1, y: 1), vehicleTo: CGPoint(x: 0.9, y: 1),
            vehicleSize: CGSize(width: 0.14, height: 0.44)
        ))
        XCTAssertFalse(JumpyCollision.sweptAABB(
            playerFrom: CGPoint(x: 0.5, y: 0), playerTo: CGPoint(x: 0.5, y: 0),
            playerSize: CGSize(width: 0.07, height: 0.40),
            vehicleFrom: CGPoint(x: 0.62, y: 0), vehicleTo: CGPoint(x: 0.62, y: 0),
            vehicleSize: CGSize(width: 0.14, height: 0.44)
        ))
    }

    func testDirectOverlapEndsGameExactlyOnce() {
        let logic = collisionLogic(laneRow: 0, centerX: 0.5)
        logic.update(deltaTime: 0.01)
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.drainEvents(), [.collided])
        logic.update(deltaTime: 1)
        XCTAssertTrue(logic.drainEvents().isEmpty)
    }

    func testSafeRowNeverCollides() {
        var config = JumpyGameConfig.reference
        config.randomSeed = 1
        let logic = JumpyGameLogic(config: config)
        logic.replaceRowsForTesting([JumpyWorldRow(worldRow: 0, kind: .safe)])
        logic.update(deltaTime: 0.1)
        XCTAssertFalse(logic.isFinished)
    }

    func testCarOnDifferentLogicalRowDoesNotCollide() {
        let logic = collisionLogic(laneRow: 1, centerX: 0.5)
        logic.update(deltaTime: 0.1)
        XCTAssertFalse(logic.isFinished)
    }

    func testPlayerCanCollideDuringHopBeforeLanding() {
        let logic = collisionLogic(laneRow: 1, centerX: 0.5)
        XCTAssertTrue(logic.requestMove(.up))
        logic.update(deltaTime: 0.1)
        logic.update(deltaTime: 0.03)
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.playerPosition.row, 0)
    }

    private func collisionLogic(laneRow: Int, centerX: CGFloat) -> JumpyGameLogic {
        var config = JumpyGameConfig.reference
        config.randomSeed = 1
        let logic = JumpyGameLogic(config: config)
        let lane = JumpyLane(id: 1, worldRow: laneRow, direction: .right, speed: 0, vehicleWidth: 0.16, spacing: 0.4, phaseOffset: centerX, vehicleCount: 1, phase: 0)
        logic.replaceRowsForTesting([
            JumpyWorldRow(worldRow: 0, kind: laneRow == 0 ? .road(lane) : .safe),
            JumpyWorldRow(worldRow: 1, kind: laneRow == 1 ? .road(lane) : .safe),
        ])
        return logic
    }
}
