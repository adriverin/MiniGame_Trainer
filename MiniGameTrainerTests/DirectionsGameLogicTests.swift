import XCTest
@testable import MiniGameTrainer

final class DirectionsGameLogicTests: XCTestCase {
    private func logic(_ mutate: (inout DirectionsGameConfig) -> Void = { _ in }) -> DirectionsGameLogic {
        var config = DirectionsGameConfig.reference
        mutate(&config)
        config.generatorSeed = 1
        let logic = DirectionsGameLogic(config: config, seed: 1)
        logic.skipPresentation = true
        return logic
    }

    func testExactSequenceIsCorrect() {
        let logic = logic()
        logic.forcedSequence = [.up, .left, .down, .right]
        logic.start(at: 0)
        XCTAssertEqual(logic.handleInput(.up, at: 1), .accepted(.up, index: 0, score: 1))
        XCTAssertEqual(logic.handleInput(.left, at: 1.1), .accepted(.left, index: 1, score: 2))
        XCTAssertEqual(logic.handleInput(.down, at: 1.2), .accepted(.down, index: 2, score: 3))
        XCTAssertEqual(logic.handleInput(.right, at: 1.3), .completedRound(score: 4, level: 1))
        XCTAssertEqual(logic.state, .roundSuccess)
        XCTAssertEqual(logic.score, 4)
    }

