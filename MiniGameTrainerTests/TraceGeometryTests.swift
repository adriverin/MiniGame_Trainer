import XCTest
@testable import MiniGameTrainer

final class TraceGeometryTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    func testRadiusOneHasSevenNodesAndRowCountsTwoThreeTwo() {
        let field = TraceHexField(radius: 1)
        XCTAssertEqual(field.nodeCount, 7)
        XCTAssertEqual(field.allNodes.count, 7)
        XCTAssertEqual(field.rowCounts, [2, 3, 2])
    }

    func testRadiusTwoHasNineteenNodesAndSymmetricRows() {
        let field = TraceHexField(radius: 2)
        XCTAssertEqual(field.nodeCount, 19)
        XCTAssertEqual(field.allNodes.count, 19)
        XCTAssertEqual(field.rowCounts, [3, 4, 5, 4, 3])
    }

    func testRadiusThreeHasThirtySevenNodesAndSymmetricRows() {
        let field = TraceHexField(radius: 3)
        XCTAssertEqual(field.nodeCount, 37)
        XCTAssertEqual(field.allNodes.count, 37)
        XCTAssertEqual(field.rowCounts, [4, 5, 6, 7, 6, 5, 4])
    }

    func testEveryNeighborIsOnTheFieldAndInteriorNodesHaveSix() {
        for radius in 1...3 {
            let field = TraceHexField(radius: radius)
            let nodes = Set(field.allNodes)
            for node in field.allNodes {
                let neighbors = TraceHexNeighbors.neighbors(of: node)
                XCTAssertEqual(neighbors.count, 6)
                XCTAssertEqual(Set(neighbors).count, 6)
                let onField = neighbors.filter(field.contains)
                XCTAssertTrue(onField.allSatisfy { nodes.contains($0) })
                for neighbor in onField {
                    XCTAssertTrue(TraceHexNeighbors.isNeighbor(neighbor, node))
                }
            }
            XCTAssertEqual(TraceHexNeighbors.neighbors(of: TraceNode(q: 0, r: 0)).filter(field.contains).count, 6)
        }
    }

    func testNeighborDistancesAreEqual() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: TraceHexField(radius: 2))
        let origin = TraceNode(q: 0, r: 0)
        let distances = TraceHexNeighbors.neighbors(of: origin).map { neighbor in
            let a = geometry.position(for: origin)
            let b = geometry.position(for: neighbor)
            return hypot(a.x - b.x, a.y - b.y)
        }
        for distance in distances {
            XCTAssertEqual(distance, geometry.spacing, accuracy: 1e-6)
        }
    }

    func testHitInsideRadiusIsAcceptedAndOutsideIsNot() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: TraceHexField(radius: 1))
        let node = TraceNode(q: 0, r: 0)
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
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: TraceHexField(radius: 1))
        let a = TraceNode(q: 0, r: 0)
        let b = TraceNode(q: 1, r: 0)
        XCTAssertTrue(TraceHexNeighbors.isNeighbor(a, b))
        let centerB = geometry.position(for: b)
        XCTAssertEqual(geometry.node(at: centerB), b)
        XCTAssertFalse(geometry.isInsideHitRadius(point: centerB, node: a))
        XCTAssertLessThan(geometry.nodeHitRadius * 2, geometry.spacing + 1e-6)
    }

    func testVisualRadiusIsSmallerThanHitRadiusAndLineIsThinnerThanNodeDiameter() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: TraceHexField(radius: 3))
        XCTAssertLessThan(geometry.nodeVisualRadius, geometry.nodeHitRadius)
        XCTAssertLessThan(geometry.lineWidth * 2, geometry.nodeVisualRadius * 2)
        XCTAssertGreaterThan(geometry.nodeVisualRadius, 0)
        XCTAssertGreaterThan(geometry.lineWidth, 0)
    }

    func testNormalizedHUDRatiosAreFinite() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: .smallest)
        XCTAssertGreaterThan(geometry.timerFrame.width, 0)
        XCTAssertGreaterThan(geometry.timerFrame.height, 0)
        XCTAssertEqual(geometry.scorePosition.x, sceneSize.width / 2, accuracy: 1e-9)
        XCTAssertGreaterThan(geometry.nodeVisualRadius, 0)
        XCTAssertGreaterThan(geometry.lineWidth, 0)
    }
}
