import Foundation

struct ReactRandomizer {
    private let config: ReactGameConfig
    private var generator: AnyRandomNumberGenerator

    init(config: ReactGameConfig) {
        self.config = config
        generator = .seeded(config.randomSeed)
    }

    mutating func nextDelay() -> TimeInterval {
        let lower = min(config.minimumStimulusDelay, config.maximumStimulusDelay)
        let upper = max(config.minimumStimulusDelay, config.maximumStimulusDelay)
        guard upper > lower else { return max(0, lower) }
        return Double.random(in: max(0, lower)...max(0, upper), using: &generator)
    }

    mutating func nextTarget(after previous: Int?) -> Int {
        guard config.preventImmediateRepeat, let previous, (0..<9).contains(previous) else {
            return Int.random(in: 0..<9, using: &generator)
        }
        var candidate = Int.random(in: 0..<8, using: &generator)
        if candidate >= previous { candidate += 1 }
        return candidate
    }
}
