import XCTest
@testable import MiniGameTrainer

final class GridGameLogicTests: XCTestCase {
    private func makeLogic(
        seed: UInt64 = 1,
        _ mutate: (inout GridGameConfig) -> Void = { _ in }
    ) -> GridGameLogic {
        var config = GridGameConfig.reference
        mutate(&config)
        let logic = GridGameLogic(config: config, seed: seed)
        return logic
    }

    private func enterRecall(_ logic: GridGameLogic, from start: TimeInterval = 0) -> TimeInterval {
        logic.start(at: start)
        let presentUntil = start + logic.currentPresentationDuration + 0.001
        logic.update(at: presentUntil)
        XCTAssertEqual(logic.state, .recalling)
        return presentUntil
    }

    func testExactRecallIsCorrectRegardlessOfTapOrder() {
        let logic = makeLogic()
        logic.applyDebugOverrides(
            level: 1, rows: 3, columns: 3, targetCount: 3,
            presentationDuration: 0.5, recallTimeout: 10,
            forcedPattern: GridDifficultyModel.qualityAssurancePattern
        )
        _ = enterRecall(logic)
        let shuffled = Array(GridDifficultyModel.qualityAssurancePattern).reversed()
        for cell in shuffled { _ = logic.tapCell(cell) }
        XCTAssertEqual(logic.submit(), .submitted(correct: true))
        XCTAssertEqual(logic.score, 3)
    }

    func testMissingCellIsIncorrect() {
        let logic = makeLogic()
        logic.applyDebugOverrides(
            level: 1, rows: 3, columns: 3, targetCount: 3,
            presentationDuration: 0.2, recallTimeout: 10,
            forcedPattern: GridDifficultyModel.qualityAssurancePattern
        )
        _ = enterRecall(logic)
        _ = logic.tapCell(GridCell(row: 0, column: 0))
        _ = logic.tapCell(GridCell(row: 1, column: 1))
        XCTAssertEqual(logic.submit(), .submitted(correct: false))
        XCTAssertEqual(logic.score, 0)
    }

    func testExtraCellIsIncorrect() {
        let logic = makeLogic()
        logic.applyDebugOverrides(
            level: 1, rows: 3, columns: 3, targetCount: 2,
            presentationDuration: 0.2, recallTimeout: 10,
            forcedPattern: [GridCell(row: 0, column: 0), GridCell(row: 1, column: 1)]
        )
        _ = enterRecall(logic)
        _ = logic.tapCell(GridCell(row: 0, column: 0))
        _ = logic.tapCell(GridCell(row: 1, column: 1))
        _ = logic.tapCell(GridCell(row: 2, column: 2))
        XCTAssertEqual(logic.submit(), .submitted(correct: false))
    }

    func testToggleSelectsThenDeselects() {
        let logic = makeLogic()
        _ = enterRecall(logic)
        let cell = GridCell(row: 0, column: 0)
        XCTAssertEqual(logic.tapCell(cell), .toggled(cell, selected: true))
        XCTAssertTrue(logic.selectedCells.contains(cell))
        XCTAssertEqual(logic.tapCell(cell), .toggled(cell, selected: false))
        XCTAssertFalse(logic.selectedCells.contains(cell))
    }

    func testTapsIgnoredDuringPresentationAndAfterSubmit() {
        let logic = makeLogic()
        logic.start(at: 0)
        XCTAssertEqual(logic.state, .presentingPattern)
        XCTAssertEqual(logic.tapCell(GridCell(row: 0, column: 0)), .ignored)
        XCTAssertEqual(logic.submit(), .ignored)
        logic.update(at: logic.currentPresentationDuration)
        XCTAssertEqual(logic.state, .recalling)
        logic.fillCorrectSelectionForDebug()
        XCTAssertEqual(logic.submit(), .submitted(correct: true))
        XCTAssertEqual(logic.tapCell(GridCell(row: 0, column: 1)), .ignored)
        XCTAssertEqual(logic.submit(), .ignored)
    }

    func testCorrectSubmissionAdvancesExactlyOneLevelAndGrid() {
        let logic = makeLogic()
        _ = enterRecall(logic)
        XCTAssertEqual(logic.level, 1)
        XCTAssertEqual(logic.stage.rows, 3)
        logic.fillCorrectSelectionForDebug()
        _ = logic.submit()
        logic.update(at: logic.currentPresentationDuration + logic.config.feedbackDuration + 0.01)
        XCTAssertEqual(logic.level, 2)
        XCTAssertEqual(logic.stage.rows, 3)
        XCTAssertEqual(logic.state, .presentingPattern)
        XCTAssertTrue(logic.selectedCells.isEmpty)
    }

    func testIncorrectSubmitEndsRunAfterFeedback() {
        let logic = makeLogic()
        let recallAt = enterRecall(logic)
        _ = logic.tapCell(GridCell(row: 0, column: 0))
        _ = logic.submit()
        logic.update(at: recallAt + logic.config.feedbackDuration + 0.01)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.score, 0)
    }

    func testTimeoutEndsRunAtExactBoundary() {
        var config = GridGameConfig.reference
        config.presentationDuration = 0.5
        config.recallTimeout = 2.0
        config.feedbackDuration = 0.1
        let logic = GridGameLogic(config: config, seed: 7)
        logic.start(at: 0)
        logic.update(at: 0.5)
        XCTAssertEqual(logic.state, .recalling)
        logic.update(at: 2.499)
        XCTAssertEqual(logic.state, .recalling)
        logic.update(at: 2.5)
        XCTAssertTrue(logic.state == .timedOut || logic.state == .feedback)
        logic.update(at: 2.61)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.rounds.last?.outcome, .timedOut)
    }

    func testBackgroundResumeRestartsCurrentRoundWithoutKeepingSelection() {
        let logic = makeLogic()
        logic.applyDebugOverrides(
            level: 1, rows: 3, columns: 3, targetCount: 3,
            presentationDuration: 0.4, recallTimeout: 8,
            forcedPattern: nil
        )
        let recallAt = enterRecall(logic)
        _ = logic.tapCell(GridCell(row: 0, column: 0))
        let firstTarget = logic.targetCells
        logic.pause(at: recallAt + 0.2)
        logic.resume(at: recallAt + 1.0)
        XCTAssertEqual(logic.state, .presentingPattern)
        XCTAssertTrue(logic.selectedCells.isEmpty)
        XCTAssertEqual(logic.level, 1)
        XCTAssertEqual(logic.score, 0)
        XCTAssertNotEqual(logic.targetCells, firstTarget)
    }

    func testReferenceStagesThroughLevelTen() {
        for level in 1...10 {
            let stage = GridDifficultyModel.stage(forLevel: level, config: .reference)
            XCTAssertEqual(stage.rows, GridDifficultyModel.gridSize(forLevel: level).rows)
            XCTAssertEqual(stage.columns, GridDifficultyModel.gridSize(forLevel: level).columns)
            XCTAssertEqual(stage.targetCount, GridDifficultyModel.referenceTargetCounts[level])
            XCTAssertLessThan(stage.targetCount, stage.totalCells)
        }
        XCTAssertEqual(GridDifficultyModel.gridSize(forLevel: 1).rows, 3)
        XCTAssertEqual(GridDifficultyModel.gridSize(forLevel: 5).rows, 5)
        XCTAssertEqual(GridDifficultyModel.gridSize(forLevel: 8).rows, 6)
        XCTAssertEqual(GridDifficultyModel.gridSize(forLevel: 10).rows, 7)
    }
}
