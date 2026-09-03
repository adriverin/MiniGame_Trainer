import XCTest
@testable import MiniGameTrainer

final class GridPatternTests: XCTestCase {
    func testGeneratorNeverRepeatsACellAndHonoursCount() {
        var generator = SeededRandomNumberGenerator(seed: 99)
        for level in 1...10 {
            let size = GridDifficultyModel.gridSize(forLevel: level)
            let count = GridDifficultyModel.targetCount(forLevel: level, rows: size.rows, columns: size.columns)
            let pattern = GridDifficultyModel.generatePattern(
                rows: size.rows,
                columns: size.columns,
                count: count,
                generator: &generator
            )
            XCTAssertEqual(pattern.count, count)
            XCTAssertEqual(Set(pattern).count, count)
        }
    }

    func testEveryCoordinateStaysInsideBounds() {
        var generator = SeededRandomNumberGenerator(seed: 123)
        for _ in 0..<200 {
            let rows = Int.random(in: 2...7, using: &generator)
            let columns = Int.random(in: 2...7, using: &generator)
            let count = Int.random(in: 1...(rows * columns - 1), using: &generator)
            let pattern = GridDifficultyModel.generatePattern(
                rows: rows,
                columns: columns,
                count: count,
                generator: &generator
            )
            XCTAssertTrue(pattern.allSatisfy { (0..<rows).contains($0.row) && (0..<columns).contains($0.column) })
        }
    }

    func testSameSeedAndConfigReproduceTheSamePattern() {
        func pattern(seed: UInt64) -> Set<GridCell> {
            var generator = SeededRandomNumberGenerator(seed: seed)
            return GridDifficultyModel.generatePattern(rows: 5, columns: 5, count: 13, generator: &generator)
        }
        XCTAssertEqual(pattern(seed: 42), pattern(seed: 42))
        XCTAssertNotEqual(pattern(seed: 42), pattern(seed: 43))
    }

    func testQualityAssurancePatternIsTopLeftCenterBottomRight() {
        XCTAssertEqual(
            GridDifficultyModel.qualityAssurancePattern,
            [GridCell(row: 0, column: 0), GridCell(row: 1, column: 1), GridCell(row: 2, column: 2)]
        )
        var generator = SeededRandomNumberGenerator(seed: 1)
        let forced = GridDifficultyModel.generatePattern(
            rows: 3,
            columns: 3,
            count: 8,
            generator: &generator,
            forced: GridDifficultyModel.qualityAssurancePattern
        )
        XCTAssertEqual(forced, GridDifficultyModel.qualityAssurancePattern)
    }

    func testLogicSeedReplaysTheOpeningPattern() {
        let first = GridGameLogic(config: .reference, seed: 11)
        first.start(at: 0)
        let second = GridGameLogic(config: .reference, seed: 11)
        second.start(at: 0)
        XCTAssertEqual(first.targetCells, second.targetCells)
        let other = GridGameLogic(config: .reference, seed: 12)
        other.start(at: 0)
        XCTAssertNotEqual(first.targetCells, other.targetCells)
    }
}
