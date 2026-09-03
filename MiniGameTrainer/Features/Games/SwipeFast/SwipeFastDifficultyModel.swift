import Foundation

/// Piecewise-linear per-box allowed time measured from bar urgency in the 71-point recording.
/// Capped at the last calibrated anchor so score 200 cannot drive time to zero.
struct SwipeFastDifficultyModel: Equatable {
    let config: SwipeFastGameConfig

    func allowedTime(forScore score: Int) -> TimeInterval {
        let scores = config.difficultyAnchorScores
        let durations = config.difficultyAnchorDurations
        guard !scores.isEmpty, scores.count == durations.count else {
            return max(config.minimumAllowedTime, 1)
        }
        let clamped = max(0, score)
        if clamped <= scores[0] { return max(config.minimumAllowedTime, durations[0]) }
        if clamped >= scores[scores.count - 1] {
            return max(config.minimumAllowedTime, durations[scores.count - 1])
        }
        for index in 0..<(scores.count - 1) {
            let lower = scores[index]
            let upper = scores[index + 1]
            if clamped >= lower, clamped <= upper {
                let span = max(1, upper - lower)
                let t = Double(clamped - lower) / Double(span)
                let value = durations[index] + t * (durations[index + 1] - durations[index])
                return max(config.minimumAllowedTime, value)
            }
        }
        return max(config.minimumAllowedTime, durations[durations.count - 1])
    }
}
