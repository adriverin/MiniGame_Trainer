import CoreGraphics
import Foundation

/// Piecewise-linear KEEP UP physics time scale measured from the original score-41 recording.
///
/// Trajectories stay geometrically similar: velocity scales with `s`, acceleration with `s²`.
/// Horizontal bounce response uses the same `s` so late-game wall travel keeps up with vertical timing.
struct KeepUpDifficultyModel: Equatable {
    let config: KeepUpGameConfig

    /// Time-scale multiplier `s(score)`. Capped at the last calibrated anchor (score 40).
    func physicsSpeedScale(forScore score: Int) -> CGFloat {
        let scores = config.difficultyAnchorScores
        let scales = config.difficultyAnchorScales
        guard !scores.isEmpty, scores.count == scales.count else { return 1 }
        let clamped = max(0, score)
        if clamped <= scores[0] { return scales[0] }
        if clamped >= scores[scores.count - 1] { return scales[scales.count - 1] }
        for index in 0..<(scores.count - 1) {
            let lower = scores[index]
            let upper = scores[index + 1]
            if clamped >= lower, clamped <= upper {
                let span = max(1, upper - lower)
                let t = CGFloat(clamped - lower) / CGFloat(span)
                return scales[index] + t * (scales[index + 1] - scales[index])
            }
        }
        return scales[scales.count - 1]
    }

    func gravity(forScore score: Int, sceneHeight: CGFloat) -> CGFloat {
        let scale = physicsSpeedScale(forScore: score)
        return sceneHeight * config.gravityHeightRatio * scale * scale
    }

    func bounceImpulse(forScore score: Int, sceneHeight: CGFloat) -> CGFloat {
        sceneHeight * config.bounceImpulseHeightRatio * physicsSpeedScale(forScore: score)
    }

    func maximumHorizontalBounceSpeed(forScore score: Int, sceneWidth: CGFloat) -> CGFloat {
        sceneWidth * config.maximumHorizontalBounceSpeedWidthRatio * physicsSpeedScale(forScore: score)
    }

    func startingHorizontalVelocity(forScore score: Int, sceneWidth: CGFloat) -> CGFloat {
        sceneWidth * config.startingHorizontalVelocityWidthRatio * physicsSpeedScale(forScore: score)
    }

    func startingVerticalVelocity(forScore score: Int, sceneHeight: CGFloat) -> CGFloat {
        sceneHeight * config.startingVerticalVelocityHeightRatio * physicsSpeedScale(forScore: score)
    }
}
