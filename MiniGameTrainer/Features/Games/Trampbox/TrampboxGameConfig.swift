import CoreGraphics
import Foundation

/// Central calibration surface for Trampbox. Ratios are relative to the full SpriteKit scene.
struct TrampboxGameConfig: Equatable, Codable {
    // Ball
    var ballRadiusRatio: CGFloat = 0.037
    var startingXRatio: CGFloat = 0.50

    // Relative drag control
    var horizontalControlSensitivity: CGFloat = 1.0
    var maximumHorizontalSpeedRatio: CGFloat = 1.35

    // Deterministic bounce
    var initialBounceDuration: TimeInterval = 0.68
    var minimumBounceDuration: TimeInterval = 0.30
    var bounceDurationReductionPerPoint: TimeInterval = 0.0033
    var bounceHeightRatio: CGFloat = 0.21

    // Platforms
    var initialPlatformWidthRatio: CGFloat = 0.25
    var minimumPlatformWidthRatio: CGFloat = 0.11
    var platformWidthReductionPerPoint: CGFloat = 0.0008
    /// Visual projection is independent of the logical landing width.
    var farTopDepthToWidthRatio: CGFloat = 0.18
    var nearTopDepthToWidthRatio: CGFloat = 0.54
    var farSideDepthToWidthRatio: CGFloat = 0.055
    var nearSideDepthToWidthRatio: CGFloat = 0.14

    // Path generation
    var minimumHorizontalOffsetRatio: CGFloat = 0.08
    var maximumHorizontalOffsetRatio: CGFloat = 0.46
    var reachabilityMultiplier: CGFloat = 0.82
    var visiblePlatformCount: Int = 8
    var randomSeed: UInt64? = nil

    // Perspective / layout (screen-down coordinates)
    var horizonYRatio: CGFloat = 0.23
    var landingYRatio: CGFloat = 0.70
    var platformSpacingRatio: CGFloat = 0.15
    var farScale: CGFloat = 0.40
    var nearScale: CGFloat = 1.0
    var perspectiveExponent: CGFloat = 0.90
    var depthProjectionExponent: CGFloat = 1.05
    var approachRotationDegrees: CGFloat = 3.0

    // Rendering-only lifecycle after a platform has left gameplay.
    var departureDurationMultiplier: CGFloat = 1.05
    var departureDownwardDistanceRatio: CGFloat = 0.42
    var departureLateralDriftRatio: CGFloat = 0.18
    var departureRotationDegrees: CGFloat = 105
    var foregroundScaleMultiplier: CGFloat = 1.75

    // Rules
    var pointsPerLanding: Int = 1
    var landingRule: TrampboxLandingRule = .ballOverlap
    /// Multiplier applied to the ball radius when evaluating horizontal overlap.
    var landingTolerance: CGFloat = 0.82
    var failureYRatio: CGFloat = 0.94
    var fallInitialSpeedRatio: CGFloat = 0.20
    var fallGravityRatio: CGFloat = 2.4

    // Flow / visual timing
    var countdownSteps: Int = 3
    var countdownStepDuration: TimeInterval = 0.55
    var gameOverHoldDuration: TimeInterval = 0.55
    var maximumFrameDelta: TimeInterval = 1.0 / 20.0
    var scoreYRatio: CGFloat = 0.235
    var scoreFontSizeRatio: CGFloat = 0.072

    static let reference = TrampboxGameConfig()

    static func deterministic(seed: UInt64 = 17_601) -> TrampboxGameConfig {
        var config = TrampboxGameConfig()
        config.randomSeed = seed
        return config
    }
}

enum TrampboxLandingRule: String, Equatable, Codable, CaseIterable {
    case centerInsidePlatform
    case ballOverlap

    var displayName: String {
        switch self {
        case .centerInsidePlatform: "Ball center"
        case .ballOverlap: "Ball overlap"
        }
    }
}
