import XCTest
@testable import MiniGameTrainer

final class TraceGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(
        pattern: [TraceNode]? = nil,
        grid: TraceGridSize = TraceGridSize(rows: 3, columns: 3),
        mutate: (inout TraceGameConfig) -> Void = { _ in }
    ) -> TraceGameLogic {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        config.segmentRevealDuration = 0
        config.patternHoldDuration = 0
        config.evaluationDuration = 0
        config.transitionDuration = 0.01
        mutate(&config)
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: 42)
        logic.skipPresentation = true
        logic.forcedGrid = grid
        logic.forcedPattern = pattern
        logic.forcedTargetCount = pattern?.count
        logic.start()
        XCTAssertEqual(logic.phase, .awaitingTrace)
        return logic
    }

    func testOrderedPathIsCorrectAndPermutationIsNot() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let c = TraceNode(row: 2, column: 1)
        let d = TraceNode(row: 2, column: 2)
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(a, b))
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(b, c))
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(c, d))
        let logic = makeLogic(pattern: [a, b, c, d], grid: TraceGridSize(rows: 3, columns: 3))
        XCTAssertEqual(logic.accept(a), .accepted(node: a, scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(b), .accepted(node: b, scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(c), .accepted(node: c, scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(d), .accepted(node: d, scoreDelta: 1, completed: true))
        XCTAssertEqual(logic.score, 3)
        XCTAssertEqual(logic.patternsCompleted, 1)

        let wrong = makeLogic(pattern: [a, b, c, d], grid: TraceGridSize(rows: 3, columns: 3))
        _ = wrong.accept(a)
        XCTAssertEqual(wrong.accept(c), .rejected)
        XCTAssertEqual(wrong.lastFailure, .wrongNode)
        XCTAssertEqual(wrong.score, 0)
    }

    func testReversePathIsRejectedByDefault() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let c = TraceNode(row: 2, column: 1)
        let d = TraceNode(row: 2, column: 2)
        let logic = makeLogic(pattern: [a, b, c, d], grid: TraceGridSize(rows: 3, columns: 3))
        XCTAssertEqual(logic.accept(d), .rejected)
        XCTAssertEqual(logic.lastFailure, .wrongNode)
    }

    func testReversePathCanBeEnabled() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let c = TraceNode(row: 2, column: 1)
        let d = TraceNode(row: 2, column: 2)
        let logic = makeLogic(pattern: [a, b, c, d], grid: TraceGridSize(rows: 3, columns: 3)) { $0.acceptReverseSequence = true }
        XCTAssertEqual(logic.accept(d), .accepted(node: d, scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(c), .accepted(node: c, scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(b), .accepted(node: b, scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(a), .accepted(node: a, scoreDelta: 1, completed: true))
        XCTAssertEqual(logic.score, 3)
    }

    func testRemainingInsideTheSameNodeDoesNotAppendDuplicates() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let logic = makeLogic(pattern: [a, b], grid: TraceGridSize(rows: 3, columns: 3))
        XCTAssertEqual(logic.accept(a), .accepted(node: a, scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(a), .duplicate)
        XCTAssertEqual(logic.playerSequence, [a])
        XCTAssertEqual(logic.score, 0)
    }

    func testInputIgnoredWhileShowingPatternAndAfterResult() {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        config.segmentRevealDuration = 10
        config.patternHoldDuration = 10
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: 1)
        logic.forcedGrid = TraceGridSize(rows: 3, columns: 3)
        logic.forcedPattern = [TraceNode(row: 0, column: 0), TraceNode(row: 0, column: 1)]
        logic.start()
        XCTAssertEqual(logic.phase, .showingPattern)
        XCTAssertEqual(logic.accept(TraceNode(row: 0, column: 0)), .ignored)
        logic.beginTouch(position: CGPoint(x: 10, y: 10))
        XCTAssertTrue(logic.playerSequence.isEmpty)
    }

    func testRecallTimeoutFailsPatternWithoutEndingSessionByDefault() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let logic = makeLogic(pattern: [a, b], grid: TraceGridSize(rows: 3, columns: 3)) {
            $0.recallBaseDuration = 0.2
            $0.recallDurationPerSegment = 0
            $0.transitionDuration = 10
            $0.evaluationDuration = 10
        }
        XCTAssertEqual(logic.phase, .awaitingTrace)
        let limit = logic.recallDuration + 0.15
        var elapsed: TimeInterval = 0
        while elapsed < limit, logic.lastFailure == nil {
            logic.update(deltaTime: 0.05)
            elapsed += 0.05
        }
        XCTAssertEqual(logic.lastFailure, .recallTimeout)
        XCTAssertFalse(logic.isFinished)
    }

    func testBackgroundDuringRecallRestartsPatternAndRewindsScore() {
        let a = TraceNode(row: 1, column: 0)
        let b = TraceNode(row: 1, column: 1)
        let c = TraceNode(row: 2, column: 1)
        let logic = makeLogic(pattern: [a, b, c], grid: TraceGridSize(rows: 3, columns: 3))
        _ = logic.accept(a)
        _ = logic.accept(b)
        XCTAssertEqual(logic.score, 1)
        logic.pause()
        logic.resume()
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.playerSequence.isEmpty)
        XCTAssertEqual(logic.targetSequence, [a, b, c])
    }

    func testSixtyAndOneTwentyHertzProduceEquivalentRecallState() {
        func run(hz: Double) -> TimeInterval {
            let a = TraceNode(row: 1, column: 0)
            let b = TraceNode(row: 1, column: 1)
            let logic = makeLogic(pattern: [a, b], grid: TraceGridSize(rows: 3, columns: 3))
            let step = 1 / hz
            for _ in 0..<Int(hz) { logic.update(deltaTime: step) }
            return logic.recallElapsed
        }
        XCTAssertEqual(run(hz: 60), run(hz: 120), accuracy: 1e-6)
    }

    func testLargeDifficultyRemainsFinite() {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: 99)
        logic.skipPresentation = true
        logic.scoreOverride = 200
        logic.start()
        XCTAssertGreaterThan(logic.grid.rows, 0)
        XCTAssertGreaterThan(logic.grid.columns, 0)
        XCTAssertFalse(logic.targetSequence.isEmpty)
        XCTAssertLessThanOrEqual(logic.targetSequence.count, logic.grid.nodeCount)
        XCTAssertTrue(logic.targetSequence.allSatisfy(logic.grid.contains))
        XCTAssertGreaterThan(logic.recallDuration, 0)
        XCTAssertFalse(logic.recallDuration.isNaN)
    }
}
