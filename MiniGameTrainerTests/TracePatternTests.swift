import XCTest
@testable import MiniGameTrainer

final class TracePatternTests: XCTestCase {
    func testGeneratedPathHasRequestedLengthAndStaysInGrid() {
        var rng = AnyRandomNumberGenerator.seeded(7)
        let generator = TracePatternGenerator(config: .reference)
        let grid = TraceGridSize(rows: 6, columns: 5)
        let path = generator.generate(grid: grid, length: 9, rng: &rng)
        XCTAssertEqual(path.count, 9)
        XCTAssertTrue(generator.isValid(path, grid: grid, requireAdjacent: true))
        XCTAssertEqual(Set(path).count, path.count)
    }

    func testGeneratorIsDeterministicUnderSeed() {
        let generator = TracePatternGenerator(config: .reference)
        let grid = TraceGridSize(rows: 5, columns: 4)
        var first = AnyRandomNumberGenerator.seeded(123)
        var second = AnyRandomNumberGenerator.seeded(123)
        XCTAssertEqual(
            generator.generate(grid: grid, length: 7, rng: &first),
            generator.generate(grid: grid, length: 7, rng: &second)
        )
    }

    func testNoConsecutiveDuplicatesAndNeighborsOnly() {
        var rng = AnyRandomNumberGenerator.seeded(21)
        let generator = TracePatternGenerator(config: .reference)
        let grid = TraceGridSize(rows: 8, columns: 7)
        for _ in 0..<20 {
            let path = generator.generate(grid: grid, length: 12, rng: &rng)
            XCTAssertTrue(generator.isValid(path, grid: grid, requireAdjacent: true))
            for index in 1..<path.count {
                XCTAssertNotEqual(path[index], path[index - 1])
                XCTAssertTrue(TraceHexNeighbors.isNeighbor(path[index - 1], path[index]))
            }
        }
    }

    func testHexNeighborsAreSixAndSymmetric() {
        let node = TraceNode(row: 4, column: 3)
        let neighbors = TraceHexNeighbors.neighbors(of: node)
        XCTAssertEqual(neighbors.count, 6)
        XCTAssertEqual(Set(neighbors).count, 6)
        for neighbor in neighbors {
            XCTAssertTrue(TraceHexNeighbors.isNeighbor(neighbor, node))
        }
    }
}
