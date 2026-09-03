import XCTest
@testable import MiniGameTrainer

final class KeepUpPhysicsTests: XCTestCase {
    func testVerticalStepUsesExactConstantAcceleration() {
        let result = KeepUpPhysics.verticalStep(position: 100, velocity: 40, gravity: 20, deltaTime: 0.5)
        XCTAssertEqual(result.position, 117.5, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, 30, accuracy: 1e-9)
        XCTAssertFalse(result.hitUpperBound)
    }

    func testCeilingReflectionPreservesOvershootDistance() {
        let result = KeepUpPhysics.verticalStep(
            position: 98,
            velocity: 5,
            gravity: 0,
            deltaTime: 1,
            upperBound: 100,
            restitution: 1
        )
        XCTAssertEqual(result.position, 97, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, -5, accuracy: 1e-9)
        XCTAssertTrue(result.hitUpperBound)
    }

    func testCeilingReflectionDoesNotDiscardOvershootByClamping() {
        let clamped = KeepUpPhysics.verticalStep(
            position: 98,
            velocity: 5,
            gravity: 0,
            deltaTime: 1,
            upperBound: 100,
            restitution: 1
        )
        XCTAssertNotEqual(clamped.position, 100, accuracy: 1e-9)
        XCTAssertEqual(clamped.position, 100 - 3, accuracy: 1e-9)
    }

    func testLargeStepThroughCeilingRemainsFiniteAndReflected() {
        let result = KeepUpPhysics.verticalStep(
            position: 50,
            velocity: 400,
            gravity: 20,
            deltaTime: 3,
            upperBound: 100,
            restitution: 1
        )
        XCTAssertTrue(result.position.isFinite && result.velocity.isFinite)
        XCTAssertLessThanOrEqual(result.position, 100 + 1e-9)
        XCTAssertTrue(result.hitUpperBound)
        XCTAssertLessThan(result.velocity, 0)
    }

    func testCeilingRestitutionOneIsElastic() {
        let result = KeepUpPhysics.verticalStep(
            position: 90,
            velocity: 50,
            gravity: 0,
            deltaTime: 0.6,
            upperBound: 100,
            restitution: 1
        )
        XCTAssertEqual(result.position, 80, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, -50, accuracy: 1e-9)
        XCTAssertTrue(result.hitUpperBound)
    }

    func testHorizontalStepWithoutWallsDoesNotClamp() {
        let result = KeepUpPhysics.horizontalStep(position: 90, velocity: 40, deltaTime: 0.5, lowerBound: 0, upperBound: 100, reflects: false)
        XCTAssertEqual(result.position, 110, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, 40, accuracy: 1e-9)
    }

    func testSideWallReflectionPreservesOvershoot() {
        let result = KeepUpPhysics.horizontalStep(position: 90, velocity: 40, deltaTime: 0.5, lowerBound: 0, upperBound: 100, reflects: true)
        XCTAssertEqual(result.position, 90, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, -40, accuracy: 1e-9)
    }

    func testSideWallReflectionHandlesMultipleCrossings() {
        let result = KeepUpPhysics.horizontalStep(position: 25, velocity: 100, deltaTime: 3, lowerBound: 0, upperBound: 100, reflects: true)
        XCTAssertEqual(result.position, 75, accuracy: 1e-9)
        XCTAssertEqual(result.velocity, -100, accuracy: 1e-9)
    }

    func testCenteredImpactProducesVerticalBounce() {
        let result = KeepUpPhysics.outgoingHorizontalVelocity(
            normalizedImpactOffset: 0,
            maximumSpeed: 500,
            exponent: 1,
            platformVelocity: 100,
            transferCoefficient: 0
        )
        XCTAssertEqual(result, 0, accuracy: 1e-9)
    }

    func testEqualOffsetsProduceSymmetricVelocities() {
        let left = KeepUpPhysics.outgoingHorizontalVelocity(normalizedImpactOffset: -0.4, maximumSpeed: 500, exponent: 1, platformVelocity: 0, transferCoefficient: 0)
        let right = KeepUpPhysics.outgoingHorizontalVelocity(normalizedImpactOffset: 0.4, maximumSpeed: 500, exponent: 1, platformVelocity: 0, transferCoefficient: 0)
        XCTAssertEqual(left, -200, accuracy: 1e-9)
        XCTAssertEqual(right, 200, accuracy: 1e-9)
    }

    func testOutgoingVelocityIsClampedAfterPlatformTransfer() {
        let result = KeepUpPhysics.outgoingHorizontalVelocity(normalizedImpactOffset: 1, maximumSpeed: 500, exponent: 1, platformVelocity: 1_000, transferCoefficient: 1)
        XCTAssertEqual(result, 500, accuracy: 1e-9)
    }
}
