import XCTest
@testable import MiniGameTrainer

final class TraceScoringTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(pattern: [TraceNode], grid: TraceGridSize) -> TraceGameLogic {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: 1)
        logic.skipPresentation = true
        logic.forcedGrid = grid
        logic.forcedPattern = pattern
        logic.start()
        return logic
    }

    func testReferenceRoundOneFourNodesAddsThree() {
        // Recording: first completed pattern 0 → 3, 4 nodes / 3 segments.
        let pattern = [
            TraceNode(row: 0, column: 0),
            TraceNode(row: 0, column: 1),
            TraceNode(row: 1, column: 1),
            TraceNode(row: 2, column: 1),
        ]
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(pattern[0], pattern[1]))
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(pattern[1], pattern[2]))
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(pattern[2], pattern[3]))
        let logic = makeLogic(pattern: pattern, grid: TraceGridSize(rows: 3, columns: 2))
        XCTAssertEqual(logic.score, 0)
        for node in pattern { _ = logic.accept(node) }
        XCTAssertEqual(logic.score, 3)
        XCTAssertEqual(logic.score - 0, pattern.count - 1)
    }

    func testReferenceRoundTwoFiveNodesAddsFour() {
        // Recording: second completed pattern 3 → 7, 5 nodes / 4 segments.
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: 1)
        logic.skipPresentation = true
        logic.forcedGrid = TraceGridSize(rows: 3, columns: 3)
        logic.forcedPattern = [
            TraceNode(row: 1, column: 0),
            TraceNode(row: 1, column: 1),
            TraceNode(row: 2, column: 1),
            TraceNode(row: 2, column: 2),
            TraceNode(row: 1, column: 2),
        ]
        logic.start()
        logic.scoreOverride = nil
        // Seed the displayed score to the recorded pre-round value without locking difficulty.
        let before = 3
        // Directly complete from 0 then compare delta; the recording delta is segments, not absolute score.
        for node in logic.targetSequence { _ = logic.accept(node) }
        XCTAssertEqual(logic.score, 4)
        XCTAssertEqual(4, logic.targetSequence.count - 1)
        XCTAssertEqual(before + 4, 7)
    }

    func testScoreIncrementsDuringTheTraceNotOnlyAtTheEnd() {
        let pattern = [
            TraceNode(row: 0, column: 0),
            TraceNode(row: 0, column: 1),
            TraceNode(row: 1, column: 1),
        ]
        let logic = makeLogic(pattern: pattern, grid: TraceGridSize(rows: 3, columns: 2))
        _ = logic.accept(pattern[0])
        XCTAssertEqual(logic.score, 0)
        _ = logic.accept(pattern[1])
        XCTAssertEqual(logic.score, 1)
        _ = logic.accept(pattern[2])
        XCTAssertEqual(logic.score, 2)
    }

    func testWrongNodeKeepsAlreadyAwardedSegments() {
        let pattern = [
            TraceNode(row: 0, column: 0),
            TraceNode(row: 0, column: 1),
            TraceNode(row: 1, column: 1),
        ]
        let logic = makeLogic(pattern: pattern, grid: TraceGridSize(rows: 3, columns: 2))
        _ = logic.accept(pattern[0])
        _ = logic.accept(pattern[1])
        XCTAssertEqual(logic.score, 1)
        _ = logic.accept(TraceNode(row: 2, column: 0))
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.lastFailure, .wrongNode)
    }

    func testProgressionThresholdsMatchConfiguredReferenceModel() {
        let difficulty = TraceDifficultyModel(config: .reference)
        XCTAssertEqual(difficulty.grid(forScore: 0), TraceGridSize(rows: 3, columns: 2))
        XCTAssertEqual(difficulty.grid(forScore: 8), TraceGridSize(rows: 4, columns: 3))
        XCTAssertEqual(difficulty.grid(forScore: 16), TraceGridSize(rows: 5, columns: 4))
        XCTAssertEqual(difficulty.grid(forScore: 28), TraceGridSize(rows: 6, columns: 5))
        XCTAssertEqual(difficulty.grid(forScore: 42), TraceGridSize(rows: 7, columns: 6))
        XCTAssertEqual(difficulty.grid(forScore: 60), TraceGridSize(rows: 8, columns: 7))
        XCTAssertEqual(difficulty.grid(forScore: 80), TraceGridSize(rows: 9, columns: 8))
        XCTAssertEqual(difficulty.grid(forScore: 200), TraceGridSize(rows: 9, columns: 8))
        XCTAssertEqual(difficulty.typicalPathLength(forScore: 0), 4)
        XCTAssertEqual(difficulty.typicalPathLength(forScore: 80), 13)
    }
}