    func testWrongOrderFails() {
        let logic = logic()
        logic.forcedSequence = [.up, .down, .left, .right]
        logic.start(at: 0)
        _ = logic.handleInput(.up, at: 1)
        let outcome = logic.handleInput(.left, at: 1.1)
        XCTAssertEqual(outcome, .failed(expected: .down, actual: .left, index: 1))
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.score, 1)
    }

    func testCorrectPrefixKeepsRoundActive() {
        let logic = logic()
        logic.forcedSequence = [.up, .left, .down]
        logic.start(at: 0)
        XCTAssertEqual(logic.handleInput(.up, at: 1), .accepted(.up, index: 0, score: 1))
        XCTAssertEqual(logic.state, .recalling)
        XCTAssertEqual(logic.playerInput, [.up])
        XCTAssertEqual(logic.handleInput(.left, at: 1.1), .accepted(.left, index: 1, score: 2))
        XCTAssertEqual(logic.handleInput(.down, at: 1.2), .completedRound(score: 3, level: 1))
        XCTAssertEqual(logic.state, .roundSuccess)
    }

    func testWrongPrefixFailsImmediately() {
        let logic = logic()
        logic.forcedSequence = [.up, .left, .down]
        logic.start(at: 0)
        _ = logic.handleInput(.up, at: 1)
        XCTAssertEqual(logic.handleInput(.right, at: 1.05), .failed(expected: .left, actual: .right, index: 1))
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.handleInput(.down, at: 1.1), .ignored)
    }

    func testDuplicateDirectionsAreAcceptedInOrder() {
        let logic = logic()
        logic.forcedSequence = [.up, .up, .left]
        logic.start(at: 0)
        XCTAssertEqual(logic.handleInput(.up, at: 1), .accepted(.up, index: 0, score: 1))
        XCTAssertEqual(logic.handleInput(.up, at: 1.1), .accepted(.up, index: 1, score: 2))
        XCTAssertEqual(logic.handleInput(.left, at: 1.2), .completedRound(score: 3, level: 1))
    }

    func testInputsIgnoredWhilePresentingAndTransitioning() {
        var config = DirectionsGameConfig.reference
        config.generatorSeed = 7
        config.arrowOnDuration = 0.6
        config.interArrowGap = 0.266
        config.transitionToRecallDuration = 0.35
        let logic = DirectionsGameLogic(config: config, seed: 7)
        logic.forcedSequence = [.up, .left]
        logic.start(at: 0)
        XCTAssertEqual(logic.state, .presenting)
        XCTAssertEqual(logic.handleInput(.up, at: 0.1), .ignored)
        logic.update(at: 0.6)
        XCTAssertFalse(logic.isArrowVisible)
        XCTAssertEqual(logic.handleInput(.up, at: 0.7), .ignored)
        logic.update(at: config.presentationDuration(forSequenceLength: 2) - 0.01)
        XCTAssertNotEqual(logic.state, .recalling)
        XCTAssertEqual(logic.handleInput(.up, at: config.presentationDuration(forSequenceLength: 2) - 0.01), .ignored)
        logic.update(at: config.presentationDuration(forSequenceLength: 2))
        XCTAssertEqual(logic.state, .recalling)
        XCTAssertEqual(logic.handleInput(.up, at: 2), .accepted(.up, index: 0, score: 1))
    }

    func testInputsIgnoredAfterGameOver() {
        let logic = logic()
        logic.forcedSequence = [.up]
        logic.start(at: 0)
        XCTAssertEqual(logic.handleInput(.down, at: 1), .failed(expected: .up, actual: .down, index: 0))
        XCTAssertEqual(logic.handleInput(.up, at: 1.1), .ignored)
        XCTAssertEqual(logic.score, 0)
    }

    func testMultiTouchGateAllowsOnePressAtATime() {
        let logic = logic()
        logic.forcedSequence = [.up, .left]
        logic.start(at: 0)
        XCTAssertTrue(logic.beginPress())
        XCTAssertFalse(logic.beginPress())
        XCTAssertEqual(logic.handleInput(.up, at: 1), .accepted(.up, index: 0, score: 1))
        logic.endPress()
        XCTAssertTrue(logic.beginPress())
        XCTAssertEqual(logic.handleInput(.left, at: 1.1), .completedRound(score: 2, level: 1))
    }

    func testPauseDuringRecallRestartsTheSameRound() {
        var config = DirectionsGameConfig.reference
        config.generatorSeed = 1
        let logic = DirectionsGameLogic(config: config, seed: 1)
        logic.forcedSequence = [.up, .left, .down]
        logic.start(at: 0)
        logic.update(at: logic.presentationEndTime(from: 0))
        XCTAssertEqual(logic.state, .recalling)
        _ = logic.handleInput(.up, at: 4)
        XCTAssertEqual(logic.score, 1)
        logic.pause(at: 4.2)
        XCTAssertEqual(logic.state, .paused)
        logic.resume(at: 8)
        XCTAssertEqual(logic.state, .presenting)
        XCTAssertEqual(logic.playerInput, [])
        XCTAssertEqual(logic.target, [.up, .left, .down])
        XCTAssertEqual(logic.score, 0)
        logic.update(at: logic.presentationEndTime(from: 8))
        XCTAssertEqual(logic.state, .recalling)
        XCTAssertEqual(logic.handleInput(.up, at: 12), .accepted(.up, index: 0, score: 1))
    }

    func testLevelIncrementsAfterSuccessHold() {
        var config = DirectionsGameConfig.reference
        config.roundSuccessHoldDuration = 0.72
        config.generatorSeed = 1
        let logic = DirectionsGameLogic(config: config, seed: 1)
        logic.skipPresentation = true
        logic.forcedSequence = [.up]
        logic.start(at: 0)
        XCTAssertEqual(logic.handleInput(.up, at: 1), .completedRound(score: 1, level: 1))
        logic.forcedSequence = nil
        logic.update(at: 1 + logic.config.roundSuccessHoldDuration)
        XCTAssertEqual(logic.level, 2)
        XCTAssertEqual(logic.sequenceLength, 4)
    }

    func testLongRunToLevel50StaysValid() {
        var config = DirectionsGameConfig.reference
        config.roundSuccessHoldDuration = 0
        config.generatorSeed = 42
        let logic = DirectionsGameLogic(config: config, seed: 42)
        logic.skipPresentation = true
        logic.start(at: 0)
        var time: TimeInterval = 0
        while logic.level < 50, !logic.isFinished, time < 5_000 {
            XCTAssertEqual(logic.target.count, logic.config.sequenceLength(forLevel: logic.level))
            XCTAssertFalse(logic.target.contains { _ in false })
            XCTAssertTrue(logic.target.allSatisfy { Direction.allCases.contains($0) })
            for direction in logic.target {
                time += 0.01
                let outcome = logic.handleInput(direction, at: time)
                switch outcome {
                case .accepted, .completedRound: break
                default: return XCTFail("Unexpected \(outcome) at level \(logic.level)")
                }
            }
            time += 0.01
            logic.update(at: time)
        }
        XCTAssertEqual(logic.level, 50)
        XCTAssertGreaterThan(logic.score, 0)
        XCTAssertEqual(logic.target.count, config.sequenceLengthCap)
        XCTAssertFalse(logic.isFinished)
    }
}
