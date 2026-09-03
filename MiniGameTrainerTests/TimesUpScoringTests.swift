import XCTest
@testable import MiniGameTrainer

final class TimesUpScoringTests: XCTestCase {
    func testAverageUsesRawErrorsNotRoundedDisplayStrings() {
        let results = [
            result(signed: 0.008),
            result(signed: -0.025),
            result(signed: -0.155),
        ]
        let average = TimesUpScoring.averageAbsoluteError(results)
        XCTAssertEqual(average, 0.06266666666666666, accuracy: 1e-12)
        XCTAssertEqual(TimesUpScoring.scoreMilliseconds(averageAbsoluteError: average), 63)
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formatted(63), "0.06 s")
        XCTAssertEqual(TimesUpFormatter.seconds(0.008, signed: false), "0.01s")
        XCTAssertEqual(TimesUpFormatter.seconds(-0.025, signed: false), "0.03s")
        XCTAssertEqual(TimesUpFormatter.seconds(-0.16, signed: false), "0.16s")
    }

    func testDisplayedReferenceTripleWouldRoundToSevenHundredthsIfAveragedNaively() {
        let displayed = [0.01, 0.03, 0.16]
        let naive = displayed.reduce(0, +) / Double(displayed.count)
        XCTAssertEqual(naive, 0.06666666666666667, accuracy: 1e-12)
        XCTAssertEqual(String(format: "%.2f", naive), "0.07")
        XCTAssertEqual(TimesUpScoring.scoreMilliseconds(averageAbsoluteError: naive), 67)
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formatted(67), "0.07 s")
    }

    func testLateFormatterUsesPlusPrefixAndEarlyDoesNot() {
        XCTAssertEqual(TimesUpFormatter.seconds(0.01, signed: true), "+0.01s")
        XCTAssertEqual(TimesUpFormatter.seconds(-0.03, signed: true), "0.03s")
        XCTAssertEqual(TimesUpFormatter.directionCopy(.late), "Too late!")
        XCTAssertEqual(TimesUpFormatter.directionCopy(.early), "Too early!")
        XCTAssertEqual(TimesUpFormatter.directionCopy(.exact), "Exact!")
    }

    func testBiasUsesMeanSignedError() {
        let results = [result(signed: 0.01), result(signed: -0.03), result(signed: -0.16)]
        XCTAssertEqual(TimesUpScoring.meanSignedError(results), -0.06, accuracy: 1e-12)
        XCTAssertEqual(TimesUpFormatter.bias(-0.06), "0.06 s early")
        XCTAssertEqual(TimesUpFormatter.bias(0.04), "0.04 s late")
    }

    func testZeroIsAValidScore() {
        XCTAssertEqual(TimesUpScoring.scoreMilliseconds(averageAbsoluteError: 0), 0)
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.formatted(0), "0.00 s")
        XCTAssertEqual(ScorePresentation.timingErrorSeconds.comparison, .lowerIsBetter)
    }

    func testGeometryUsesConfiguredRatios() {
        let geometry = TimesUpGeometry(sceneSize: CGSize(width: 390, height: 844), config: .reference)
        XCTAssertEqual(geometry.barFrame.width, 101.4, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.height, 337.6, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.midX, 195, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.midY, 844 * 0.42, accuracy: 0.001)
        XCTAssertEqual(geometry.cornerRadius, geometry.barFrame.width / 2, accuracy: 0.001)
    }

    @MainActor
    func testResultBuilderPersistsMillisecondsAndPerLevelMetrics() {
        let summary = TimesUpSessionSummary(
            results: [result(signed: 0.01), result(signed: -0.03, level: 2), result(signed: -0.16, level: 3)],
            duration: 32
        )
        let gameResult = TimesUpResultBuilder.makeResult(from: summary)
        XCTAssertEqual(gameResult.gameID, "timesUp")
        XCTAssertEqual(gameResult.score, 67)
        XCTAssertEqual(gameResult.scorePresentation, .timingErrorSeconds)
        XCTAssertEqual(gameResult.scorePresentation.formatted(gameResult.score), "0.07 s")
        XCTAssertEqual(gameResult.metrics.contains(where: { $0.key == "bias" }), true)
        XCTAssertEqual(gameResult.metrics.contains(where: { $0.key == "level-3" }), true)
    }

    private func result(signed: TimeInterval, level: Int = 1) -> TimesUpLevelResult {
        TimesUpLevelResult(
            levelIndex: level,
            targetDuration: 10,
            visibleDuration: 5,
            actualElapsed: 10 + signed,
            signedError: signed,
            absoluteError: abs(signed),
            direction: TimesUpScoring.direction(signedError: signed),
            tapTimestamp: 10 + signed
        )
    }
}
