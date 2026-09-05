import XCTest
@testable import MiniGameTrainer

final class TraceGameLogicTests: XCTestCase {
    func testOrderedPathIsCorrectAndPermutationIsNot() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        XCTAssertEqual(logic.accept(path[0]), .accepted(node: path[0], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(path[1]), .accepted(node: path[1], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(path[2]), .accepted(node: path[2], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(path[3]), .accepted(node: path[3], scoreDelta: 1, completed: true))
        XCTAssertEqual(logic.score, 3)
        XCTAssertEqual(logic.patternsCompleted, 1)

        let wrong = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        _ = wrong.accept(path[0])
        XCTAssertEqual(wrong.accept(path[2]), .rejected)
        XCTAssertEqual(wrong.lastFailure, .wrongNode)
        XCTAssertEqual(wrong.score, 0)
        XCTAssertTrue(wrong.isFinished)
    }

    func testInvalidStartNodeIsIgnoredUntilTheHighlightedAnchor() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        XCTAssertEqual(logic.recallAnchor, path[0])
        XCTAssertEqual(logic.accept(path[3]), .ignored)
        XCTAssertNil(logic.lastFailure)
        XCTAssertFalse(logic.isFinished)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.accept(path[0]), .accepted(node: path[0], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.score, 0)
    }

    func testReversePathCanBeEnabled() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1)) {
            $0.acceptReverseSequence = true
        }
        XCTAssertEqual(logic.accept(path[3]), .accepted(node: path[3], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(path[2]), .accepted(node: path[2], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(path[1]), .accepted(node: path[1], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.accept(path[0]), .accepted(node: path[0], scoreDelta: 1, completed: true))
        XCTAssertEqual(logic.score, 3)
    }

    func testRemainingInsideTheSameNodeDoesNotAppendDuplicates() {
        let path = Array(TraceLogicHarness.radiusOneFourNodePath.prefix(2))
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        XCTAssertEqual(logic.accept(path[0]), .accepted(node: path[0], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.accept(path[0]), .duplicate)
        XCTAssertEqual(logic.playerSequence, [path[0]])
        XCTAssertEqual(logic.score, 0)
    }

    func testInputIgnoredWhileShowingPatternAndAfterResult() {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        config.segmentRevealDuration = 10
        config.patternHoldDuration = 10
        let logic = TraceGameLogic(config: config, sceneSize: TraceLogicHarness.sceneSize, seed: 1)
        logic.forcedField = TraceHexField(radius: 1)
        logic.forcedPattern = Array(TraceLogicHarness.radiusOneFourNodePath.prefix(2))
        logic.start()
        XCTAssertEqual(logic.phase, .showingPattern)
        XCTAssertEqual(logic.accept(TraceLogicHarness.radiusOneFourNodePath[0]), .ignored)
        logic.beginTouch(position: CGPoint(x: 10, y: 10))
        XCTAssertTrue(logic.playerSequence.isEmpty)
    }

    func testRecallTimeoutEndsTheSessionAndPreservesScore() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1)) {
            $0.recallBaseDuration = 0.2
            $0.recallDurationPerSegment = 0
        }
        _ = logic.accept(path[0])
        _ = logic.accept(path[1])
        XCTAssertEqual(logic.score, 1)
        let target = logic.targetSequence
        let limit = logic.recallDuration + 0.2
        var elapsed: TimeInterval = 0
        while elapsed < limit, !logic.isFinished {
            logic.update(deltaTime: 0.05)
            elapsed += 0.05
        }
        XCTAssertEqual(logic.lastFailure, .recallTimeout)
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.targetSequence, target)
        XCTAssertEqual(logic.patternsCompleted, 0)
        let ended = logic.drainEvents().filter { $0 == .sessionEnded }
        XCTAssertEqual(ended.count, 1)
        logic.update(deltaTime: 0.2)
        XCTAssertEqual(logic.drainEvents().filter { $0 == .sessionEnded }.count, 0)
    }

    func testWrongNeighborEndsSessionWithoutGeneratingANewTarget() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        _ = logic.accept(path[0])
        _ = logic.accept(path[1])
        let target = logic.targetSequence
        let wrong = TraceLogicHarness.wrongNeighbor(after: path[1], expected: path[2], field: logic.field)
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(path[1], wrong))
        XCTAssertNotEqual(wrong, path[2])
        _ = logic.drainEvents()
        XCTAssertEqual(logic.accept(wrong), .rejected)
        XCTAssertEqual(logic.lastFailure, .wrongNode)
        XCTAssertTrue(logic.isFinished)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.targetSequence, target)
        XCTAssertEqual(logic.phase, .gameOver)
        let events = logic.drainEvents()
        XCTAssertEqual(events.filter { $0 == .sessionEnded }.count, 1)
        XCTAssertFalse(events.contains { if case .patternStarted = $0 { return true }; return false })
        logic.update(deltaTime: 1)
        XCTAssertEqual(logic.targetSequence, target)
        XCTAssertEqual(logic.drainEvents().filter { $0 == .sessionEnded }.count, 0)
    }

    func testStartNodeRemainsAfterMemorizeAndAwardsZeroThenOne() {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        config.segmentRevealDuration = 0.1
        config.patternHoldDuration = 0.1
        config.evaluationDuration = 0
        config.transitionDuration = 0
        let logic = TraceGameLogic(config: config, sceneSize: TraceLogicHarness.sceneSize, seed: 3)
        logic.forcedField = TraceHexField(radius: 1)
        logic.forcedPattern = TraceLogicHarness.radiusOneFourNodePath
        logic.start()
        XCTAssertEqual(logic.phase, .showingPattern)
        XCTAssertNil(logic.recallAnchor)
        XCTAssertGreaterThan(logic.visibleReferenceCount, 0)
        var elapsed: TimeInterval = 0
        while logic.phase == .showingPattern, elapsed < 2 {
            logic.update(deltaTime: 0.05)
            elapsed += 0.05
        }
        XCTAssertEqual(logic.phase, .awaitingTrace)
        XCTAssertEqual(logic.visibleReferenceCount, 0)
        XCTAssertEqual(logic.recallAnchor, logic.targetSequence.first)
        XCTAssertEqual(logic.accept(logic.targetSequence[0]), .accepted(node: logic.targetSequence[0], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.accept(logic.targetSequence[1]), .accepted(node: logic.targetSequence[1], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.score, 1)
    }

    func testBoardProgressionFollowsPlayusRadii() {
        let difficulty = TraceDifficultyModel(config: .reference)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 0), 1)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 1), 1)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 2), 2)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 3), 2)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 4), 2)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 5), 3)
        XCTAssertEqual(difficulty.radius(forRoundIndex: 20), 3)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 0), 0)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 3), 1)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 7), 2)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 18), 4)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 25), 5)
        XCTAssertEqual(difficulty.roundIndex(afterCompletedScore: 33), 6)
    }

    func testLiveRoundsChangeBoardAndEdgeCounts() {
        let logic = TraceLogicHarness.makeLogic(seed: 17)
        XCTAssertEqual(logic.field.radius, 1)
        XCTAssertEqual(logic.field.nodeCount, 7)
        XCTAssertEqual(logic.segmentCount, 3)

        TraceLogicHarness.completeCurrentPattern(logic)
        TraceLogicHarness.advanceToRecall(logic)
        XCTAssertEqual(logic.score, 3)
        XCTAssertEqual(logic.field.radius, 1)
        XCTAssertEqual(logic.segmentCount, 4)

        TraceLogicHarness.completeCurrentPattern(logic)
        TraceLogicHarness.advanceToRecall(logic)
        XCTAssertEqual(logic.score, 7)
        XCTAssertEqual(logic.field.radius, 2)
        XCTAssertEqual(logic.field.nodeCount, 19)
        XCTAssertEqual(logic.segmentCount, 5)

        TraceLogicHarness.completeCurrentPattern(logic)
        TraceLogicHarness.advanceToRecall(logic)
        XCTAssertEqual(logic.score, 12)
        XCTAssertEqual(logic.field.radius, 2)

        TraceLogicHarness.completeCurrentPattern(logic)
        TraceLogicHarness.advanceToRecall(logic)
        XCTAssertEqual(logic.score, 18)
        XCTAssertEqual(logic.field.radius, 2)

        TraceLogicHarness.completeCurrentPattern(logic)
        TraceLogicHarness.advanceToRecall(logic)
        XCTAssertEqual(logic.score, 25)
        XCTAssertEqual(logic.field.radius, 3)
        XCTAssertEqual(logic.field.nodeCount, 37)
        XCTAssertEqual(logic.segmentCount, 8)
    }

    func testExactEdgeCountsForRepresentativeRounds() {
        let difficulty = TraceDifficultyModel(config: .reference)
        let expected = [3, 4, 5, 6, 7, 8, 9, 10, 12, 14]
        let rounds = [0, 1, 2, 3, 4, 5, 6, 7, 9, 11]
        for (round, edges) in zip(rounds, expected) {
            XCTAssertEqual(difficulty.edgeCount(forRoundIndex: round), edges)
            let field = difficulty.field(forRoundIndex: round)
            XCTAssertEqual(difficulty.nodeCount(forRoundIndex: round, field: field), edges + 1)
        }
    }

    func testBackgroundDuringRecallRestartsPatternAndRewindsScore() {
        let path = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
        _ = logic.accept(path[0])
        _ = logic.accept(path[1])
        XCTAssertEqual(logic.score, 1)
        logic.pause()
        logic.resume()
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.playerSequence.isEmpty)
        XCTAssertEqual(logic.targetSequence, path)
        XCTAssertEqual(logic.recallAnchor, path[0])
    }

    func testSixtyAndOneTwentyHertzProduceEquivalentRecallState() {
        func run(hz: Double) -> TimeInterval {
            let path = Array(TraceLogicHarness.radiusOneFourNodePath.prefix(2))
            let logic = TraceLogicHarness.makeLogic(pattern: path, field: TraceHexField(radius: 1))
            let step = 1 / hz
            for _ in 0..<Int(hz) { logic.update(deltaTime: step) }
            return logic.recallElapsed
        }
        XCTAssertEqual(run(hz: 60), run(hz: 120), accuracy: 1e-6)
    }

    func testLargeDifficultyRemainsFiniteOnRadiusThree() {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        let logic = TraceGameLogic(config: config, sceneSize: TraceLogicHarness.sceneSize, seed: 99)
        logic.skipPresentation = true
        logic.scoreOverride = 200
        logic.start()
        XCTAssertEqual(logic.field.radius, 3)
        XCTAssertEqual(logic.field.nodeCount, 37)
        XCTAssertFalse(logic.targetSequence.isEmpty)
        XCTAssertLessThanOrEqual(logic.targetSequence.count, logic.field.nodeCount)
        XCTAssertTrue(logic.targetSequence.allSatisfy(logic.field.contains))
        XCTAssertGreaterThan(logic.recallDuration, 0)
        XCTAssertFalse(logic.recallDuration.isNaN)
    }

    func testGeneratedRoundPathsHaveExactNodeCounts() {
        let logic = TraceLogicHarness.makeLogic(seed: 64)
        for round in 0..<8 {
            XCTAssertEqual(logic.roundIndex, round)
            XCTAssertEqual(logic.segmentCount, round + 3)
            XCTAssertEqual(logic.targetSequence.count, logic.segmentCount + 1)
            XCTAssertEqual(Set(logic.targetSequence).count, logic.targetSequence.count)
            for index in 1..<logic.targetSequence.count {
                XCTAssertTrue(TraceHexNeighbors.isNeighbor(logic.targetSequence[index - 1], logic.targetSequence[index]))
            }
            TraceLogicHarness.completeCurrentPattern(logic)
            TraceLogicHarness.advanceToRecall(logic)
        }
    }
}
