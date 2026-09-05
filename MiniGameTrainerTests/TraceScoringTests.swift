import XCTest
@testable import MiniGameTrainer

final class TraceScoringTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    func testSuccessfulCumulativeMilestones() {
        let logic = TraceLogicHarness.makeLogic(seed: 9)
        let expected = TraceDifficultyModel.successfulMilestones
        for (index, milestone) in expected.enumerated() {
            XCTAssertEqual(logic.score, TraceDifficultyModel.cumulativeScore(afterCompletedRounds: index))
            XCTAssertEqual(logic.segmentCount, index + 3)
            TraceLogicHarness.completeCurrentPattern(logic)
            XCTAssertEqual(logic.score, milestone, "Round \(index + 1) should end at \(milestone)")
            TraceLogicHarness.advanceToRecall(logic)
        }
        XCTAssertEqual(logic.patternsCompleted, expected.count)
        XCTAssertEqual(logic.score, 88)
    }

    func testScoreIncrementsDuringTheTraceNotOnlyAtTheEnd() {
        let pattern = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: pattern, field: TraceHexField(radius: 1))
        XCTAssertEqual(logic.accept(pattern[0]), .accepted(node: pattern[0], scoreDelta: 0, completed: false))
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.accept(pattern[1]), .accepted(node: pattern[1], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.accept(pattern[2]), .accepted(node: pattern[2], scoreDelta: 1, completed: false))
        XCTAssertEqual(logic.score, 2)
        XCTAssertEqual(logic.accept(pattern[3]), .accepted(node: pattern[3], scoreDelta: 1, completed: true))
        XCTAssertEqual(logic.score, 3)
    }

    func testWrongNodeKeepsAlreadyAwardedSegmentsAndEndsTheRun() {
        let pattern = TraceLogicHarness.radiusOneFourNodePath
        let logic = TraceLogicHarness.makeLogic(pattern: pattern, field: TraceHexField(radius: 1))
        _ = logic.accept(pattern[0])
        _ = logic.accept(pattern[1])
        XCTAssertEqual(logic.score, 1)
        let wrong = TraceLogicHarness.wrongNeighbor(after: pattern[1], expected: pattern[2], field: logic.field)
        XCTAssertEqual(logic.accept(wrong), .rejected)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.lastFailure, .wrongNode)
        XCTAssertTrue(logic.isFinished)
    }

    func testMilestoneFormulaMatchesPlayusTable() {
        let expected = [0, 3, 7, 12, 18, 25, 33, 42, 52, 63, 75, 88]
        for (completed, score) in expected.enumerated() {
            XCTAssertEqual(TraceDifficultyModel.cumulativeScore(afterCompletedRounds: completed), score)
        }
    }
}
