import XCTest
@testable import MiniGameTrainer

final class BloopyWrapTests: XCTestCase {
    func testHorizontalWrapRightPreservesOvershoot() {
        let result = BloopyPhysics.horizontalStep(
            position: 98,
            velocity: 5,
            input: .none,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 1_000,
            deltaTime: 1,
            worldWidth: 100
        )
        XCTAssertEqual(result.position, 3, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, 5, accuracy: 1e-9)
    }

    func testHorizontalWrapLeftPreservesOvershoot() {
        let result = BloopyPhysics.horizontalStep(
            position: 2,
            velocity: -5,
            input: .none,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 1_000,
            deltaTime: 1,
            worldWidth: 100
        )
        XCTAssertEqual(result.position, 97, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, -5, accuracy: 1e-9)
    }

    func testMultipleWrapsUseRobustModulo() {
        XCTAssertEqual(BloopyPhysics.wrap(98 + 205, width: 100), 3, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.wrap(2 - 205, width: 100), 97, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.wrap(-1, width: 100), 99, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.wrap(0, width: 100), 0, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.wrap(100, width: 100), 0, accuracy: 1e-9)
    }

    func testWrapDoesNotReflectVelocity() {
        let right = BloopyPhysics.horizontalStep(
            position: 99,
            velocity: 40,
            input: .none,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 1_000,
            deltaTime: 0.1,
            worldWidth: 100
        )
        XCTAssertGreaterThan(right.velocity, 0)
        XCTAssertEqual(right.velocity, 40, accuracy: 1e-9)

        let left = BloopyPhysics.horizontalStep(
            position: 1,
            velocity: -40,
            input: .none,
            acceleration: 0,
            damping: 0,
            maximumSpeed: 1_000,
            deltaTime: 0.1,
            worldWidth: 100
        )
        XCTAssertLessThan(left.velocity, 0)
        XCTAssertEqual(left.velocity, -40, accuracy: 1e-9)
    }

    func testToroidalDistanceTreatsEdgesAsNeighbors() {
        XCTAssertEqual(BloopyPhysics.toroidalDistance(2, 98, width: 100), 4, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.toroidalDistance(50, 50, width: 100), 0, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.toroidalDelta(from: 98, to: 3, width: 100), 5, accuracy: 1e-9)
        XCTAssertEqual(BloopyPhysics.toroidalDelta(from: 3, to: 98, width: 100), -5, accuracy: 1e-9)
    }
}
