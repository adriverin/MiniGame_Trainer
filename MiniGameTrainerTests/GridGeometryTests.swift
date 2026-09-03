import XCTest
@testable import MiniGameTrainer

final class GridGeometryTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    func testReferenceGridsThroughLevelTenDoNotOverlapOrOverflow() {
        for level in 1...10 {
            let size = GridDifficultyModel.gridSize(forLevel: level)
            let geometry = GridGeometry(sceneSize: sceneSize, rows: size.rows, columns: size.columns, config: .reference)
            XCTAssertFalse(geometry.cellsOverlap, "Level \(level) cells overlap")
            XCTAssertFalse(geometry.overflowsViewport, "Level \(level) overflows \(sceneSize)")
            XCTAssertGreaterThan(geometry.gap, 0)
            XCTAssertEqual(geometry.rows, size.rows)
            XCTAssertEqual(geometry.columns, size.columns)
        }
    }

    func testCellSizeShrinksSoASevenBySevenBoardFitsTheSameEnvelope() {
        let small = GridGeometry(sceneSize: sceneSize, rows: 3, columns: 3, config: .reference)
        let large = GridGeometry(sceneSize: sceneSize, rows: 7, columns: 7, config: .reference)
        XCTAssertLessThan(large.cellSize, small.cellSize)
        XCTAssertFalse(large.overflowsViewport)
        XCTAssertLessThanOrEqual(large.gridFrame.width, sceneSize.width * GridGameConfig.reference.gridWidthRatio + 0.5)
        XCTAssertLessThanOrEqual(large.gridFrame.height, sceneSize.height * GridGameConfig.reference.gridHeightRatio + 0.5)
    }

    func testHitTestingMapsCentersAndRejectsGaps() {
        let geometry = GridGeometry(sceneSize: sceneSize, rows: 3, columns: 3, config: .reference)
        let target = GridCell(row: 1, column: 2)
        let frame = geometry.frame(for: target)
        XCTAssertEqual(geometry.cell(at: CGPoint(x: frame.midX, y: frame.midY)), target)
        XCTAssertEqual(geometry.cell(at: CGPoint(x: 0, y: 0)), nil)
        let neighbour = geometry.frame(for: GridCell(row: 1, column: 1))
        let gapPoint = CGPoint(x: (neighbour.maxX + frame.minX) / 2, y: frame.midY)
        XCTAssertNil(geometry.cell(at: gapPoint))
    }

    func testTopLeftCellIsRowZeroColumnZero() {
        let geometry = GridGeometry(sceneSize: sceneSize, rows: 4, columns: 4, config: .reference)
        let topLeft = geometry.frame(for: GridCell(row: 0, column: 0))
        let bottomRight = geometry.frame(for: GridCell(row: 3, column: 3))
        XCTAssertGreaterThan(topLeft.maxY, bottomRight.maxY)
        XCTAssertLessThan(topLeft.minX, bottomRight.minX)
    }
}
