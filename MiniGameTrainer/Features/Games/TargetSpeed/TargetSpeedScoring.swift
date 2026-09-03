import CoreGraphics
import Foundation

/// Evidence-backed scoring: every successful tap awards a constant integer.
/// 717 of 730 OCR score transitions in the 731-point recording were +1; remaining
/// non-+1 samples were OCR glitches or two hits inside one 100 ms bin.
enum TargetSpeedScoring {
    static func points(forHit config: TargetSpeedGameConfig = .reference) -> Int {
        max(1, config.pointsPerHit)
    }

    static func points(
        diameterRatio: CGFloat,
        reactionTime: TimeInterval,
        config: TargetSpeedGameConfig = .reference
    ) -> Int {
        _ = diameterRatio
        _ = reactionTime
        return points(forHit: config)
    }
}
