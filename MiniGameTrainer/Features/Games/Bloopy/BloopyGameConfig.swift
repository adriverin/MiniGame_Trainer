import CoreGraphics
import Foundation
import UIKit

/// Reference-derived ratios for BLOOPY. Vertical units are scene heights; horizontal units are scene widths.
struct BloopyGameConfig: Equatable, Codable {
    var ballDiameterRatio: CGFloat = 0.054
    var startingBallXRatio: CGFloat = 0.50
    var startingPlatformXRatio: CGFloat = 0.50
    var startingPlatformYRatio: CGFloat = 0.22
    var scoreYRatio: CGFloat = 0.720
    var scoreFontSizeRatio: CGFloat = 0.145

    var gravityHeightRatio: CGFloat = 4.80
    var bounceImpulseHeightRatio: CGFloat = 1.72
    var horizontalAccelerationWidthRatio: CGFloat = 2.40
    var maximumHorizontalSpeedWidthRatio: CGFloat = 1.45
    var horizontalDampingPerSecond: CGFloat = 2.20

    var cameraFollowYRatio: CGFloat = 0.58
    var failureMarginHeightRatio: CGFloat = 0.06
    /// One point per this fraction of scene height of maximum world Y above the start.
    var scoreUnitHeightRatio: CGFloat = 0.038

    var platformHeightRatio: CGFloat = 0.026
    var platformCornerRadiusRatio: CGFloat = 0.22
    var initialPlatformWidthRatio: CGFloat = 0.235
    var minimumPlatformWidthRatio: CGFloat = 0.080
    var initialVerticalSpacingRatio: CGFloat = 0.145
    var maximumVerticalSpacingRatio: CGFloat = 0.280
    var widthJitterRatio: CGFloat = 0.012
    var spacingJitterRatio: CGFloat = 0.018
    var reachabilityMultiplier: CGFloat = 0.88
    var platformHorizontalMarginRatio: CGFloat = 0.01
    var lookaheadPlatformCount: Int = 8
    var recycleBelowHeightRatio: CGFloat = 0

    var difficultyAnchorScores: [Int] = [0, 50, 100, 200, 300, 400, 500, 600]
    var difficultyWidthRatios: [CGFloat] = [0.235, 0.220, 0.200, 0.165, 0.125, 0.100, 0.088, 0.080]
    var difficultySpacingRatios: [CGFloat] = [0.145, 0.165, 0.200, 0.250, 0.270, 0.280, 0.280, 0.280]

    var trailSampleInterval: TimeInterval = 0.045
    var trailLifetime: TimeInterval = 0.70
    var trailMaximumCount = 14
    var trailMinimumScale: CGFloat = 0.18
    var trailMaximumScale: CGFloat = 0.55
    var trailMinimumOpacity: CGFloat = 0.12
    var trailMaximumOpacity: CGFloat = 0.95

    var resultHoldDuration: TimeInterval = 0.42
    var maximumFrameDelta: TimeInterval = 0.100
    var maximumPhysicsStep: TimeInterval = 1.0 / 240.0
    var randomSeed: UInt64? = nil

    static let reference = BloopyGameConfig()

    static func deterministic(seed: UInt64 = 17_602) -> BloopyGameConfig {
        var config = BloopyGameConfig()
        config.randomSeed = seed
        return config
    }

    var backgroundColor: UIColor { UIColor(red: 10 / 255, green: 78 / 255, blue: 96 / 255, alpha: 1) }
    var platformColor: UIColor { UIColor(red: 245 / 255, green: 197 / 255, blue: 160 / 255, alpha: 1) }
    var usedPlatformColor: UIColor { UIColor(red: 214 / 255, green: 72 / 255, blue: 64 / 255, alpha: 1) }
    var ballColor: UIColor { .white }
    var trailColor: UIColor { .white }
}
