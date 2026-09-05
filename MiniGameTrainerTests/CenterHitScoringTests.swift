import XCTest
@testable import MiniGameTrainer

final class CenterHitScoringTests: XCTestCase {
    func testExactCenterScoresOneHundredPercent() {
        XCTAssertEqual(CenterHitScoring.precision(indicatorX: 50, centerX: 50, halfWidth: 50), 100)
    }

    func testSymmetricErrorsReceiveEqualPrecision() {
        let left = CenterHitScoring.precision(indicatorX: 42, centerX: 50, halfWidth: 50)
        let right = CenterHitScoring.precision(indicatorX: 58, centerX: 50, halfWidth: 50)
        XCTAssertEqual(left, right, accuracy: 1e-12)
        XCTAssertEqual(left, 84, accuracy: 1e-12)
    }

    func testLargerErrorNeverScoresHigher() {
        let scores = stride(from: 0.0, through: 50, by: 2.5).map {
            CenterHitScoring.precision(indicatorX: 50 + $0, centerX: 50, halfWidth: 50)
        }
        for pair in zip(scores, scores.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.0, pair.1)
        }
    }

    func testPrecisionClampsToZeroAndOneHundred() {
        XCTAssertEqual(CenterHitScoring.precision(indicatorX: -500, centerX: 50, halfWidth: 50), 0)
        XCTAssertEqual(CenterHitScoring.precision(indicatorX: 50, centerX: 50, halfWidth: 50, coefficient: 4), 100)
        XCTAssertEqual(CenterHitScoring.precision(indicatorX: 100, centerX: 50, halfWidth: 50, coefficient: 4), 0)
    }

    func testReferenceVisibleScoresMapToMeasuredNearCenterErrors() {
        let halfBarWidth = 416.0
        let displayedScores = [97.82, 97.99, 98.31, 98.67]
        let impliedErrors = displayedScores.map { halfBarWidth * (1 - $0 / 100) }
        XCTAssertEqual(impliedErrors[0], 9.0688, accuracy: 0.0001)
        XCTAssertEqual(impliedErrors[1], 8.3616, accuracy: 0.0001)
        XCTAssertEqual(impliedErrors[2], 7.0304, accuracy: 0.0001)
        XCTAssertEqual(impliedErrors[3], 5.5328, accuracy: 0.0001)
        for (score, error) in zip(displayedScores, impliedErrors) {
            XCTAssertEqual(
                CenterHitScoring.precision(indicatorX: 589.5 - error, centerX: 589.5, halfWidth: halfBarWidth),
                score,
                accuracy: 0.0001
            )
        }
    }

    func testReferenceFinalMeanWithDocumentedInferredFifthValue() {
        // The recording displays only the first four individual values. 96.66 is the approximate
        // fifth value implied by the rounded 97.89 final mean, not a claimed direct observation.
        let values = [97.82, 97.99, 98.31, 98.67, 96.66]
        XCTAssertEqual(values.reduce(0, +) / Double(values.count), 97.89, accuracy: 0.0001)
    }

    func testPrecisionScorePresentationUsesBasisPointsWithoutChangingExistingFormats() {
        XCTAssertEqual(ScorePresentation.precisionPercent.formatted(9_789), "97.89%")
        XCTAssertEqual(ScorePresentation.precisionPercent.formattedAverage(9_788.5), "97.89%")
        XCTAssertEqual(ScorePresentation.points.formatted(42), "42")
        XCTAssertEqual(ScorePresentation.points.formattedAverage(42.5), "42.5")
        XCTAssertEqual(ScorePresentation.reactionMilliseconds.formatted(288), "288 ms")
    }

    @MainActor
    func testGameLibraryBestScoreUsesDescriptorFormatter() {
        var centerStats = GameStatistics(gameID: "centerHit")
        centerStats.gamesPlayed = 1
        centerStats.bestScore = 8_017
        let centerCard = GameCardView(
            descriptor: CenterHitGameModule.descriptor,
            statistics: centerStats,
            onPlay: {}
        )
        XCTAssertEqual(centerCard.formattedBestScore, "80.17%")

        centerStats.bestScore = 9_789
        let secondCenterCard = GameCardView(
            descriptor: CenterHitGameModule.descriptor,
            statistics: centerStats,
            onPlay: {}
        )
        XCTAssertEqual(secondCenterCard.formattedBestScore, "97.89%")

        var pointsStats = GameStatistics(gameID: "piano")
        pointsStats.bestScore = 42
        XCTAssertEqual(
            GameCardView(descriptor: PianoGameModule.descriptor, statistics: pointsStats, onPlay: {}).formattedBestScore,
            "42"
        )

        var reactStats = GameStatistics(gameID: "react")
        reactStats.bestScore = 288
        XCTAssertEqual(
            GameCardView(descriptor: ReactGameModule.descriptor, statistics: reactStats, onPlay: {}).formattedBestScore,
            "288 ms"
        )
    }

    @MainActor
    func testLibraryDistinguishesUnplayedFromEarnedZeroScore() {
        var stats = GameStatistics(gameID: "centerHit")
        XCTAssertEqual(
            GameCardView(descriptor: CenterHitGameModule.descriptor, statistics: stats, onPlay: {}).bestScoreLabel,
            "No score yet"
        )
        stats.gamesPlayed = 1
        XCTAssertEqual(
            GameCardView(descriptor: CenterHitGameModule.descriptor, statistics: stats, onPlay: {}).bestScoreLabel,
            "0.00%"
        )
    }

    func testLegacyScorePresentationJSONDecodesWithOriginalDefaults() throws {
        let data = #"{"label":"Average","unit":"ms","comparison":"lowerIsBetter"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ScorePresentation.self, from: data)
        XCTAssertEqual(decoded.storageScale, 1)
        XCTAssertEqual(decoded.valueFractionDigits, 0)
        XCTAssertEqual(decoded.averageFractionDigits, 1)
        XCTAssertTrue(decoded.separatesUnit)
        XCTAssertEqual(decoded.formatted(288), "288 ms")
    }

    func testReferenceGeometryUsesMeasuredRatiosAndSevenSymmetricZones() {
        let geometry = CenterHitGeometry(sceneSize: CGSize(width: 390, height: 844), config: .reference)
        XCTAssertEqual(geometry.barFrame.width, 312, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.height, 77.688, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.midX, 195, accuracy: 0.001)
        XCTAssertEqual(geometry.barFrame.midY, 222.816, accuracy: 0.001)
        XCTAssertEqual(geometry.zoneFrames.count, 7)
        XCTAssertEqual(geometry.zoneFrames[0].width, geometry.zoneFrames[6].width, accuracy: 0.001)
        XCTAssertEqual(geometry.zoneFrames[1].width, geometry.zoneFrames[5].width, accuracy: 0.001)
        XCTAssertEqual(geometry.zoneFrames[2].width, geometry.zoneFrames[4].width, accuracy: 0.001)
        XCTAssertEqual(geometry.zoneFrames.reduce(0) { $0 + $1.width }, geometry.barFrame.width, accuracy: 0.001)
    }
}
