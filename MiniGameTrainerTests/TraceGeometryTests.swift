import XCTest
@testable import MiniGameTrainer

final class TraceGeometryTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    func testHitInsideRadiusIsAcceptedAndOutsideIsNot() {
        let geometry = TraceGeometry(
            sceneSize: sceneSize,
            config: .reference,
            grid: TraceGridSize(rows: 3, columns: 2)
        )
        let node = TraceNode(row: 1, column: 0)
        let center = geometry.position(for: node)
        XCTAssertEqual(geometry.node(at: center), node)
        XCTAssertTrue(geometry.isInsideHitRadius(point: center, node: node))

        let inside = CGPoint(x: center.x + geometry.nodeHitRadius * 0.5, y: center.y)
        XCTAssertEqual(geometry.node(at: inside), node)

        let boundary = CGPoint(x: center.x + geometry.nodeHitRadius, y: center.y)
        XCTAssertEqual(geometry.node(at: boundary), node, "Boundary is inclusive")

        let outside = CGPoint(x: center.x + geometry.nodeHitRadius + 2, y: center.y)
        XCTAssertNotEqual(geometry.node(at: outside), node)
        XCTAssertFalse(geometry.isInsideHitRadius(point: outside, node: node))
    }

    func testHitCirclesDoNotSwallowNeighborCenters() {
        let geometry = TraceGeometry(
            sceneSize: sceneSize,
            config: .reference,
            grid: TraceGridSize(rows: 3, columns: 2)
        )
        let a = TraceNode(row: 0, column: 0)
        let b = TraceNode(row: 0, column: 1)
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(a, b))
        let centerB = geometry.position(for: b)
        XCTAssertEqual(geometry.node(at: centerB), b)
        XCTAssertFalse(geometry.isInsideHitRadius(point: centerB, node: a))
        XCTAssertLessThan(geometry.nodeHitRadius * 2, geometry.spacing + 1e-6)
    }

    func testNormalizedHUDRatiosAreFinite() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, grid: .smallest)
        XCTAssertGreaterThan(geometry.timerFrame.width, 0)
        XCTAssertGreaterThan(geometry.timerFrame.height, 0)
        XCTAssertEqual(geometry.scorePosition.x, sceneSize.width / 2, accuracy: 1e-9)
        XCTAssertGreaterThan(geometry.nodeVisualRadius, 0)
        XCTAssertGreaterThan(geometry.lineWidth, 0)
    }
}
