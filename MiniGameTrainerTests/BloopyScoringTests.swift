import XCTest
@testable import MiniGameTrainer

final class BloopyScoringTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testHeightScoreMatchesReferenceUnit() {
        let unit = 844 * BloopyGameConfig.reference.scoreUnitHeightRatio
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 0, startWorldY: 0, unit: unit), 0)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 12, startWorldY: 0, unit: unit), 12)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 16.9, startWorldY: 0, unit: unit), 16)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 32, startWorldY: 0, unit: unit), 32)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 44, startWorldY: 0, unit: unit), 44)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 88, startWorldY: 0, unit: unit), 88)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 175, startWorldY: 0, unit: unit), 175)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 313, startWorldY: 0, unit: unit), 313)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 408, startWorldY: 0, unit: unit), 408)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 517, startWorldY: 0, unit: unit), 517)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: unit * 554, startWorldY: 0, unit: unit), 554)
    }

    func testZeroDeltaAndTinyNoiseStayAtZero() {
        let unit = 844 * BloopyGameConfig.reference.scoreUnitHeightRatio
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 200, startWorldY: 200, unit: unit), 0)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 200 + 1e-9, startWorldY: 200, unit: unit), 0)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 199.999999, startWorldY: 200, unit: unit), 0)
    }

    func testScoreDoesNotIncreaseFromHeightLoss() {
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 400, startWorldY: 200, unit: 10), 20)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 350, startWorldY: 200, unit: 10), 15)
    }

    func testScoreBeginsExactlyZeroAtInitializationAndStart() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.maxWorldY, logic.startWorldY, accuracy: 1e-9)
        logic.start()
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(
            BloopyScoring.score(maxWorldY: logic.maxWorldY, startWorldY: logic.startWorldY, unit: logic.geometry.scoreUnit),
            0
        )
    }

    func testFirstAscentStartsAtZeroAndUsesReferenceScale() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        XCTAssertEqual(logic.score, 0)
        while logic.ballVelocity.dy > 0, logic.state == .playing {
            logic.update(deltaTime: 1 / 60)
        }
        XCTAssertGreaterThanOrEqual(logic.score, 6)
        XCTAssertLessThanOrEqual(logic.score, 10)
        let expected = BloopyScoring.score(
            maxWorldY: logic.maxWorldY,
            startWorldY: logic.startWorldY,
            unit: logic.geometry.scoreUnit
        )
        XCTAssertEqual(logic.score, expected)
    }

    func testScoreOnlyIncreasesOnNewMaximumHeight() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var previousScore = logic.score
        var previousMax = logic.maxWorldY
        var sawIncrease = false
        var frozenOnDescent = false
        for _ in 0..<240 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            XCTAssertGreaterThanOrEqual(logic.score, previousScore)
            if logic.maxWorldY > previousMax + 1e-9, logic.score > previousScore {
                sawIncrease = true
            }
            if logic.ballVelocity.dy < 0, logic.ballPosition.y + logic.geometry.scoreUnit < logic.maxWorldY {
                XCTAssertEqual(logic.score, previousScore)
                frozenOnDescent = logic.score == previousScore
            }
            previousScore = logic.score
            previousMax = logic.maxWorldY
        }
        XCTAssertTrue(sawIncrease)
        XCTAssertTrue(frozenOnDescent)
    }

    func testScoreDoesNotDecreaseAndFreezesBelowPreviousMaximum() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var peak = 0
        var frozenDuringRepeatBounce = false
        for _ in 0..<360 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            XCTAssertGreaterThanOrEqual(logic.score, peak)
            if logic.score > peak { peak = logic.score }
            if logic.ballPosition.y + logic.geometry.scoreUnit < logic.maxWorldY {
                XCTAssertEqual(logic.score, peak)
                if logic.landingCount >= 1 { frozenDuringRepeatBounce = true }
            }
        }
        XCTAssertGreaterThan(peak, 0)
        XCTAssertTrue(frozenDuringRepeatBounce)
    }

    func testLiveClimbUpdatesScoreFromMaxHeightNotLandings() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let startScore = logic.score
        XCTAssertEqual(startScore, 0)
        var lastScore = startScore
        var increasedWithoutLanding = false
        var lastLandings = logic.landingCount
        for _ in 0..<180 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            if logic.score > lastScore, logic.landingCount == lastLandings {
                increasedWithoutLanding = true
            }
            lastScore = logic.score
            lastLandings = logic.landingCount
        }
        XCTAssertGreaterThan(logic.score, startScore)
        XCTAssertTrue(increasedWithoutLanding)
        XCTAssertEqual(
            logic.score,
            BloopyScoring.score(maxWorldY: logic.maxWorldY, startWorldY: logic.startWorldY, unit: logic.geometry.scoreUnit)
        )
    }

    func testScoreIsMonotonicDuringAutoClimb() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var previous = 0
        for _ in 0..<600 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            XCTAssertGreaterThanOrEqual(logic.score, previous)
            previous = logic.score
        }
        XCTAssertGreaterThan(previous, 20)
    }

    func testScoreScaleRemainsReferenceUnit() {
        XCTAssertEqual(BloopyGameConfig.reference.scoreUnitHeightRatio, 0.038, accuracy: 1e-12)
    }
}
