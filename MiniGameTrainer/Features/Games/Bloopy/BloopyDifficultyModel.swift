import CoreGraphics
import Foundation

struct BloopyDifficultyModel: Equatable {
    let config: BloopyGameConfig

    func platformWidthRatio(forScore score: Int) -> CGFloat {
        interpolate(score: score, values: config.difficultyWidthRatios, floor: config.minimumPlatformWidthRatio)
    }

    func verticalSpacingRatio(forScore score: Int) -> CGFloat {
        interpolate(score: score, values: config.difficultySpacingRatios, floor: config.initialVerticalSpacingRatio)
    }

    func platformWidth(forScore score: Int, sceneWidth: CGFloat) -> CGFloat {
        max(sceneWidth * config.minimumPlatformWidthRatio, sceneWidth * platformWidthRatio(forScore: score))
    }

    func verticalSpacing(forScore score: Int, sceneHeight: CGFloat) -> CGFloat {
        sceneHeight * verticalSpacingRatio(forScore: score)
    }

    func gravity(sceneHeight: CGFloat) -> CGFloat {
        sceneHeight * config.gravityHeightRatio
    }

    func bounceImpulse(sceneHeight: CGFloat) -> CGFloat {
        sceneHeight * config.bounceImpulseHeightRatio
    }

    func bounceHeight(sceneHeight: CGFloat) -> CGFloat {
        let impulse = bounceImpulse(sceneHeight: sceneHeight)
        let g = gravity(sceneHeight: sceneHeight)
        guard g > 1e-9 else { return 0 }
        return impulse * impulse / (2 * g)
    }

    func horizontalAcceleration(sceneWidth: CGFloat) -> CGFloat {
        sceneWidth * config.horizontalAccelerationWidthRatio
    }

    func maximumHorizontalSpeed(sceneWidth: CGFloat) -> CGFloat {
        sceneWidth * config.maximumHorizontalSpeedWidthRatio
    }

    /// Probability that a newly generated platform is fragile. Always clamped to `0...1`.
    func fragileProbability(forScore score: Int) -> CGFloat {
        let start = max(0, config.fragileStartScore)
        if score < start { return 0 }
        let low = clampedUnit(config.fragileProbabilityAtStart)
        let high = clampedUnit(config.fragileProbabilityHighScore)
        let end = max(start, config.fragileProbabilityRampEndScore)
        if score >= end || end == start { return high }
        let t = CGFloat(score - start) / CGFloat(end - start)
        return clampedUnit(low + t * (high - low))
    }

    func platformKind(forScore score: Int, roll: CGFloat) -> BloopyPlatformKind {
        let probability = fragileProbability(forScore: score)
        return roll < probability ? .fragile : .stable
    }

    private func interpolate(score: Int, values: [CGFloat], floor: CGFloat) -> CGFloat {
        let scores = config.difficultyAnchorScores
        guard !scores.isEmpty, scores.count == values.count else { return floor }
        let clamped = max(0, score)
        if clamped <= scores[0] { return values[0] }
        if clamped >= scores[scores.count - 1] { return values[values.count - 1] }
        for index in 0..<(scores.count - 1) where clamped >= scores[index] && clamped <= scores[index + 1] {
            let span = max(1, scores[index + 1] - scores[index])
            let t = CGFloat(clamped - scores[index]) / CGFloat(span)
            return values[index] + t * (values[index + 1] - values[index])
        }
        return values[values.count - 1]
    }

    private func clampedUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
