import CoreGraphics
import Foundation

struct TrampboxDifficultyModel {
    let config: TrampboxGameConfig

    func bounceDuration(for score: Int) -> TimeInterval {
        max(
            config.minimumBounceDuration,
            config.initialBounceDuration - Double(max(0, score)) * config.bounceDurationReductionPerPoint
        )
    }

    func platformWidthRatio(for score: Int) -> CGFloat {
        max(
            config.minimumPlatformWidthRatio,
            config.initialPlatformWidthRatio - CGFloat(max(0, score)) * config.platformWidthReductionPerPoint
        )
    }
}
