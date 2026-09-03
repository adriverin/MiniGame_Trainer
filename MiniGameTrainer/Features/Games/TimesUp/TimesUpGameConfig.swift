import CoreGraphics
import Foundation
import UIKit

/// Reference-derived TIME'S UP calibration. Durations come from linear drain-to-empty fits on
/// the recording, not from the intro's "~22s" chip. See Documentation/TIMES_UP_GAME_ANALYSIS.md.
struct TimesUpGameConfig: Equatable, Codable {
    var levelCount = 3
    var targetDurations: [TimeInterval] = [10, 10, 10]
    var visibilityFraction: Double = 0.5

    var barWidthRatio: CGFloat = 0.26
    var barHeightRatio: CGFloat = 0.40
    var barCenterXRatio: CGFloat = 0.50
    /// SpriteKit Y ratio measured upward from the scene bottom.
    var barCenterYRatio: CGFloat = 0.42
    var cornerRadiusRatio: CGFloat = 0.50
    var instructionYRatio: CGFloat = 0.76

    var requiresTapToStart = true
    var disappearFadeDuration: TimeInterval = 0
    var sessionEndHoldDuration: TimeInterval = 0.35
    var maximumSimulationDelta: TimeInterval = 0.25
    var exactTolerance: TimeInterval = 0

    var backgroundRed: CGFloat = 16 / 255
    var backgroundGreen: CGFloat = 20 / 255
    var backgroundBlue: CGFloat = 40 / 255
    var containerRed: CGFloat = 1
    var containerGreen: CGFloat = 1
    var containerBlue: CGFloat = 1
    var containerOpacity: CGFloat = 0.12
    var fillTopRed: CGFloat = 0
    var fillTopGreen: CGFloat = 229 / 255
    var fillTopBlue: CGFloat = 1
    var fillBottomRed: CGFloat = 41 / 255
    var fillBottomGreen: CGFloat = 121 / 255
    var fillBottomBlue: CGFloat = 1

    static let reference = TimesUpGameConfig()

    func targetDuration(forLevelIndex index: Int) -> TimeInterval {
        guard !targetDurations.isEmpty else { return 10 }
        let clamped = min(max(0, index), targetDurations.count - 1)
        return max(0.05, targetDurations[clamped])
    }

    var resolvedLevelCount: Int { max(1, levelCount) }
    var resolvedVisibilityFraction: Double { min(max(visibilityFraction, 0.05), 0.99) }

    var backgroundColor: UIColor {
        UIColor(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, alpha: 1)
    }

    var containerColor: UIColor {
        UIColor(red: containerRed, green: containerGreen, blue: containerBlue, alpha: containerOpacity)
    }

    var fillTopColor: UIColor {
        UIColor(red: fillTopRed, green: fillTopGreen, blue: fillTopBlue, alpha: 1)
    }

    var fillBottomColor: UIColor {
        UIColor(red: fillBottomRed, green: fillBottomGreen, blue: fillBottomBlue, alpha: 1)
    }
}
