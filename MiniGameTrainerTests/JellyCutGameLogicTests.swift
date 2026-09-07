import XCTest
@testable import MiniGameTrainer

final class JellyCutGameLogicTests: XCTestCase {
    private let shape = [
        CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
        CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100),
    ]

    func testFixedRoundProgressionAndExactPerfectCuts() throws {
        let logic = makeLogic()
        XCTAssertEqual(logic.currentRound, .half)
        let half = try scored(logic.commitCut(start: point(50, -50), end: point(50, 150), at: 1))
        XCTAssertEqual(half.accuracy, 100, accuracy: 1e-10)
        logic.advanceAfterResult()
        XCTAssertEqual(logic.currentRound, .third)
        let third = try scored(logic.commitCut(start: point(100.0 / 3, -50), end: point(100.0 / 3, 150), at: 2))
        XCTAssertEqual(third.accuracy, 100, accuracy: 1e-9)
        logic.advanceAfterResult()
        XCTAssertEqual(logic.currentRound, .quarter)
        let quarter = try scored(logic.commitCut(start: point(25, -50), end: point(25, 150), at: 3))
        XCTAssertEqual(quarter.accuracy, 100, accuracy: 1e-10)
        logic.advanceAfterResult()
        XCTAssertEqual(logic.state, .summary)
        logic.finish(at: 4)
        XCTAssertEqual(logic.state, .finished)
    }

    func testTooShortMissAndTangentDoNotScoreOrAdvance() {
        let logic = makeLogic()
        XCTAssertEqual(logic.commitCut(start: point(1, 1), end: point(2, 2), at: 1), .invalid)
        XCTAssertEqual(logic.commitCut(start: point(-50, 120), end: point(150, 120), at: 2), .invalid)
        XCTAssertEqual(logic.commitCut(start: point(-50, 100), end: point(150, 100), at: 3), .invalid)
        XCTAssertTrue(logic.results.isEmpty)
        XCTAssertEqual(logic.currentRound, .half)
        XCTAssertEqual(logic.state, .active)
    }

    func testResolvingStateLocksDuplicateInput() throws {
        let logic = makeLogic()
        _ = try scored(logic.commitCut(start: point(50, -50), end: point(50, 150), at: 1))
        XCTAssertEqual(logic.commitCut(start: point(-50, 50), end: point(150, 50), at: 1.1), .invalid)
        XCTAssertEqual(logic.results.count, 1)
    }

    func testPauseFreezesDurationAndRestoresState() throws {
        let logic = makeLogic(startTime: 10)
        logic.pause(at: 12)
        XCTAssertEqual(logic.state, .paused)
        logic.resume(at: 22)
        XCTAssertEqual(logic.state, .active)
        for (index, x) in [50.0, 100.0 / 3, 25.0].enumerated() {
            _ = try scored(logic.commitCut(start: point(x, -50), end: point(x, 150), at: 23 + Double(index)))
            logic.advanceAfterResult()
        }
        logic.finish(at: 30)
        XCTAssertEqual(logic.summary(at: 30).duration, 10, accuracy: 1e-12)
    }

    func testSummaryAverageRetainsFullPrecision() {
        let rounds = zip(JellyCutRound.allCases, [99.1, 98.9, 98.9]).map { round, accuracy in
            JellyCutRoundResult(
                round: round,
                line: JellyCutLine(start: point(0, 0), end: point(1, 0))!,
                pieces: [shape, shape], fractions: [0.5, 0.5], targetPieceIndex: 0,
                achievedFraction: round.targetFraction, accuracy: accuracy
            )
        }
        let summary = JellyCutSessionSummary(rounds: rounds, duration: 5)
        XCTAssertEqual(summary.averageAccuracy, 98.9666666667, accuracy: 1e-9)
        XCTAssertEqual(summary.scoreBasisPoints, 9_897)
    }

    private func makeLogic(startTime: TimeInterval = 0) -> JellyCutGameLogic {
        JellyCutGameLogic(
            shapes: [shape, shape, shape],
            config: JellyCutConfig(minimumGestureLength: 30),
            startTime: startTime
        )
    }

    private func scored(_ outcome: JellyCutCommitOutcome) throws -> JellyCutRoundResult {
        guard case .scored(let result) = outcome else {
            XCTFail("Expected a scored cut")
            throw NSError(domain: "JellyCutTests", code: 1)
        }
        return result
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
}

@MainActor
final class JellyCutIntegrationTests: XCTestCase {
    func testRegistryAppendsJellyCutAsNineteenthGame() {
        XCTAssertEqual(GameRegistry.descriptors.count, 19)
        XCTAssertEqual(GameRegistry.descriptors.last?.id, "jellyCut")
        XCTAssertEqual(GameRegistry.descriptors.last?.name, "JELLY CUT")
        XCTAssertEqual(JellyCutGameModule.descriptor.scorePresentation, .precisionPercent)
    }

    func testResultUsesBasisPointsAndExpectedMetrics() {
        let result = JellyCutResultBuilder.makeResult(from: summary(score: 98.9666666667))
        XCTAssertEqual(result.gameID, "jellyCut")
        XCTAssertEqual(result.score, 9_897)
        XCTAssertEqual(result.scorePresentation.formatted(result.score), "98.97%")
        XCTAssertEqual(result.metrics.map(\.key), ["half", "third", "quarter", "averageFractionError", "duration"])
    }

    func testHighestPrecisionPersistsIncludingZeroAndOneHundred() {
        let suite = "JellyCutStatistics-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StatisticsStore(userDefaults: defaults)
        for score in [0, 9_897, 8_000, 10_000] {
            store.record(GameResult(gameID: "jellyCut", score: score, scorePresentation: .precisionPercent, duration: 1))
        }
        XCTAssertEqual(store.statistics(for: "jellyCut").gamesPlayed, 4)
        XCTAssertEqual(store.statistics(for: "jellyCut").bestScore, 10_000)
        defaults.removePersistentDomain(forName: suite)
    }

    func testJellyCutInheritsSharedAttemptRules() {
        let suite = "JellyCutAttempts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let entitlement = StubEntitlement(isPro: false)
        let attempts = AttemptManager(
            userDefaults: defaults,
            clock: MutableDayClock(now: Date(timeIntervalSince1970: 1_767_398_400)),
            calendar: calendar,
            entitlement: entitlement
        )
        for _ in 0..<7 { XCTAssertTrue(attempts.consumeAttempt(for: "jellyCut")) }
        XCTAssertEqual(attempts.availability(for: "jellyCut"), .exhausted)
        XCTAssertTrue(attempts.grantRewardedAttempts(3, for: "jellyCut"))
        XCTAssertEqual(attempts.availability(for: "jellyCut"), .rewarded(remaining: 3))
        entitlement.isPro = true
        XCTAssertEqual(attempts.availability(for: "jellyCut"), .proUnlimited)
        defaults.removePersistentDomain(forName: suite)
    }

    private func summary(score: Double) -> JellyCutSessionSummary {
        let results = JellyCutRound.allCases.map { round in
            JellyCutRoundResult(
                round: round,
                line: JellyCutLine(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1, y: 0))!,
                pieces: [[], []], fractions: [round.targetFraction, 1 - round.targetFraction],
                targetPieceIndex: 0, achievedFraction: round.targetFraction, accuracy: score
            )
        }
        return JellyCutSessionSummary(rounds: results, duration: 4.2)
    }
}
