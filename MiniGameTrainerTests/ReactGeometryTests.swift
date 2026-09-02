import XCTest
@testable import MiniGameTrainer

final class ReactGeometryTests: XCTestCase {
    private let size = CGSize(width: 393, height: 852)

    func testReferenceGeometryResolvesMeasuredRatios() {
        let geometry = ReactGeometry(sceneSize: size, config: .reference)
        XCTAssertEqual(geometry.circleDiameter, 393 * 0.197, accuracy: 0.001)
        XCTAssertEqual(geometry.horizontalGap / geometry.circleDiameter, 0.135, accuracy: 0.001)
        XCTAssertEqual(geometry.verticalGap / geometry.circleDiameter, 0.135, accuracy: 0.001)
        XCTAssertEqual(geometry.gridCenter.x, size.width / 2, accuracy: 0.001)
        XCTAssertEqual(geometry.gridCenter.y, size.height * 0.469, accuracy: 0.001)
    }

    func testIndicesMapAcrossRowsFromTopLeftToBottomRight() {
        let geometry = ReactGeometry(sceneSize: size, config: .reference)
        XCTAssertLessThan(geometry.center(for: 0).x, geometry.center(for: 2).x)
        XCTAssertGreaterThan(geometry.center(for: 0).y, geometry.center(for: 6).y)
        XCTAssertEqual(geometry.center(for: 4), geometry.gridCenter)
    }

    func testCircularHitTestingRejectsGapAndOutsideCorner() {
        let geometry = ReactGeometry(sceneSize: size, config: .reference)
        for index in 0..<9 {
            XCTAssertEqual(geometry.targetIndex(at: geometry.center(for: index)), index)
        }
        let gapPoint = CGPoint(
            x: (geometry.center(for: 0).x + geometry.center(for: 1).x) / 2,
            y: geometry.center(for: 0).y
        )
        XCTAssertNil(geometry.targetIndex(at: gapPoint))
        XCTAssertNil(geometry.targetIndex(at: .zero))
    }
}
