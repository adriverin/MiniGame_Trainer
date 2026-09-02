import XCTest
@testable import MiniGameTrainer

final class ReactPerformanceTests: XCTestCase {
    private let referenceSeconds = [273, 239, 312, 290, 326].map { Double($0) / 1_000 }

    func testReferenceAverageIsExactly288Milliseconds() {
        let summary = ReactSessionSummary(
            reactionTimes: referenceSeconds,
            validReactionTimes: referenceSeconds,
            prematureTaps: 0,
            wrongTargetTaps: 0,
            duration: 14
        )
        XCTAssertEqual(summary.average!, 0.288, accuracy: 1e-12)
        XCTAssertEqual(summary.score, 288)
    }

    func testReferenceMedianFastestSlowestSpreadAndDeviation() {
        let summary = ReactSessionSummary(
            reactionTimes: referenceSeconds,
            validReactionTimes: referenceSeconds,
            prematureTaps: 0,
            wrongTargetTaps: 0,
            duration: 14
        )
        XCTAssertEqual(summary.fastest!, 0.239, accuracy: 1e-12)
        XCTAssertEqual(summary.slowest!, 0.326, accuracy: 1e-12)
        XCTAssertEqual(summary.median!, 0.290, accuracy: 1e-12)
        XCTAssertEqual(summary.spread!, 0.087, accuracy: 1e-12)
        XCTAssertEqual(summary.standardDeviation!, 0.030495901363953813, accuracy: 1e-12)
    }

    @MainActor
    func testResultBuilderUsesMillisecondsAndLowerIsBetter() {
        let summary = ReactSessionSummary(
            reactionTimes: referenceSeconds,
            validReactionTimes: referenceSeconds,
            prematureTaps: 0,
            wrongTargetTaps: 0,
            duration: 14
        )
        let result = ReactResultBuilder.makeResult(from: summary)
        XCTAssertEqual(result.score, 288)
        XCTAssertEqual(result.scorePresentation.label, "Average")
        XCTAssertEqual(result.scorePresentation.unit, "ms")
        XCTAssertEqual(result.scorePresentation.comparison, .lowerIsBetter)
        XCTAssertEqual(result.averageReactionTime!, 0.288, accuracy: 1e-12)
    }
}
