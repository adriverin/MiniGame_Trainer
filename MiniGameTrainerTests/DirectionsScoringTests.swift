import XCTest
@testable import MiniGameTrainer

final class DirectionsScoringTests: XCTestCase {
    private func play(_ logic: DirectionsGameLogic, sequence: [Direction], at time: TimeInterval) {
        for (offset, direction) in sequence.enumerated() {
            _ = logic.handleInput(direction, at: time + TimeInterval(offset) * 0.05)
        }
    }

    func testScoreIncreasesPerCorrectInput() {
        let logic = DirectionsGameLogic(config: .reference, seed: 1)
        logic.skipPresentation = true
        logic.forcedSequence = [.up, .right, .down]
        logic.start(at: 0)
        XCTAssertEqual(logic.score, 0)
        _ = logic.handleInput(.up, at: 1)
        XCTAssertEqual(logic.score, 1)
        _ = logic.handleInput(.right, at: 1.1)
        XCTAssertEqual(logic.score, 2)
        _ = logic.handleInput(.down, at: 1.2)
        XCTAssertEqual(logic.score, 3)
    }

    func testReferenceRoundScoreTransitions() {
        var config = DirectionsGameConfig.reference
        config.roundSuccessHoldDuration = 0
        let logic = DirectionsGameLogic(config: config, seed: 5)
        logic.skipPresentation = true
        logic.start(at: 0)
        var time: TimeInterval = 0
        let expectedAfterLevel = [3, 7, 12, 18, 25, 33, 42, 52, 63, 75, 88]
        for (index, expected) in expectedAfterLevel.enumerated() {
            XCTAssertEqual(logic.sequenceLength, index + 3, "Level \(index + 1)")
            let before = logic.score
            play(logic, sequence: logic.target, at: time)
            time += 1
            logic.update(at: time)
            XCTAssertEqual(logic.score, expected, "After level \(index + 1)")
            XCTAssertEqual(logic.score - before, index + 3)
        }
        XCTAssertEqual(logic.level, 12)
        XCTAssertEqual(logic.score, 88)
    }

    func testWrongInputDoesNotAddPoints() {
        let logic = DirectionsGameLogic(config: .reference, seed: 1)
        logic.skipPresentation = true
        logic.forcedSequence = [.left, .up]
        logic.start(at: 0)
        _ = logic.handleInput(.right, at: 1)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .gameOver)
    }

    @MainActor
    func testResultIsHigherIsBetterIntegerScore() {
        let summary = DirectionsSessionSummary(
            score: 88,
            levelReached: 12,
            roundsCompleted: 11,
            correctInputs: 88,
            duration: 170,
            lastTarget: [.down]
        )
        let result = DirectionsResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.gameID, "directions")
        XCTAssertEqual(result.score, 88)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertEqual(result.scorePresentation.comparison, .higherIsBetter)
    }
}
