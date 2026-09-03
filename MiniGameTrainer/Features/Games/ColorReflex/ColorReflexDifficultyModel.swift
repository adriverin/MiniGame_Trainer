import Foundation

/// Wait-delay model. Reference delays do not shorten or widen with score, so
/// this is a stationary uniform draw — not a difficulty ramp.
struct ColorReflexDifficultyModel: Equatable {
    let minWait: TimeInterval
    let maxWait: TimeInterval

    init(config: ColorReflexGameConfig) {
        minWait = min(config.minWait, config.maxWait)
        maxWait = max(config.minWait, config.maxWait)
    }

    func waitDelay(rng: inout AnyRandomNumberGenerator) -> TimeInterval {
        let lower = max(0, minWait)
        let upper = max(lower, maxWait)
        guard upper > lower else { return lower }
        return Double.random(in: lower...upper, using: &rng)
    }
}
