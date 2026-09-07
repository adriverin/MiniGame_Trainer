import XCTest
@testable import MiniGameTrainer

final class JellyCutScoringAndGeneratorTests: XCTestCase {
    func testRelativeAccuracyExamples() {
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.5, achieved: 0.495), 99, accuracy: 1e-10)
        XCTAssertEqual(JellyCutScoring.accuracy(target: 1.0 / 3.0, achieved: 0.330), 99, accuracy: 1e-10)
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.25, achieved: 0.253), 98.8, accuracy: 1e-10)
    }

    func testBadQuarterCutScoresZeroAndImperfectThirtyPercentScoresEighty() {
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.25, achieved: 0.50), 0, accuracy: 1e-12)
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.25, achieved: 0.30), 80, accuracy: 1e-12)
    }

    func testComplementSelectionIsIndependentOfPieceOrder() {
        let forward = JellyCutScoring.achievedFraction([0.252, 0.748], target: 0.25)
        let reverse = JellyCutScoring.achievedFraction([0.748, 0.252], target: 0.25)
        XCTAssertEqual(forward.value, 0.252, accuracy: 1e-12)
        XCTAssertEqual(reverse.value, 0.252, accuracy: 1e-12)
    }

    func testHalfSymmetryAndAccuracyRange() {
        let first = JellyCutScoring.achievedFraction([0.49, 0.51], target: 0.5)
        let second = JellyCutScoring.achievedFraction([0.51, 0.49], target: 0.5)
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.5, achieved: first.value), 98, accuracy: 1e-12)
        XCTAssertEqual(JellyCutScoring.accuracy(target: 0.5, achieved: second.value), 98, accuracy: 1e-12)
        for achieved in stride(from: -1.0, through: 2.0, by: 0.01) {
            XCTAssertTrue((0...100).contains(JellyCutScoring.accuracy(target: 0.25, achieved: achieved)))
        }
    }

    func testDisplayedPairAlwaysSumsToOneHundred() {
        let displayed = JellyCutScoring.displayedPercentages([0.25253, 0.74747])
        XCTAssertEqual(displayed[0], 25.3, accuracy: 1e-12)
        XCTAssertEqual(displayed[1], 74.7, accuracy: 1e-12)
        XCTAssertEqual(displayed.reduce(0, +), 100, accuracy: 1e-12)
    }

    func testSameSeedReproducesSessionAndDifferentSeedVaries() {
        var first = SeededJellyRandomNumberGenerator(seed: 42)
        var replay = SeededJellyRandomNumberGenerator(seed: 42)
        var different = SeededJellyRandomNumberGenerator(seed: 43)
        let a = JellyShapeGenerator.sessionShapes(using: &first)
        let b = JellyShapeGenerator.sessionShapes(using: &replay)
        let c = JellyShapeGenerator.sessionShapes(using: &different)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(Set(a.map(String.init(describing:))).count, 3)
    }

    func testGeneratedShapesRemainSimpleBoundedAndNondegenerate() {
        var random = SeededJellyRandomNumberGenerator(seed: 7)
        for _ in 0..<1_000 {
            let shape = JellyShapeGenerator.generate(using: &random)
            XCTAssertTrue(JellyShapeGenerator.validate(shape))
            XCTAssertTrue(JellyPolygonGeometry.isSimple(shape))
            XCTAssertGreaterThan(JellyPolygonGeometry.area(of: shape), 0.55)
            XCTAssertGreaterThan(JellyPolygonGeometry.minimumEdgeLength(of: shape), 0.005)
        }
    }
}
