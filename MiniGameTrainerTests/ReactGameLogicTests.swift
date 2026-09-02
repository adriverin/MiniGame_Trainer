import XCTest
@testable import MiniGameTrainer

final class ReactGameLogicTests: XCTestCase {
    private func config(_ mutate: (inout ReactGameConfig) -> Void = { _ in }) -> ReactGameConfig {
        var config = ReactGameConfig.deterministic(seed: 42)
        mutate(&config)
        return config
    }

    func testStateMachineRunsWaitingTargetFeedbackAndNextWaiting() {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 1
            $0.maximumStimulusDelay = 1
            $0.feedbackDuration = 0.1
        })
        logic.start(at: 0)
        XCTAssertEqual(logic.state, .waiting)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .targetVisible)
        let target = try! XCTUnwrap(logic.activeTargetIndex)
        XCTAssertEqual(logic.handleTap(targetIndex: target, at: 1.25), .correct(0.25))
        XCTAssertEqual(logic.state, .roundFeedback)
        logic.update(at: 1.35)
        XCTAssertEqual(logic.state, .waiting)
        logic.update(at: 2.25)
        XCTAssertEqual(logic.state, .targetVisible)
    }

    func testExactInjectedTimingProduces273Milliseconds() {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 0
            $0.maximumStimulusDelay = 0
        })
        logic.start(at: 10)
        logic.update(at: 10)
        let target = try! XCTUnwrap(logic.activeTargetIndex)
        guard case .correct(let reaction) = logic.handleTap(targetIndex: target, at: 10.273) else {
            return XCTFail("Expected a valid reaction")
        }
        XCTAssertEqual(reaction, 0.273, accuracy: 1e-12)
        XCTAssertEqual(logic.validReactionTimes[0], 0.273, accuracy: 1e-12)
    }

    func testPrematureTapRestartsRandomWaitWithoutRecordingReaction() throws {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 1
            $0.maximumStimulusDelay = 1
            $0.feedbackDuration = 0.1
        })
        logic.start(at: 0)
        XCTAssertEqual(logic.handleTap(targetIndex: 4, at: 0.5), .premature)
        XCTAssertEqual(logic.prematureTapCount, 1)
        XCTAssertTrue(logic.reactionTimes.isEmpty)
        XCTAssertEqual(try XCTUnwrap(logic.nextStimulusTime), 1.5, accuracy: 1e-12)
        logic.update(at: 1.49)
        XCTAssertNotEqual(logic.state, .targetVisible)
        logic.update(at: 1.5)
        XCTAssertEqual(logic.state, .targetVisible)
    }

    func testRepeatedPrematureTapsCannotAdvanceRound() throws {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 1
            $0.maximumStimulusDelay = 1
        })
        logic.start(at: 0)
        for index in 1...10 {
            _ = logic.handleTap(targetIndex: index % 9, at: Double(index) * 0.1)
        }
        XCTAssertEqual(logic.completedRoundCount, 0)
        XCTAssertEqual(logic.prematureTapCount, 10)
        XCTAssertEqual(try XCTUnwrap(logic.nextStimulusTime), 2, accuracy: 1e-12)
    }

    func testWrongTargetDoesNotCreateSuccessfulReaction() {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 0
            $0.maximumStimulusDelay = 0
        })
        logic.start(at: 0)
        logic.update(at: 0)
        let target = try! XCTUnwrap(logic.activeTargetIndex)
        XCTAssertEqual(logic.handleTap(targetIndex: (target + 1) % 9, at: 0.2), .wrongTarget)
        XCTAssertEqual(logic.wrongTargetTapCount, 1)
        XCTAssertTrue(logic.reactionTimes.isEmpty)
        XCTAssertNil(logic.activeTargetIndex)
    }

    func testPenaltyRuleAdvancesRoundButDoesNotCountValidReaction() {
        let logic = ReactGameLogic(config: config {
            $0.roundCount = 1
            $0.minimumStimulusDelay = 1
            $0.maximumStimulusDelay = 1
            $0.earlyTapRule = .recordPenalty
            $0.invalidTapPenalty = 1.25
        })
        logic.start(at: 0)
        XCTAssertEqual(logic.handleTap(targetIndex: nil, at: 0.2), .penaltyRecorded(1.25))
        XCTAssertEqual(logic.state, .finished)
        let summary = logic.makeSummary(at: 0.2)
        XCTAssertEqual(summary.score, 1_250)
        XCTAssertEqual(summary.validRounds, 0)
        XCTAssertEqual(summary.completedRounds, 1)
    }

    func testFiveValidRoundsFinishSession() {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 0
            $0.maximumStimulusDelay = 0
            $0.feedbackDuration = 0
        })
        logic.start(at: 0)
        for round in 0..<5 {
            logic.update(at: Double(round))
            let target = try! XCTUnwrap(logic.activeTargetIndex)
            _ = logic.handleTap(targetIndex: target, at: Double(round) + 0.2)
        }
        XCTAssertEqual(logic.state, .finished)
        XCTAssertEqual(logic.completedRoundCount, 5)
        XCTAssertEqual(logic.makeSummary(at: 5).validRounds, 5)
    }

    func testResumeRestartsInterruptedTargetWithFreshWait() throws {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 1
            $0.maximumStimulusDelay = 1
        })
        logic.start(at: 0)
        logic.update(at: 1)
        XCTAssertEqual(logic.state, .targetVisible)
        logic.pause(at: 1.1)
        XCTAssertEqual(logic.state, .paused)
        logic.resume(at: 5)
        XCTAssertEqual(logic.state, .waiting)
        XCTAssertNil(logic.stimulusPresentedTime)
        XCTAssertEqual(try XCTUnwrap(logic.nextStimulusTime), 6, accuracy: 1e-12)
        logic.update(at: 5.99)
        XCTAssertEqual(logic.state, .waiting)
    }

    func testResetRestoresInitialStateAndSeed() {
        let logic = ReactGameLogic(config: config {
            $0.minimumStimulusDelay = 0
            $0.maximumStimulusDelay = 0
        })
        logic.start(at: 0)
        logic.update(at: 0)
        let firstTarget = logic.activeTargetIndex
        _ = logic.handleTap(targetIndex: firstTarget, at: 0.3)
        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertTrue(logic.reactionTimes.isEmpty)
        logic.start(at: 10)
        logic.update(at: 10)
        XCTAssertEqual(logic.activeTargetIndex, firstTarget)
    }
}
