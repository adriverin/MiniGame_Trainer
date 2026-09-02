import XCTest
@testable import MiniGameTrainer

final class TowerStackMovementTests: XCTestCase {
    private func makeBlock(position: CGFloat = 0, direction: CGFloat = 1, speed: CGFloat = 100) -> TowerStackMovingBlock {
        TowerStackMovingBlock(
            axis: .x,
            position: position,
            direction: direction,
            speed: speed,
            minimum: -100,
            maximum: 100,
            footprint: TowerStackFootprint(centerX: 0, centerZ: 0, width: 50, depth: 50),
            layer: 0
        )
    }

    func testMovementIsSpeedTimesDeltaTime() {
        var block = makeBlock(position: 0, speed: 40)
        block.advance(by: 0.25)
        XCTAssertEqual(block.position, 10, accuracy: 1e-9)
        XCTAssertEqual(block.footprint.centerX, 10, accuracy: 1e-9)
        XCTAssertEqual(block.footprint.width, 50)
    }

    func testReflectionPreservesOvershoot() {
        var block = makeBlock(position: 98, speed: 500)
        block.advance(by: 0.01) // +5: 98 → 100 with 3 left over → 97
        XCTAssertEqual(block.position, 97, accuracy: 1e-9)
        XCTAssertEqual(block.direction, -1)
    }

    func testReflectionAtLowerBound() {
        var block = makeBlock(position: -95, direction: -1, speed: 100)
        block.advance(by: 0.1) // −10: −95 → −100, 5 left → −95 heading +
        XCTAssertEqual(block.position, -95, accuracy: 1e-9)
        XCTAssertEqual(block.direction, 1)
    }

    func testMultipleBouncesInOneStepAreHandled() {
        var block = makeBlock(position: 0, speed: 100)
        block.advance(by: 4.5) // 450 units: 0→100 (100), →−100 (300), →50 (450)
        XCTAssertEqual(block.position, 50, accuracy: 1e-9)
        XCTAssertEqual(block.direction, 1)
    }

    func testSixtyAndOneTwentyHertzProduceSamePositionAndDirection() {
        var sixty = makeBlock(position: -20, speed: 130)
        var oneTwenty = sixty
        for _ in 0..<600 { sixty.advance(by: 1.0 / 60) }
        for _ in 0..<1_200 { oneTwenty.advance(by: 1.0 / 120) }
        XCTAssertEqual(sixty.position, oneTwenty.position, accuracy: 1e-6)
        XCTAssertEqual(sixty.direction, oneTwenty.direction)
        let analytic = makeBlock(position: -20, speed: 130).advanced(by: 10)
        XCTAssertEqual(sixty.position, analytic.position, accuracy: 1e-6)
    }

    func testTimeToReachOnlyOnCurrentHeading() {
        let block = makeBlock(position: 10, direction: 1, speed: 50)
        XCTAssertEqual(block.timeToReach(35) ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertNil(block.timeToReach(-10))
        XCTAssertNil(block.timeToReach(150))
        XCTAssertEqual(block.advanced(by: block.timeToReach(35)!).position, 35, accuracy: 1e-9)
    }

    func testZeroOrNegativeDeltaIsIgnored() {
        var block = makeBlock(position: 5)
        block.advance(by: 0)
        block.advance(by: -1)
        XCTAssertEqual(block.position, 5)
    }
}
