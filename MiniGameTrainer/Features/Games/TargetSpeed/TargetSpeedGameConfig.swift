import CoreGraphics
import Foundation
import UIKit

/// Reference-derived TARGET SPEED calibration from the 731-point recording.
/// See Documentation/TARGET_SPEED_GAME_ANALYSIS.md.
struct TargetSpeedGameConfig: Equatable, Codable {
    var startingLives = 3
    var pointsPerHit = 1

    var scoreXRatio: CGFloat = 0.50
    var scoreYRatio: CGFloat = 0.745
    var scoreFontRatio: CGFloat = 0.155
    var livesXRatio: CGFloat = 0.155
    var livesYRatio: CGFloat = 0.745
    var livesSpacingRatio: CGFloat = 0.058
    var heartSizeRatio: CGFloat = 0.042

    /// Playable field in scene-normalized coordinates (SpriteKit Y-up).
    var playMinXRatio: CGFloat = 0.08
    var playMaxXRatio: CGFloat = 0.92
    var playMinYRatio: CGFloat = 0.10
    var playMaxYRatio: CGFloat = 0.675

    /// Diameter / scene width. Clustered at ~0.193 in the source, with a smaller tail.
    var largeDiameterRange: [CGFloat] = [0.175, 0.228]
    var mediumDiameterRange: [CGFloat] = [0.090, 0.155]
    var smallDiameterRange: [CGFloat] = [0.045, 0.085]
    var tinyDiameterRange: [CGFloat] = [0.022, 0.040]

    var difficultyAnchorScores: [Int] = [0, 50, 100, 200, 300, 400, 500, 700]
    var difficultyAnchorLifetimes: [TimeInterval] = [1.40, 1.30, 1.25, 1.20, 1.18, 1.15, 1.12, 1.10]
    var difficultyAnchorSpawnIntervals: [TimeInterval] = [0.50, 0.36, 0.28, 0.24, 0.22, 0.21, 0.205, 0.20]
    var difficultyAnchorMaxActive: [Int] = [1, 2, 2, 3, 3, 4, 4, 5]
    var minimumLifetime: TimeInterval = 1.10
    var minimumSpawnInterval: TimeInterval = 0.20
    var maximumActiveTargets = 5

    /// Large / medium / small / tiny weights per difficulty anchor.
    var sizeWeightAnchors: [[Double]] = [
        [0.90, 0.10, 0.00, 0.00],
        [0.78, 0.17, 0.05, 0.00],
        [0.70, 0.18, 0.10, 0.02],
        [0.64, 0.18, 0.14, 0.04],
        [0.60, 0.20, 0.15, 0.05],
        [0.56, 0.20, 0.16, 0.08],
        [0.54, 0.20, 0.17, 0.09],
        [0.52, 0.20, 0.18, 0.10],
    ]

    var firstTargetDelay: TimeInterval = 0.35
    var instructionOverlayDuration: TimeInterval = 1.15
    var fadeWarningFraction: Double = 0.22
    var missFadeDuration: TimeInterval = 0.20
    var hitPulseDuration: TimeInterval = 0.08
    var sessionEndHoldDuration: TimeInterval = 0.35
    var maximumSimulationDelta: TimeInterval = 0.25
    var spawnPlacementAttempts = 24
    var overlapPaddingRatio: CGFloat = 0.012
    var minimumHitRadiusRatio: CGFloat = 0.028
    var ringLineWidthRatio: CGFloat = 0.006
    var requiresTapToStart = false
    var generatorSeed: UInt64 = 1

    var greenRemainingThreshold: Double = 0.55
    var yellowRemainingThreshold: Double = 0.32
    var orangeRemainingThreshold: Double = 0.16

    var backgroundRed: CGFloat = 26 / 255
    var backgroundGreen: CGFloat = 31 / 255
    var backgroundBlue: CGFloat = 40 / 255
    var outerRed: CGFloat = 0.92
    var outerGreen: CGFloat = 0.14
    var outerBlue: CGFloat = 0.16
    var ringWhite: CGFloat = 0.96
    var heartRed: CGFloat = 0.92
    var heartGreen: CGFloat = 0.16
    var heartBlue: CGFloat = 0.22
    var timerGreenR: CGFloat = 0.35
    var timerGreenG: CGFloat = 0.92
    var timerGreenB: CGFloat = 0.38
    var timerYellowR: CGFloat = 1
    var timerYellowG: CGFloat = 0.84
    var timerYellowB: CGFloat = 0.20
    var timerOrangeR: CGFloat = 1
    var timerOrangeG: CGFloat = 0.55
    var timerOrangeB: CGFloat = 0.16
    var timerRedR: CGFloat = 1
    var timerRedG: CGFloat = 0.28
    var timerRedB: CGFloat = 0.28

    static let reference = TargetSpeedGameConfig()

    var backgroundColor: UIColor {
        UIColor(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, alpha: 1)
    }

    var targetOuterColor: UIColor {
        UIColor(red: outerRed, green: outerGreen, blue: outerBlue, alpha: 1)
    }

    var targetRingColor: UIColor {
        UIColor(white: ringWhite, alpha: 1)
    }

    var heartColor: UIColor {
        UIColor(red: heartRed, green: heartGreen, blue: heartBlue, alpha: 1)
    }

    func ringColor(for stage: TargetSpeedRingStage) -> UIColor {
        switch stage {
        case .green:
            UIColor(red: timerGreenR, green: timerGreenG, blue: timerGreenB, alpha: 1)
        case .yellow:
            UIColor(red: timerYellowR, green: timerYellowG, blue: timerYellowB, alpha: 1)
        case .orange:
            UIColor(red: timerOrangeR, green: timerOrangeG, blue: timerOrangeB, alpha: 1)
        case .red:
            UIColor(red: timerRedR, green: timerRedG, blue: timerRedB, alpha: 1)
        }
    }

    func ringStage(remainingFraction: Double) -> TargetSpeedRingStage {
        let fraction = min(max(remainingFraction, 0), 1)
        if fraction > greenRemainingThreshold { return .green }
        if fraction > yellowRemainingThreshold { return .yellow }
        if fraction > orangeRemainingThreshold { return .orange }
        return .red
    }

    func diameterRange(for tier: TargetSpeedSizeTier) -> ClosedRange<CGFloat> {
        let pair: [CGFloat]
        switch tier {
        case .large: pair = largeDiameterRange
        case .medium: pair = mediumDiameterRange
        case .small: pair = smallDiameterRange
        case .tiny: pair = tinyDiameterRange
        }
        let lo = pair.first ?? 0.05
        let hi = pair.count > 1 ? pair[1] : lo
        return min(lo, hi)...max(lo, hi)
    }
}
