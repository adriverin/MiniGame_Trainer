import XCTest
@testable import MiniGameTrainer

final class TowerStackOverlapTests: XCTestCase {
    private func resolve(
        target: TowerStackInterval,
        incoming: TowerStackInterval,
        axis: TowerStackAxis = .x
    ) -> TowerStackPlacementResolution {
        let base = TowerStackFootprint(centerX: 0, centerZ: 0, width: 100, depth: 100)
        let targetFootprint = base.replacing(target, along: axis)
        let incomingFootprint = base.replacing(incoming, along: axis)
        return TowerStackPlacementResolver.resolve(
            incoming: incomingFootprint,
            target: targetFootprint,
            axis: axis,
            overlapTolerance: 0.0005,
            minimumViableDimension: 0.002
        )
    }

    func testPerfectPlacementKeepsCenterAndDimension() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 0, maximum: 100))
        XCTAssertEqual(result.overlapLength, 100, accuracy: 1e-9)
        XCTAssertEqual(result.overlapRatio, 1, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerX ?? .nan, 50, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.width ?? .nan, 100, accuracy: 1e-9)
        XCTAssertTrue(result.cutPieces.isEmpty)
        XCTAssertFalse(result.isMiss)
    }

    func testPartialOverlapKeepsExactIntersection() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 10, maximum: 110))
        XCTAssertEqual(result.surviving?.minX ?? .nan, 10, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.maxX ?? .nan, 100, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.width ?? .nan, 90, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerX ?? .nan, 55, accuracy: 1e-9)
        XCTAssertEqual(result.offset, 10, accuracy: 1e-9)
        XCTAssertEqual(result.overlapRatio, 0.9, accuracy: 1e-9)
        XCTAssertEqual(result.cutPieces.count, 1)
        XCTAssertEqual(result.cutPieces.first?.minX ?? .nan, 100, accuracy: 1e-9)
        XCTAssertEqual(result.cutPieces.first?.maxX ?? .nan, 110, accuracy: 1e-9)
    }

    func testNonMovingAxisIsInherited() {
        let target = TowerStackFootprint(centerX: 3, centerZ: -2, width: 40, depth: 25)
        let incoming = target.moved(to: 7, along: .z)
        let result = TowerStackPlacementResolver.resolve(
            incoming: incoming, target: target, axis: .z, overlapTolerance: 0, minimumViableDimension: 0
        )
        XCTAssertEqual(result.surviving?.width ?? .nan, 40, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerX ?? .nan, 3, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.depth ?? .nan, 16, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerZ ?? .nan, 2.5, accuracy: 1e-9)
    }

    func testSymmetricOffsetsGiveEqualOverlapAndMirroredCenters() {
        let plus = resolve(target: .init(minimum: -50, maximum: 50), incoming: .init(center: 7, length: 100))
        let minus = resolve(target: .init(minimum: -50, maximum: 50), incoming: .init(center: -7, length: 100))
        XCTAssertEqual(plus.overlapLength, minus.overlapLength, accuracy: 1e-9)
        XCTAssertEqual(plus.overlapLength, 93, accuracy: 1e-9)
        XCTAssertEqual(plus.surviving?.centerX ?? .nan, -(minus.surviving?.centerX ?? .nan), accuracy: 1e-9)
        XCTAssertEqual(plus.surviving?.centerX ?? .nan, 3.5, accuracy: 1e-9)
    }

    func testCompleteMissHasNoSurvivor() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 101, maximum: 201))
        XCTAssertTrue(result.isMiss)
        XCTAssertNil(result.surviving)
        XCTAssertLessThanOrEqual(result.overlapLength, 0)
        XCTAssertEqual(result.overlapRatio, 0)
        XCTAssertTrue(result.cutPieces.isEmpty)
    }

    func testTouchingEdgesCountAsMiss() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 100, maximum: 200))
        XCTAssertTrue(result.isMiss)
    }

    func testOverlapBelowMinimumViableDimensionIsMiss() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 99.999, maximum: 199.999))
        XCTAssertTrue(result.isMiss)
    }

    func testTinyPositiveOverlapAboveThresholdsSurvivesWithoutEnlargement() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 99.9, maximum: 199.9))
        XCTAssertFalse(result.isMiss)
        XCTAssertEqual(result.surviving?.width ?? .nan, 0.1, accuracy: 1e-6)
        XCTAssertTrue(result.surviving?.isNumericallyValid ?? false)
    }

    func testIncomingSmallerThanTargetInsideIsFullyKept() {
        let result = resolve(target: .init(minimum: 0, maximum: 100), incoming: .init(minimum: 20, maximum: 60))
        XCTAssertEqual(result.surviving?.width ?? .nan, 40, accuracy: 1e-9)
        XCTAssertTrue(result.cutPieces.isEmpty)
    }

    func testZAxisPartialOverlapTrimsDepthOnly() {
        let result = resolve(
            target: .init(minimum: 0, maximum: 100),
            incoming: .init(minimum: 10, maximum: 110),
            axis: .z
        )
        XCTAssertEqual(result.surviving?.depth ?? .nan, 90, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerZ ?? .nan, 55, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.width ?? .nan, 100, accuracy: 1e-9)
        XCTAssertEqual(result.surviving?.centerX ?? .nan, 0, accuracy: 1e-9)
    }
}
