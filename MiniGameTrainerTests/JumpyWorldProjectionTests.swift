import XCTest
@testable import MiniGameTrainer

final class JumpyWorldProjectionTests: XCTestCase {
    private let size = CGSize(width: 390, height: 844)

    func testRowsProjectMonotonicallyWithDiminishingPitchAhead() {
        let projection = JumpyWorldProjection(size: size, config: .reference, cameraProgress: 10)
        let points = (-5...12).map { projection.project(CGPoint(x: 0.5, y: 10 + CGFloat($0))) }
        XCTAssertTrue(zip(points, points.dropFirst()).allSatisfy { $0.point.y < $1.point.y })
        XCTAssertGreaterThan(points[5].rowPitch, points[12].rowPitch)
    }

    func testProjectionInverseRoundTripsAndShowsReferenceDepthRange() {
        let projection = JumpyWorldProjection(size: size, config: .reference, cameraProgress: 20)
        for row in stride(from: 14.0, through: 31.0, by: 0.5) {
            let y = projection.project(CGPoint(x: 0.5, y: row)).point.y
            XCTAssertEqual(projection.worldRow(atScreenY: y), row, accuracy: 1e-5)
        }
        XCTAssertLessThanOrEqual(projection.minimumVisibleWorldRow, 14)
        XCTAssertGreaterThanOrEqual(projection.maximumVisibleWorldRow, 31)
    }

    func testAllSevenColumnsAndPlayerArtworkRemainVisible() {
        let config = JumpyGameConfig.reference
        let projection = JumpyWorldProjection(size: size, config: config, cameraProgress: 10)
        let usable = 1 - config.horizontalMarginRatio * 2
        for row in 4...22 {
            for column in 0..<config.columnCount {
                let x = config.horizontalMarginRatio + usable * (CGFloat(column) + 0.5) / CGFloat(config.columnCount)
                let projected = projection.project(CGPoint(x: x, y: CGFloat(row)))
                let halfWidth = size.width * config.playerWidthRatio * projected.depthScale / 2
                XCTAssertGreaterThanOrEqual(projected.point.x - halfWidth, 0)
                XCTAssertLessThanOrEqual(projected.point.x + halfWidth, size.width)
            }
        }
    }

    func testLogicRetreatBoundaryUsesProjectionInverse() {
        let logic = JumpyGameLogic(config: .reference)
        logic.setPlayerForTesting(.init(row: 20, column: 3), score: 20, camera: 20)
        let projection = JumpyWorldProjection(size: CGSize(width: 1, height: 1), config: .reference, cameraProgress: 20)
        XCTAssertEqual(logic.minimumRetreatRow, max(0, Int(ceil(projection.minimumVisibleWorldRow))))
    }
}
