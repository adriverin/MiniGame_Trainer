import CoreGraphics
import Foundation
import UIKit

struct JumpyGameConfig: Equatable {
    var columnCount = 7
    var gestureThreshold: CGFloat = 24
    var hopDuration: TimeInterval = 0.21
    var resultHoldDuration: TimeInterval = 0.38
    var maximumFrameDelta: TimeInterval = 0.10
    var maximumSimulationStep: TimeInterval = 1.0 / 240.0

    var rowHeightRatio: CGFloat = 0.092
    var cameraAnchorYRatio: CGFloat = 0.35
    var horizontalMarginRatio: CGFloat = 0.055
    var playerWidthRatio: CGFloat = 0.092
    var playerHeightInRows: CGFloat = 0.58
    var playerHitboxScale: CGFloat = 0.70
    var vehicleWidthRange: ClosedRange<CGFloat> = 0.14...0.19
    var vehicleHeightInRows: CGFloat = 0.52
    var vehicleHitboxScale: CGFloat = 0.85
    var trafficMargin: CGFloat = 0.24
    var trafficSafetyGap: CGFloat = 0.055

    var lookaheadRows = 16
    var retainedRowsBehind = 2
    var maximumSameDirectionRun = 3
    var randomSeed: UInt64?
    var startingScore = 0

    static let reference = JumpyGameConfig()

    var roadColor: UIColor { UIColor(red: 0.055, green: 0.34, blue: 0.40, alpha: 1) }
    var roadAlternateColor: UIColor { UIColor(red: 0.045, green: 0.30, blue: 0.36, alpha: 1) }
    var safeColor: UIColor { UIColor(red: 0.08, green: 0.56, blue: 0.43, alpha: 1) }
    var safeAlternateColor: UIColor { UIColor(red: 0.07, green: 0.50, blue: 0.39, alpha: 1) }
    var playerColor: UIColor { UIColor(red: 0.49, green: 0.95, blue: 0.18, alpha: 1) }
    var backgroundColor: UIColor { UIColor(red: 0.025, green: 0.19, blue: 0.23, alpha: 1) }
}

struct JumpyDifficulty: Equatable {
    let roadGroupLength: ClosedRange<Int>
    let speed: ClosedRange<CGFloat>
    let gap: ClosedRange<CGFloat>
}

struct JumpyDifficultyModel {
    let config: JumpyGameConfig

    func values(at score: Int) -> JumpyDifficulty {
        let s = max(0, score)
        let group: ClosedRange<Int> = s < 20 ? 2...3 : (s < 60 ? 3...4 : 3...5)
        let speed: ClosedRange<CGFloat>
        if s < 50 {
            speed = interpolate(s, 0, 50, 0.20...0.30, 0.24...0.36)
        } else if s < 100 {
            speed = interpolate(s, 50, 100, 0.24...0.36, 0.28...0.42)
        } else {
            speed = interpolate(min(s, 150), 100, 150, 0.28...0.42, 0.32...0.48)
        }
        let progress = CGFloat(min(s, 150)) / 150
        return JumpyDifficulty(
            roadGroupLength: group,
            speed: speed,
            gap: (0.32 - progress * 0.11)...(0.46 - progress * 0.13)
        )
    }

    private func interpolate(
        _ score: Int,
        _ lowScore: Int,
        _ highScore: Int,
        _ low: ClosedRange<CGFloat>,
        _ high: ClosedRange<CGFloat>
    ) -> ClosedRange<CGFloat> {
        let t = CGFloat(score - lowScore) / CGFloat(max(1, highScore - lowScore))
        let lower = low.lowerBound + (high.lowerBound - low.lowerBound) * t
        let upper = low.upperBound + (high.upperBound - low.upperBound) * t
        return lower...upper
    }
}
