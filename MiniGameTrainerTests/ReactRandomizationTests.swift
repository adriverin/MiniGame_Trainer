import XCTest
@testable import MiniGameTrainer

final class ReactRandomizationTests: XCTestCase {
    func testGeneratedDelaysStayWithinInclusiveBoundsAndVary() {
        var config = ReactGameConfig.deterministic(seed: 7)
        config.minimumStimulusDelay = 1
        config.maximumStimulusDelay = 3.5
        var randomizer = ReactRandomizer(config: config)
        let delays = (0..<200).map { _ in randomizer.nextDelay() }
        XCTAssertTrue(delays.allSatisfy { $0 >= 1 && $0 <= 3.5 })
        XCTAssertGreaterThan(Set(delays.map { Int($0 * 1_000_000) }).count, 1)
    }

    func testFixedSeedReproducesDelayAndTargetSequence() {
        let config = ReactGameConfig.deterministic(seed: 99)
        var first = ReactRandomizer(config: config)
        var second = ReactRandomizer(config: config)
        for _ in 0..<100 {
            XCTAssertEqual(first.nextDelay(), second.nextDelay())
            XCTAssertEqual(first.nextTarget(after: nil), second.nextTarget(after: nil))
        }
    }

    func testTargetIndexAlwaysFallsInGridAndAllPositionsAreReachable() {
        var randomizer = ReactRandomizer(config: .deterministic(seed: 123))
        let targets = (0..<10_000).map { _ in randomizer.nextTarget(after: nil) }
        XCTAssertTrue(targets.allSatisfy { (0..<9).contains($0) })
        XCTAssertEqual(Set(targets), Set(0..<9))
    }

    func testRepeatPreventionNeverSelectsPreviousPosition() {
        var config = ReactGameConfig.deterministic(seed: 5)
        config.preventImmediateRepeat = true
        var randomizer = ReactRandomizer(config: config)
        var previous: Int? = nil
        for _ in 0..<2_000 {
            let target = randomizer.nextTarget(after: previous)
            XCTAssertNotEqual(target, previous)
            previous = target
        }
    }
}
