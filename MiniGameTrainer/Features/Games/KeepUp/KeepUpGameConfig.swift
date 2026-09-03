import CoreGraphics
import Foundation
import UIKit

/// Reference-derived ratios and deterministic physics for KEEP UP.
struct KeepUpGameConfig: Equatable, Codable {
    // Geometry
    var platformDiameterRatio: CGFloat = 0.254
    var startingPlatformXRatio: CGFloat = 0.500
    var startingPlatformYRatio: CGFloat = 0.225
    var minimumPlatformCenterXRatio: CGFloat = 0.000
    var maximumPlatformCenterXRatio: CGFloat = 1.000
    var minimumPlatformCenterYRatio: CGFloat = 0.000
    var maximumPlatformCenterYRatio: CGFloat = 0.550
    var ballDiameterRatio: CGFloat = 0.060
    var startingBallXRatio: CGFloat = 0.500
    var startingBallYRatio: CGFloat = 0.600
    var scoreYRatio: CGFloat = 0.730
    var upperLineYRatio: CGFloat = 0.793
    var upperLineHorizontalInsetRatio: CGFloat = 0.080
    var upperLineThicknessWidthRatio: CGFloat = 0.004
    var upperLineOpacity: CGFloat = 0.840

    // Ballistics, expressed relative to the viewport so all iPhones feel alike.
    var startingHorizontalVelocityWidthRatio: CGFloat = 0.240
    var startingVerticalVelocityHeightRatio: CGFloat = -0.350
    var gravityHeightRatio: CGFloat = 1.150
    var bounceImpulseHeightRatio: CGFloat = 1.520
    var ceilingRestitution: CGFloat = 1.000
    var maximumHorizontalBounceSpeedWidthRatio: CGFloat = 1.650
    var impactResponseExponent: CGFloat = 1.000
    var platformHorizontalVelocityTransferCoefficient: CGFloat = 0.000
    var platformVerticalVelocityTransferCoefficient: CGFloat = 0.000

    // Collision and boundaries
    var effectiveCatchRadiusRatio: CGFloat = 0.920
    var landingToleranceWidthRatio: CGFloat = 0.004
    var minimumCatchNormalY: CGFloat = 0.180
    var reflectsAtSideWalls = true
    var reflectsAtCeiling = true
    var failureYRatio: CGFloat = 0.000

    // Trail
    var trailSampleInterval: TimeInterval = 0.050
    var trailLifetime: TimeInterval = 0.880
    var trailMaximumCount = 16
    var trailMinimumScale: CGFloat = 0.220
    var trailMaximumScale: CGFloat = 0.520
    var trailMinimumOpacity: CGFloat = 0.240
    var trailMaximumOpacity: CGFloat = 0.580

    // Scoring and lifecycle
    var pointsPerBounce = 1
    var resultHoldDuration: TimeInterval = 0.420
    var maximumFrameDelta: TimeInterval = 0.100
    var maximumPhysicsStep: TimeInterval = 1.0 / 240.0

    static let reference = KeepUpGameConfig()

    var backgroundColor: UIColor { UIColor(red: 32 / 255, green: 35 / 255, blue: 44 / 255, alpha: 1) }
    var platformColor: UIColor { UIColor(red: 200 / 255, green: 199 / 255, blue: 202 / 255, alpha: 1) }
    var ballColor: UIColor { .white }
    var trailColor: UIColor { UIColor(white: 0.76, alpha: 1) }
}
