import XCTest
@testable import MiniGameTrainer

final class DirectionsSequenceTests: XCTestCase {
    func testGeneratedCountMatchesRequiredLength() {
        var rng = SeededRandomNumberGenerator(seed: 9)
        let generator = DirectionsSequenceGenerator(config: .reference)
        let sequence = generator.generate(length: 7, rng: &rng)
        XCTAssertEqual(sequence.count, 7)
        XCTAssertTrue(sequence.allSatisfy { Direction.allCases.contains($0) })
    }

    func testSeedIsDeterministic() {
        var first = SeededRandomNumberGenerator(seed: 123)
        var second = SeededRandomNumberGenerator(seed: 123)
        let generator = DirectionsSequenceGenerator(config: .reference)
        XCTAssertEqual(generator.generate(length: 12, rng: &first), generator.generate(length: 12, rng: &second))
    }

    func testDifferentSeedsDiverge() {
        var first = SeededRandomNumberGenerator(seed: 1)
        var second = SeededRandomNumberGenerator(seed: 2)
        let generator = DirectionsSequenceGenerator(config: .reference)
        XCTAssertNotEqual(generator.generate(length: 16, rng: &first), generator.generate(length: 16, rng: &second))
    }

    func testConsecutiveRepeatsOccurWithDefaultGenerator() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        let generator = DirectionsSequenceGenerator(config: .reference)
        var sawRepeat = false
        for _ in 0..<40 {
            let sequence = generator.generate(length: 14, rng: &rng)
            if zip(sequence, sequence.dropFirst()).contains(where: { $0 == $1 }) {
                sawRepeat = true
                break
            }
        }
        XCTAssertTrue(sawRepeat, "Reference allows consecutive repeats; the seeded generator must be able to emit them")
    }

    func testRepeatRestrictionIsHonouredWhenConfigured() {
        var config = DirectionsGameConfig.reference
        config.allowsConsecutiveRepeats = false
        var rng = SeededRandomNumberGenerator(seed: 1)
        let generator = DirectionsSequenceGenerator(config: config)
        for _ in 0..<20 {
            let sequence = generator.generate(length: 12, rng: &rng)
            XCTAssertFalse(zip(sequence, sequence.dropFirst()).contains(where: { $0 == $1 }))
        }
    }

    func testRoundsAreIndependentNotSimonStyle() {
        var config = DirectionsGameConfig.reference
        config.roundSuccessHoldDuration = 0
        config.generatorSeed = 99
        let logic = DirectionsGameLogic(config: config, seed: 99)
        logic.skipPresentation = true
        logic.start(at: 0)
        let first = logic.target
        for direction in first {
            _ = logic.handleInput(direction, at: 1)
        }
        logic.update(at: 1)
        let second = logic.target
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(second.count, 4)
        XCTAssertNotEqual(Array(second.prefix(3)), first, "Each round generates a new sequence")
    }

    func testForcedSequenceIsUsedWhenProvided() {
        let logic = DirectionsGameLogic(config: .reference, seed: 1)
        logic.skipPresentation = true
        logic.forcedSequence = [.left, .left, .left]
        logic.start(at: 0)
        XCTAssertEqual(logic.target, [.left, .left, .left])
    }
}
