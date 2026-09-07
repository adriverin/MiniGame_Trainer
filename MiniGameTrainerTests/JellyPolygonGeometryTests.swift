import XCTest
@testable import MiniGameTrainer

final class JellyPolygonGeometryTests: XCTestCase {
    func testSquareAreaAndReversedWindingAreOne() {
        let square = polygon([(0, 0), (1, 0), (1, 1), (0, 1)])
        XCTAssertEqual(JellyPolygonGeometry.area(of: square), 1, accuracy: 1e-12)
        XCTAssertEqual(JellyPolygonGeometry.area(of: square.reversed()), 1, accuracy: 1e-12)
    }

    func testExactHalfCutConservesArea() throws {
        let square = polygon([(0, 0), (1, 0), (1, 1), (0, 1)])
        let split = try XCTUnwrap(JellyPolygonGeometry.split(square, by: line((0.5, -1), (0.5, 2))))
        XCTAssertEqual(JellyPolygonGeometry.area(of: split.negative), 0.5, accuracy: 1e-12)
        XCTAssertEqual(JellyPolygonGeometry.area(of: split.positive), 0.5, accuracy: 1e-12)
        XCTAssertTrue(JellyPolygonGeometry.areaIsConserved(original: square, split: split))
    }

    func testExactThirdCut() throws {
        let rectangle = polygon([(0, 0), (3, 0), (3, 1), (0, 1)])
        let split = try XCTUnwrap(JellyPolygonGeometry.split(rectangle, by: line((1, -1), (1, 2))))
        let areas = [JellyPolygonGeometry.area(of: split.negative), JellyPolygonGeometry.area(of: split.positive)].sorted()
        XCTAssertEqual(areas[0], 1, accuracy: 1e-12)
        XCTAssertEqual(areas[1], 2, accuracy: 1e-12)
    }

    func testExactQuarterCut() throws {
        let square = polygon([(0, 0), (1, 0), (1, 1), (0, 1)])
        let split = try XCTUnwrap(JellyPolygonGeometry.split(square, by: line((0.25, -1), (0.25, 2))))
        let areas = [JellyPolygonGeometry.area(of: split.negative), JellyPolygonGeometry.area(of: split.positive)].sorted()
        XCTAssertEqual(areas[0], 0.25, accuracy: 1e-12)
        XCTAssertEqual(areas[1], 0.75, accuracy: 1e-12)
    }

    func testMildlyConcavePolygonSupportsSeveralCuts() throws {
        let concave = polygon([(0, 0), (4, 0), (4, 4), (2.5, 3), (2, 4), (0, 4)])
        for cut in [line((2, -2), (2, 6)), line((-2, 2), (6, 2)), line((-1, -1), (5, 5))] {
            let split = try XCTUnwrap(JellyPolygonGeometry.split(concave, by: cut))
            XCTAssertTrue(JellyPolygonGeometry.areaIsConserved(original: concave, split: split))
            XCTAssertGreaterThan(JellyPolygonGeometry.area(of: split.negative), 0)
            XCTAssertGreaterThan(JellyPolygonGeometry.area(of: split.positive), 0)
        }
    }

    func testLineThroughVertexHasNoDuplicateBrokenVertices() throws {
        let square = polygon([(0, 0), (2, 0), (2, 2), (0, 2)])
        let split = try XCTUnwrap(JellyPolygonGeometry.split(square, by: line((0, 0), (2, 2))))
        XCTAssertEqual(split.intersections.count, 2)
        XCTAssertTrue(JellyPolygonGeometry.areaIsConserved(original: square, split: split))
    }

    func testNearParallelCutIsNumericallyStable() throws {
        let square = polygon([(0, 0), (100, 0), (100, 100), (0, 100)])
        let split = try XCTUnwrap(JellyPolygonGeometry.split(square, by: line((-10, 0.001), (110, 0.002))))
        let areas = [JellyPolygonGeometry.area(of: split.negative), JellyPolygonGeometry.area(of: split.positive)]
        XCTAssertTrue(areas.allSatisfy(\.isFinite))
        XCTAssertTrue(JellyPolygonGeometry.areaIsConserved(original: square, split: split))
    }

    func testTangentAndMissAreInvalidSplits() {
        let square = polygon([(0, 0), (1, 0), (1, 1), (0, 1)])
        XCTAssertNil(JellyPolygonGeometry.split(square, by: line((-1, 1), (2, 1))))
        XCTAssertNil(JellyPolygonGeometry.split(square, by: line((-1, 2), (2, 2))))
    }

    func testGeneratedShapeFuzzConservesAreaWithoutNaN() {
        var random = SeededJellyRandomNumberGenerator(seed: 982_451_653)
        var validCuts = 0
        for _ in 0..<120 {
            let shape = JellyShapeGenerator.generate(using: &random).map {
                CGPoint(x: $0.x * 300, y: $0.y * 300)
            }
            for _ in 0..<30 {
                let angle = Double(random.next() % 1_000_000) / 1_000_000 * 2 * .pi
                let offset = CGFloat(Int(random.next() % 241) - 120)
                let normal = CGVector(dx: -sin(angle), dy: cos(angle))
                let direction = CGVector(dx: cos(angle), dy: sin(angle))
                let center = CGPoint(x: normal.dx * offset, y: normal.dy * offset)
                let cut = JellyCutLine(
                    start: CGPoint(x: center.x - direction.dx * 500, y: center.y - direction.dy * 500),
                    end: CGPoint(x: center.x + direction.dx * 500, y: center.y + direction.dy * 500)
                )!
                guard let split = JellyPolygonGeometry.split(shape, by: cut) else { continue }
                validCuts += 1
                let areas = [JellyPolygonGeometry.area(of: split.negative), JellyPolygonGeometry.area(of: split.positive)]
                XCTAssertTrue(areas.allSatisfy { $0.isFinite && $0 >= 0 })
                XCTAssertTrue(JellyPolygonGeometry.areaIsConserved(original: shape, split: split, tolerance: 1e-6))
            }
        }
        XCTAssertGreaterThan(validCuts, 1_000)
    }

    private func polygon(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] {
        values.map(CGPoint.init)
    }

    private func line(_ start: (CGFloat, CGFloat), _ end: (CGFloat, CGFloat)) -> JellyCutLine {
        JellyCutLine(start: CGPoint(x: start.0, y: start.1), end: CGPoint(x: end.0, y: end.1))!
    }
}
