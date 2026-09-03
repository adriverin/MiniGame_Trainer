import CoreGraphics
import Foundation
import UIKit

/// Reference-derived COLOR REFLEX calibration.
/// Session length comes from first gameplay frame → results collapse (41.40 s),
/// not the intro `~27s` chip. Wait bounds come from the 16 successful triggers.
/// See Documentation/COLOR_REFLEX_GAME_ANALYSIS.md.
struct ColorReflexGameConfig: Equatable, Codable {
    var sessionDuration: TimeInterval = 41.0
    var minWait: TimeInterval = 0.60
    var maxWait: TimeInterval = 4.00
    /// Inferred: no false start exists in the recording. Intro copy says a premature
    /// tap costs time. Midpoint of the 1.0...2.0 s suggested range.
    var prematurePenalty: TimeInterval = 1.50
    var prematureResetsWait = true

    var scoreXRatio: CGFloat = 0.50
    var scoreYRatio: CGFloat = 0.78
    var scoreFontRatio: CGFloat = 0.155
    var promptYRatio: CGFloat = 0.46
    var promptFontRatio: CGFloat = 0.088
    var reactionYRatio: CGFloat = 0.28
    var reactionFontRatio: CGFloat = 0.038
    var reactionOpacity: CGFloat = 0.55

    var barWidthRatio: CGFloat = 0.78
    var barHeightRatio: CGFloat = 0.012
    var barCenterXRatio: CGFloat = 0.50
    /// SpriteKit Y ratio measured upward from the scene bottom.
    var barCenterYRatio: CGFloat = 0.935
    var barCornerRadiusRatio: CGFloat = 0.50
    var barStrokeWidthRatio: CGFloat = 0.0024

    var greenRemainingThreshold: Double = 0.42
    var orangeRemainingThreshold: Double = 0.25

    var requiresTapToStart = false
    var sessionEndHoldDuration: TimeInterval = 0.35
    var maximumSimulationDelta: TimeInterval = 0.25
    var generatorSeed: UInt64 = 1

    var barGreenRed: CGFloat = 72 / 255
    var barGreenGreen: CGFloat = 214 / 255
    var barGreenBlue: CGFloat = 82 / 255
    var barOrangeRed: CGFloat = 1
    var barOrangeGreen: CGFloat = 176 / 255
    var barOrangeBlue: CGFloat = 32 / 255
    var barRedRed: CGFloat = 235 / 255
    var barRedGreen: CGFloat = 64 / 255
    var barRedBlue: CGFloat = 54 / 255
    var barTrackOpacity: CGFloat = 0.34
    var barStrokeRed: CGFloat = 1
    var barStrokeGreen: CGFloat = 1
    var barStrokeBlue: CGFloat = 1

    static let reference = ColorReflexGameConfig()

    static func deterministic(seed: UInt64 = 1) -> ColorReflexGameConfig {
        var config = ColorReflexGameConfig()
        config.generatorSeed = seed
        return config
    }

    var resolvedSessionDuration: TimeInterval { max(0.05, sessionDuration) }
    var resolvedPrematurePenalty: TimeInterval { max(0, prematurePenalty) }

    func barStage(remainingFraction: Double) -> ColorReflexBarStage {
        let fraction = min(max(remainingFraction, 0), 1)
        if fraction > greenRemainingThreshold { return .green }
        if fraction > orangeRemainingThreshold { return .orange }
        return .red
    }

    func barFillColor(for stage: ColorReflexBarStage) -> UIColor {
        switch stage {
        case .green:
            UIColor(red: barGreenRed, green: barGreenGreen, blue: barGreenBlue, alpha: 1)
        case .orange:
            UIColor(red: barOrangeRed, green: barOrangeGreen, blue: barOrangeBlue, alpha: 1)
        case .red:
            UIColor(red: barRedRed, green: barRedGreen, blue: barRedBlue, alpha: 1)
        }
    }

    var barStrokeColor: UIColor {
        UIColor(red: barStrokeRed, green: barStrokeGreen, blue: barStrokeBlue, alpha: 1)
    }
}
