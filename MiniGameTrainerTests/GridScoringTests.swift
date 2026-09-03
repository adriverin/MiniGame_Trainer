import XCTest
@testable import MiniGameTrainer

final class GridScoringTests: XCTestCase {
    private let measured: [(level: Int, before: Int, after: Int, delta: Int)] = [
        (1, 0, 4, 4),
        (2, 4, 10, 6),
        (3, 10, 16, 6),
        (4, 16, 28, 12),
        (5, 28, 41, 13),
        (6, 41, 60, 19),
        (7, 60, 77, 17),
        (8, 77, 97, 20),
        (9, 97, 120, 23),
        (10, 120, 148, 28),
    ]

    func testReferenceScoreDeltasMatchMeasuredRecording() {
        var config = GridGameConfig.reference
        config.presentationDuration = 0.05
        config.feedbackDuration = 0.05
        config.recallTimeout = 5
        let logic = GridGameLogic(config: config, seed: 3)
        var time: TimeInterval = 0
        logic.start(at: time)
        for sample in measured {
            XCTAssertEqual(logic.level, sample.level, "Expected to start level \(sample.level)")
            XCTAssertEqual(logic.score, sample.before, "Score before level \(sample.level)")
            time += logic.currentPresentationDuration + 0.001
            logic.update(at: time)
            XCTAssertEqual(logic.state, .recalling, "Level \(sample.level) should be recalling")
            XCTAssertEqual(logic.targetCells.count, sample.delta, "Target count for level \(sample.level)")
            logic.fillCorrectSelectionForDebug()
            XCTAssertEqual(logic.submit(), .submitted(correct: true), "Level \(sample.level) submit")
            XCTAssertEqual(logic.score, sample.after, "Score after level \(sample.level)")
            time += config.feedbackDuration + 0.001
            logic.update(at: time)
        }
        XCTAssertEqual(logic.score, 148)
        XCTAssertEqual(logic.level, 11)
    }

    func testScoreChangeIsDeterministicForTheSameStage() {
        var config = GridGameConfig.reference
        config.presentationDuration = 0.05
        config.feedbackDuration = 0.05
        func play() -> Int {
            let logic = GridGameLogic(config: config, seed: 8)
            logic.start(at: 0)
            logic.update(at: 0.06)
            logic.fillCorrectSelectionForDebug()
            _ = logic.submit()
            return logic.score
        }
        XCTAssertEqual(play(), play())
        XCTAssertEqual(play(), GridDifficultyModel.referenceTargetCounts[1]!)
    }

    @MainActor
    func testResultUsesIntegerHigherIsBetterPoints() {
        let summary = GridSessionSummary(score: 120, levelReached: 10, roundsCompleted: 9, duration: 40, rounds: [])
        let result = GridResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "grid")
        XCTAssertEqual(result.score, 120)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.formatted(result.score), "120")
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }
}
