import XCTest
@testable import MiniGameTrainer

final class JumpyGameLogicTests: XCTestCase {
    func testStartsCenteredAtZero() {
        let logic = makeSafeLogic()
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 0, column: 3))
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.facing, .up)
    }

    func testTapAndSwipeUpMoveForwardOneTile() {
        for move in [JumpyMove.up, .up] {
            let logic = makeSafeLogic()
            XCTAssertTrue(logic.requestMove(move))
            finishHop(logic)
            XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 1, column: 3))
            XCTAssertEqual(logic.score, 1)
        }
    }

    func testEverySwipeMovesOnOnlyItsWorldAxis() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 2, column: 3), score: 2)
        XCTAssertTrue(logic.requestMove(.left)); finishHop(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 2))
        XCTAssertTrue(logic.requestMove(.right)); finishHop(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 3))
        XCTAssertTrue(logic.requestMove(.down)); finishHop(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 1, column: 3))
        XCTAssertTrue(logic.requestMove(.up)); finishHop(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 3))
    }

    func testTapMovesUpAfterFacingLeftRightAndDown() {
        for firstMove in [JumpyMove.left, .right, .down] {
            let start = JumpyGridPosition(row: 2, column: 3)
            let logic = makeSafeLogic(position: start, score: 2)
            XCTAssertTrue(logic.requestMove(firstMove)); finishHop(logic)
            let beforeTap = logic.playerPosition
            XCTAssertTrue(logic.requestMove(.up)); finishHop(logic)
            XCTAssertEqual(logic.playerPosition.row, beforeTap.row + 1)
            XCTAssertEqual(logic.playerPosition.column, beforeTap.column)
        }
    }

    func testRapidDoubleTapChainsTwoForwardHops() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.acceptsInput)
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertEqual(logic.pendingMoves, [.up])
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.playerPosition.row, 0)
        advance(logic, by: logic.config.hopDuration * 2)
        XCTAssertEqual(logic.playerPosition.row, 2)
        XCTAssertEqual(logic.score, 2)
        XCTAssertNil(logic.hop)
        XCTAssertTrue(logic.pendingMoves.isEmpty)
    }

    func testRapidTripleTapIsThreeSequentialHopsNotTeleport() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertEqual(logic.playerPosition.row, 0)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.pendingMoves, [.up, .up])

        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition.row, 1)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.hop?.move, .up)
        XCTAssertEqual(logic.pendingMoves, [.up])

        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition.row, 2)
        XCTAssertEqual(logic.score, 2)
        XCTAssertEqual(logic.hop?.move, .up)

        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition.row, 3)
        XCTAssertEqual(logic.score, 3)
        XCTAssertNil(logic.hop)
        XCTAssertTrue(logic.pendingMoves.isEmpty)
    }

    func testMixedRapidQueuePreservesFIFOOrder() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.left))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.right))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertEqual(logic.pendingMoves, [.left, .up, .right, .up])
        advanceUntilIdle(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 3, column: 3))
        XCTAssertEqual(logic.score, 3)
        XCTAssertEqual(logic.facing, .up)
        XCTAssertEqual(logic.forwardJumps, 3)
        XCTAssertEqual(logic.sidewaysJumps, 2)
    }

    func testQueuedTapAfterLeftHopIsForwardNotLeft() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 2, column: 3), score: 2)
        XCTAssertTrue(logic.requestMove(.left))
        XCTAssertEqual(logic.facing, .left)
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertEqual(logic.pendingMoves, [.up])
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 2))
        XCTAssertEqual(logic.hop?.move, .up)
        XCTAssertEqual(logic.facing, .up)
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 3, column: 2))
        XCTAssertEqual(logic.score, 3)
    }

    func testQueuedTapAfterDownHopIsForward() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 2, column: 3), score: 2)
        XCTAssertTrue(logic.requestMove(.down))
        XCTAssertTrue(logic.requestMove(.up))
        advanceUntilIdle(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 3))
        XCTAssertEqual(logic.facing, .up)
        XCTAssertEqual(logic.score, 2)
    }

    func testInvalidQueuedBoundaryMoveIsSkippedWithoutPausing() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 2, column: 0), score: 2)
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.left))
        XCTAssertTrue(logic.requestMove(.up))
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 3, column: 0))
        XCTAssertEqual(logic.hop?.move, .up)
        XCTAssertTrue(logic.pendingMoves.isEmpty)
        XCTAssertEqual(logic.totalJumps, 2)
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 4, column: 0))
        XCTAssertEqual(logic.score, 4)
    }

    func testInvalidQueuedDownDoesNotStallFollowingCommand() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.right))
        XCTAssertTrue(logic.requestMove(.down))
        XCTAssertTrue(logic.requestMove(.up))
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 0, column: 4))
        XCTAssertEqual(logic.hop?.move, .up)
        advance(logic, by: logic.config.hopDuration)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 1, column: 4))
        XCTAssertEqual(logic.score, 1)
    }

    func testPendingQueueNeverExceedsCapacityAndKeepsEarliestCommands() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.left))
        XCTAssertTrue(logic.requestMove(.right))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.down))
        XCTAssertFalse(logic.requestMove(.left))
        XCTAssertFalse(logic.requestMove(.right))
        XCTAssertEqual(logic.pendingMoves.count, logic.config.pendingMoveCapacity)
        XCTAssertEqual(logic.pendingMoves, [.left, .right, .up, .down])
        XCTAssertEqual(logic.hop?.move, .up)
        XCTAssertEqual(logic.playerPosition.row, 0)
    }

    func testPauseKeepsQueuedMovesAndDoesNotConsumeThem() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.left))
        XCTAssertTrue(logic.requestMove(.up))
        logic.update(deltaTime: 0.05)
        let hopElapsed = logic.hop?.elapsed
        logic.pause()
        XCTAssertFalse(logic.acceptsInput)
        XCTAssertFalse(logic.requestMove(.right))
        logic.update(deltaTime: 1)
        XCTAssertEqual(logic.pendingMoves, [.left, .up])
        XCTAssertEqual(logic.hop?.elapsed, hopElapsed)
        XCTAssertEqual(logic.playerPosition.row, 0)
        logic.resume()
        XCTAssertTrue(logic.acceptsInput)
        advanceUntilIdle(logic)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 2, column: 2))
        XCTAssertEqual(logic.score, 2)
    }

    func testResetClearsPendingQueueFromPreviousRun() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.requestMove(.left))
        logic.reset()
        XCTAssertTrue(logic.pendingMoves.isEmpty)
        XCTAssertNil(logic.hop)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 0, column: 3))
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.requestMove(.up))
        XCTAssertTrue(logic.pendingMoves.isEmpty)
    }

    func testHorizontalEdgesRejectOutwardMovementWithoutWrapping() {
        let left = makeSafeLogic(position: JumpyGridPosition(row: 0, column: 0))
        XCTAssertFalse(left.requestMove(.left))
        XCTAssertEqual(left.playerPosition.column, 0)
        let right = makeSafeLogic(position: JumpyGridPosition(row: 0, column: 6))
        XCTAssertFalse(right.requestMove(.right))
        XCTAssertEqual(right.playerPosition.column, 6)
    }

    func testDownIsBlockedAtInitialAndScrolledBottomBoundary() {
        let logic = makeSafeLogic()
        XCTAssertFalse(logic.requestMove(.down))
        logic.setPlayerForTesting(JumpyGridPosition(row: 20, column: 3), score: 20, camera: 20)
        XCTAssertGreaterThan(logic.minimumRetreatRow, 0)
        logic.setPlayerForTesting(JumpyGridPosition(row: logic.minimumRetreatRow, column: 3), score: 20, camera: 20)
        XCTAssertFalse(logic.requestMove(.down))
    }

    func testScoreTracksGreatestCompletedForwardRowAndNeverDecreases() {
        let logic = makeSafeLogic()
        for _ in 0..<5 { XCTAssertTrue(logic.requestMove(.up)); finishHop(logic) }
        XCTAssertEqual(logic.score, 5)
        XCTAssertTrue(logic.requestMove(.left)); finishHop(logic)
        XCTAssertTrue(logic.requestMove(.right)); finishHop(logic)
        XCTAssertEqual(logic.score, 5)
        XCTAssertTrue(logic.requestMove(.down)); finishHop(logic)
        XCTAssertTrue(logic.requestMove(.down)); finishHop(logic)
        XCTAssertEqual(logic.score, 5)
        for expected in [5, 5, 6] {
            XCTAssertTrue(logic.requestMove(.up)); finishHop(logic)
            XCTAssertEqual(logic.score, expected)
        }
    }

    func testScoreChangesOnlyAfterLanding() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        logic.update(deltaTime: 0.10)
        XCTAssertEqual(logic.score, 0)
        finishHop(logic)
        XCTAssertEqual(logic.score, 1)
    }

    func testCameraIsMonotonicAndIgnoresSidewaysAndBackwardMovement() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 5, column: 3), score: 5)
        for _ in 0..<3 { XCTAssertTrue(logic.requestMove(.up)); finishHop(logic) }
        let high = logic.cameraProgress
        XCTAssertTrue(logic.requestMove(.left)); finishHop(logic)
        XCTAssertEqual(logic.cameraProgress, high)
        XCTAssertTrue(logic.requestMove(.down)); finishHop(logic)
        XCTAssertEqual(logic.cameraProgress, high)
    }

    func testPauseFreezesTrafficHopAndDuration() {
        let logic = makeSafeLogic()
        XCTAssertTrue(logic.requestMove(.up))
        logic.update(deltaTime: 0.05)
        let point = logic.playerWorldPoint
        let duration = logic.elapsedTime
        logic.pause()
        logic.update(deltaTime: 1)
        XCTAssertEqual(logic.playerWorldPoint, point)
        XCTAssertEqual(logic.elapsedTime, duration)
        logic.resume()
        finishHop(logic)
        XCTAssertEqual(logic.playerPosition.row, 1)
    }

    func testAcceptedJumpCountersExcludeRejectedInput() {
        let logic = makeSafeLogic()
        XCTAssertFalse(logic.requestMove(.down))
        XCTAssertTrue(logic.requestMove(.up)); finishHop(logic)
        XCTAssertTrue(logic.requestMove(.left)); finishHop(logic)
        XCTAssertTrue(logic.requestMove(.down)); finishHop(logic)
        XCTAssertEqual(logic.totalJumps, 3)
        XCTAssertEqual(logic.forwardJumps, 1)
        XCTAssertEqual(logic.sidewaysJumps, 1)
        XCTAssertEqual(logic.backwardJumps, 1)
    }

    func testScrollingCullsOldRowsButRetainsRetreatBuffer() {
        let logic = makeSafeLogic(position: JumpyGridPosition(row: 20, column: 3), score: 20)
        logic.setPlayerForTesting(JumpyGridPosition(row: 20, column: 3), score: 20, camera: 20)
        XCTAssertTrue(logic.requestMove(.up))
        finishHop(logic)
        XCTAssertNil(logic.row(at: logic.minimumRetreatRow - 3))
        XCTAssertNotNil(logic.row(at: logic.minimumRetreatRow - 2))
    }

    func testRetreatDoesNotRegenerateRetainedLaneIdentity() {
        var config = JumpyGameConfig.reference
        config.randomSeed = 42
        let logic = JumpyGameLogic(config: config)
        guard case .road(let original)? = logic.row(at: 1)?.kind else { return XCTFail("Expected road") }
        logic.setPlayerForTesting(JumpyGridPosition(row: 2, column: 3), score: 2, camera: 2)
        XCTAssertTrue(logic.requestMove(.down))
        for _ in 0..<30 where logic.hop != nil { logic.update(deltaTime: 1.0 / 60.0) }
        guard case .road(let revisited)? = logic.row(at: 1)?.kind else { return XCTFail("Expected retained road") }
        XCTAssertEqual(revisited.id, original.id)
        XCTAssertEqual(revisited.direction, original.direction)
        XCTAssertEqual(revisited.speed, original.speed)
        XCTAssertEqual(revisited.vehicleOffsets, original.vehicleOffsets)
        XCTAssertEqual(revisited.groupStartIndices, original.groupStartIndices)
        XCTAssertEqual(revisited.cycleLength, original.cycleLength)
    }

    private func makeSafeLogic(position: JumpyGridPosition = .init(row: 0, column: 3), score: Int = 0) -> JumpyGameLogic {
        var config = JumpyGameConfig.reference
        config.randomSeed = 1
        let logic = JumpyGameLogic(config: config)
        logic.replaceRowsForTesting((-5...60).map { JumpyWorldRow(worldRow: $0, kind: .safe) })
        logic.setPlayerForTesting(position, score: score, camera: CGFloat(score))
        return logic
    }

    private func finishHop(_ logic: JumpyGameLogic, file: StaticString = #filePath, line: UInt = #line) {
        advanceUntilIdle(logic)
        XCTAssertNil(logic.hop, file: file, line: line)
    }

    private func advance(_ logic: JumpyGameLogic, by duration: TimeInterval) {
        var remaining = duration
        while remaining > 1e-9 {
            let step = min(remaining, 1.0 / 60.0)
            logic.update(deltaTime: step)
            remaining -= step
        }
    }

    private func advanceUntilIdle(_ logic: JumpyGameLogic) {
        for _ in 0..<120 where logic.hop != nil || !logic.pendingMoves.isEmpty {
            logic.update(deltaTime: 1.0 / 60.0)
        }
    }

    func testDebugStartingScoreStagesPlayerAndCameraAtThatProgress() {
        var config = JumpyGameConfig.reference
        config.randomSeed = 4
        config.startingScore = 80
        let logic = JumpyGameLogic(config: config)

        XCTAssertEqual(logic.score, 80)
        XCTAssertEqual(logic.playerPosition, JumpyGridPosition(row: 80, column: 3))
        XCTAssertEqual(logic.cameraProgress, 80)
        XCTAssertNotNil(logic.row(at: 80))
        XCTAssertGreaterThanOrEqual(logic.rows.keys.max() ?? 80, 96)
    }
}
