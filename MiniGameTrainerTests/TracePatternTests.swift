import XCTest
@testable import MiniGameTrainer

final class TracePatternTests: XCTestCase {
    func testGeneratedPathHasRequestedLengthAndStaysOnHexField() {
        var rng = AnyRandomNumberGenerator.seeded(7)
        let generator = TracePatternGenerator(config: .reference)
        let field = TraceHexField(radius: 2)
        let path = generator.generate(field: field, length: 9, rng: &rng)
        XCTAssertEqual(path.count, 9)
        XCTAssertTrue(generator.isValid(path, field: field, requireAdjacent: true))
        XCTAssertEqual(Set(path).count, path.count)
    }

    func testGeneratorIsDeterministicUnderSeed() {
        let generator = TracePatternGenerator(config: .reference)
        let field = TraceHexField(radius: 2)
        var first = AnyRandomNumberGenerator.seeded(123)
        var second = AnyRandomNumberGenerator.seeded(123)
        XCTAssertEqual(
            generator.generate(field: field, length: 8, rng: &first),
            generator.generate(field: field, length: 8, rng: &second)
        )
    }

    func testProductionSeedsProduceDifferentPaths() {
        let generator = TracePatternGenerator(config: .reference)
        let field = TraceHexField(radius: 3)
        var first = AnyRandomNumberGenerator.seeded(11)
        var second = AnyRandomNumberGenerator.seeded(99)
        XCTAssertNotEqual(
            generator.generate(field: field, length: 12, rng: &first),
            generator.generate(field: field, length: 12, rng: &second)
        )
    }

    func testManyGeneratedPathsAreExactSelfAvoidingWalks() {
        var rng = AnyRandomNumberGenerator.seeded(21)
        let generator = TracePatternGenerator(config: .reference)
        let field = TraceHexField(radius: 3)
        for length in [4, 6, 9, 12, 15, 21] {
            for _ in 0..<12 {
                let path = generator.generate(field: field, length: length, rng: &rng)
                XCTAssertEqual(path.count, length)
                XCTAssertEqual(Set(path).count, path.count)
                XCTAssertTrue(path.allSatisfy(field.contains))
                for index in 1..<path.count {
                    XCTAssertNotEqual(path[index], path[index - 1])
                    XCTAssertTrue(TraceHexNeighbors.isNeighbor(path[index - 1], path[index]))
                }
            }
        }
    }

    func testLongWalkDoesNotSilentlyShorten() {
        var rng = AnyRandomNumberGenerator.seeded(404)
        let generator = TracePatternGenerator(config: .reference)
        let field = TraceHexField(radius: 3)
        let path = generator.generate(field: field, length: 24, rng: &rng)
        XCTAssertEqual(path.count, 24)
        XCTAssertTrue(generator.isValid(path, field: field, requireAdjacent: true))
    }

    func testHexNeighborsAreTheSixAxialDirections() {
        let node = TraceNode(q: 2, r: -1)
        let neighbors = Set(TraceHexNeighbors.neighbors(of: node))
        let expected: Set<TraceNode> = [
            TraceNode(q: 3, r: -1),
            TraceNode(q: 1, r: -1),
            TraceNode(q: 2, r: 0),
            TraceNode(q: 2, r: -2),
            TraceNode(q: 3, r: -2),
            TraceNode(q: 1, r: 0),
        ]
        XCTAssertEqual(neighbors, expected)
        for neighbor in neighbors {
            XCTAssertTrue(TraceHexNeighbors.isNeighbor(neighbor, node))
        }
    }
}
