import CoreGraphics
import Foundation
import UIKit

struct JumpyGameConfig: Equatable {
    var columnCount = 7
    var gestureThreshold: CGFloat = 24
    var hopDuration: TimeInterval = 0.18
    var pendingMoveCapacity = 4
    var resultHoldDuration: TimeInterval = 0.38
    var maximumFrameDelta: TimeInterval = 0.10
    var maximumSimulationStep: TimeInterval = 1.0 / 240.0

    var rowHeightRatio: CGFloat = 0.060
    var cameraAnchorYRatio: CGFloat = 0.49
    var projectionDepthFalloff: CGFloat = 0.055
    var minimumDepthScale: CGFloat = 0.58
    var maximumDepthScale: CGFloat = 1.24
    var horizontalDepthInfluence: CGFloat = 0.18
    var horizontalMarginRatio: CGFloat = 0.055
    var playerWidthRatio: CGFloat = 0.100
    var playerHeightInRows: CGFloat = 0.72
    var playerHitboxScale: CGFloat = 0.70
    var vehicleWidthRange: ClosedRange<CGFloat> = 0.13...0.16
    var vehicleHeightInRows: CGFloat = 0.68
    var vehicleHitboxScale: CGFloat = 0.85
    var trafficMargin: CGFloat = 0.32
    var trafficSafetyGap: CGFloat = 0.055
    var pairedSafeRowChanceDenominator = 8

    var lookaheadRows = 16
    var retainedRowsBehind = 2
    var maximumSameDirectionRun = 3
    var randomSeed: UInt64?
    var startingScore = 0

    static let reference = JumpyGameConfig()

    var roadColor: UIColor { UIColor(red: 0.125, green: 0.56, blue: 0.675, alpha: 1) }
    var roadAlternateColor: UIColor { roadColor }
    var safeColor: UIColor { UIColor(red: 0.208, green: 0.71, blue: 0.604, alpha: 1) }
    var safeAlternateColor: UIColor { safeColor }
    var safeDepthColor: UIColor { UIColor(red: 0.12, green: 0.51, blue: 0.45, alpha: 1) }
    var playerColor: UIColor { UIColor(red: 0.49, green: 0.95, blue: 0.18, alpha: 1) }
    var backgroundColor: UIColor { roadColor }
}

struct JumpyDifficulty: Equatable {
    let roadGroupLength: ClosedRange<Int>
    let speed: ClosedRange<CGFloat>
    let carsPerGroup: ClosedRange<Int>
    let groupOpening: ClosedRange<CGFloat>
    let internalGap: ClosedRange<CGFloat>
}

struct JumpyDifficultyModel {
    let config: JumpyGameConfig

    func values(at score: Int) -> JumpyDifficulty {
        let s = max(0, score)
        let group: ClosedRange<Int>
        let cars: ClosedRange<Int>
        let opening: ClosedRange<CGFloat>
        switch s {
        case ..<20:
            group = 2...3; cars = 1...1; opening = 0.42...0.60
        case ..<40:
            group = 3...5; cars = 1...2; opening = 0.34...0.50
        case ..<80:
            group = 5...8; cars = 1...3; opening = 0.27...0.40
        case ..<120:
            group = 5...8; cars = 2...3; opening = 0.23...0.35
        default:
            group = 5...8; cars = 2...4; opening = 0.21...0.31
        }
        let speed: ClosedRange<CGFloat>
        if s < 50 {
            speed = interpolate(s, 0, 50, 0.18...0.30, 0.20...0.36)
        } else {
            speed = interpolate(min(s, 100), 50, 100, 0.20...0.36, 0.24...0.42)
        }
        return JumpyDifficulty(
            roadGroupLength: group,
            speed: speed,
            carsPerGroup: cars,
            groupOpening: opening,
            internalGap: 0.025...0.055
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
