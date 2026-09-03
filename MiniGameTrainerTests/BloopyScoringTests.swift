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

    func testScoreDoesNotIncreaseFromHeightLoss() {
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 400, startWorldY: 200, unit: 10), 20)
        XCTAssertEqual(BloopyScoring.score(maxWorldY: 350, startWorldY: 200, unit: 10), 15)
    }

    func testLiveClimbUpdatesScoreFromMaxHeightNotLandings() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let startScore = logic.score
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
        let geometry = BloopyGeometry(sceneSize: sceneSize, config: .deterministic())
        XCTAssertEqual(
            logic.score,
            BloopyScoring.score(maxWorldY: logic.maxWorldY, startWorldY: logic.startWorldY, unit: geometry.scoreUnit)
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
}
