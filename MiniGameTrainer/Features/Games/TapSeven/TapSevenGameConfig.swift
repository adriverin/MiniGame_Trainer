import CoreGraphics
import Foundation
import UIKit

/// Reference-derived TAP AT 7 calibration. Target is canonical 7.000 s, not a frame-matched
/// 6.9998. See Documentation/TAP_SEVEN_GAME_ANALYSIS.md.
struct TapSevenGameConfig: Equatable, Codable {
    var attemptCount = 1
    var targetDuration: TimeInterval = 7.0
    /// PERFECT if `abs(elapsed - target) < perfectThreshold`. Evidence: 0.0002 s was PERFECTO,
    /// 0.0007 s was not. Default 0.5 ms sits in (0.0002, 0.0007].
    var perfectThreshold: TimeInterval = 0.0005
    /// Trainer-specific safety timeout. The recording never shows a no-tap past 7 s.
    var maxAttemptDuration: TimeInterval = 15.0

    var ringDiameterRatio: CGFloat = 0.59
    var ringStrokeRatio: CGFloat = 0.064
    var ringCenterXRatio: CGFloat = 0.50
    /// SpriteKit Y ratio measured upward from the scene bottom.
    var ringCenterYRatio: CGFloat = 0.51
    var instructionYRatio: CGFloat = 0.30
    var timerFontSizeRatio: CGFloat = 0.20
    var instructionFontSizeRatio: CGFloat = 0.048
    var startButtonDiameterRatio: CGFloat = 0.18
    var startButtonYRatio: CGFloat = 0.22

    var requiresTapToStart = true
    var sessionEndHoldDuration: TimeInterval = 0.85
    var maximumSimulationDelta: TimeInterval = 0.25

    var backgroundRed: CGFloat = 12 / 255
    var backgroundGreen: CGFloat = 14 / 255
    var backgroundBlue: CGFloat = 22 / 255
    var trackRed: CGFloat = 48 / 255
    var trackGreen: CGFloat = 52 / 255
    var trackBlue: CGFloat = 62 / 255
    var progressRed: CGFloat = 32 / 255
    var progressGreen: CGFloat = 214 / 255
    var progressBlue: CGFloat = 186 / 255
    var startButtonRed: CGFloat = 72 / 255
    var startButtonGreen: CGFloat = 76 / 255
    var startButtonBlue: CGFloat = 86 / 255

    static let reference = TapSevenGameConfig()

    var resolvedTargetDuration: TimeInterval { max(0.05, targetDuration) }
    var resolvedPerfectThreshold: TimeInterval { max(0, perfectThreshold) }
    var resolvedMaxAttemptDuration: TimeInterval {
        max(resolvedTargetDuration + 0.05, maxAttemptDuration)
    }

    var backgroundColor: UIColor {
        UIColor(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, alpha: 1)
    }

    var trackColor: UIColor {
        UIColor(red: trackRed, green: trackGreen, blue: trackBlue, alpha: 1)
    }

    var progressColor: UIColor {
        UIColor(red: progressRed, green: progressGreen, blue: progressBlue, alpha: 1)
    }

    var startButtonColor: UIColor {
        UIColor(red: startButtonRed, green: startButtonGreen, blue: startButtonBlue, alpha: 1)
    }

    static let scorePresentation = ScorePresentation(
        label: "Timing error",
        unit: "s",
        comparison: .lowerIsBetter,
        storageScale: 1000,
        valueFractionDigits: 2,
        averageFractionDigits: 2
    )
}
