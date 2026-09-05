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

    func testVehicleWrapDoesNotSweepAcrossInterior() {
        var config = JumpyGameConfig.reference
        config.randomSeed = 1
        let logic = JumpyGameLogic(config: config)
        let lane = JumpyLane(
            id: 7,
            worldRow: 0,
            direction: .right,
            speed: 0.40,
            vehicleWidth: 0.13,
            vehicleOffsets: [1.61],
            groupStartIndices: [0],
            cycleLength: 1.64,
            phase: 0
        )
        logic.replaceRowsForTesting([JumpyWorldRow(worldRow: 0, kind: .road(lane))])
        logic.update(deltaTime: 0.10)
        XCTAssertFalse(logic.isFinished)
    }

    func testPresentationProjectionDoesNotChangeLogicalCollision() {
        var flat = JumpyGameConfig.reference
        flat.projectionDepthFalloff = 0
        var deep = JumpyGameConfig.reference
        deep.projectionDepthFalloff = 0.10
        let first = collisionLogic(config: flat, laneRow: 0, centerX: 0.5)
        let second = collisionLogic(config: deep, laneRow: 0, centerX: 0.5)
        first.update(deltaTime: 0.01)
        second.update(deltaTime: 0.01)
        XCTAssertEqual(first.isFinished, second.isFinished)
        XCTAssertTrue(first.isFinished)
    }

    private func collisionLogic(laneRow: Int, centerX: CGFloat) -> JumpyGameLogic {
        var config = JumpyGameConfig.reference
        config.randomSeed = 1
        return collisionLogic(config: config, laneRow: laneRow, centerX: centerX)
    }

    private func collisionLogic(config: JumpyGameConfig, laneRow: Int, centerX: CGFloat) -> JumpyGameLogic {
        let logic = JumpyGameLogic(config: config)
        let lane = JumpyLane(
            id: 1,
            worldRow: laneRow,
            direction: .right,
            speed: 0,
            vehicleWidth: 0.16,
            vehicleOffsets: [centerX + config.trafficMargin],
            groupStartIndices: [0],
            cycleLength: 1 + config.trafficMargin * 2,
            phase: 0
        )
        logic.replaceRowsForTesting([
            JumpyWorldRow(worldRow: 0, kind: laneRow == 0 ? .road(lane) : .safe),
            JumpyWorldRow(worldRow: 1, kind: laneRow == 1 ? .road(lane) : .safe),
        ])
        return logic
    }
}
