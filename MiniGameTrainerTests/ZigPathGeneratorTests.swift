import XCTest
@testable import MiniGameTrainer

final class ZigPathGeneratorTests: XCTestCase {
    func testGeneratedPathIsConnectedForwardAndUnique() {
        var config = ZigGameConfig.reference; config.randomSeed = 42
        var generator = ZigPathGenerator(config: config)
        var cells: [ZigCell] = []
        for _ in 0..<5_000 { cells.append(generator.nextCell(guaranteedStraightCells: config.guaranteedStraightCells)) }
        XCTAssertEqual(Set(cells).count, cells.count)
        for pair in zip(cells, cells.dropFirst()) {
            let delta = (pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            XCTAssertTrue(delta == (1, 0) || delta == (0, 1))
        }
    }

    func testSeedsAreRepeatableAndVary() {
        func route(_ seed: UInt64) -> [ZigCell] {
            var config = ZigGameConfig.reference; config.randomSeed = seed
            var generator = ZigPathGenerator(config: config)
            return (0..<100).map { _ in generator.nextCell(guaranteedStraightCells: config.guaranteedStraightCells) }
        }
        XCTAssertEqual(route(7), route(7))
        XCTAssertNotEqual(route(7), route(8))
        XCTAssertNil(ZigGameConfig.reference.randomSeed)
    }

    func testRouteContainsShortAndLongerSegments() {
        var config = ZigGameConfig.reference; config.randomSeed = 91
        var generator = ZigPathGenerator(config: config)
        let cells = (0..<1_000).map { _ in generator.nextCell(guaranteedStraightCells: config.guaranteedStraightCells) }
        var runs: [Int] = []; var run = 1; var previousDelta: (Int, Int)?
        for pair in zip(cells, cells.dropFirst()) {
            let delta = (pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            if let previousDelta, previousDelta == delta { run += 1 } else if previousDelta != nil { runs.append(run); run = 1 }
            previousDelta = delta
        }
        runs.append(run)
        XCTAssertTrue(runs.contains(1))
        XCTAssertTrue(runs.contains { $0 >= 4 })
    }
}
