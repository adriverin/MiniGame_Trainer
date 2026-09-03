import CoreGraphics
import Foundation
import UIKit

/// Reference-derived SWIPE FAST calibration. Allowed-time anchors come from bar urgency
/// across the 71-point recording, not from the intro's "~13s" chip.
/// See Documentation/SWIPE_FAST_GAME_ANALYSIS.md.
struct SwipeFastGameConfig: Equatable, Codable {
    var boxSizeRatio: CGFloat = 0.38
    var boxGapRatio: CGFloat = 0.045
    var boxGridCenterXRatio: CGFloat = 0.50
    /// SpriteKit Y ratio measured upward from the scene bottom.
    var boxGridCenterYRatio: CGFloat = 0.42
    var boxCornerRadiusRatio: CGFloat = 0.18
    var arrowSizeRatio: CGFloat = 0.46
    var scoreXRatio: CGFloat = 0.50
    var scoreYRatio: CGFloat = 0.72
    var scoreFontRatio: CGFloat = 0.155

    var barHeightRatio: CGFloat = 0.055
    var barHorizontalInsetRatio: CGFloat = 0.06
    var barBottomInsetRatio: CGFloat = 0.03
    var barCornerRadiusRatio: CGFloat = 0.50

    /// Remaining fraction cutovers. Above cyan, then yellow, then orange, else red.
    var cyanRemainingThreshold: Double = 0.48
    var yellowRemainingThreshold: Double = 0.30
    var orangeRemainingThreshold: Double = 0.16

    var difficultyAnchorScores: [Int] = [0, 10, 20, 30, 40, 50, 60, 70]
    var difficultyAnchorDurations: [TimeInterval] = [2.00, 1.80, 1.60, 1.42, 1.28, 1.16, 1.08, 1.00]
    var minimumAllowedTime: TimeInterval = 1.00

    /// Inclusive: hypot(dx, dy) >= boxSide * ratio counts as a swipe.
    var minimumSwipeDistanceRatio: CGFloat = 0.16
    var maximumGestureDuration: TimeInterval = 1.20
    var wrongSwipeBehavior: SwipeFastWrongSwipeBehavior = .ignore
    var avoidImmediateRepeat: Bool = false

    var requiresTapToStart = false
    var sessionEndHoldDuration: TimeInterval = 0.35
    var maximumSimulationDelta: TimeInterval = 0.25
    var generatorSeed: UInt64 = 1

    var backgroundRed: CGFloat = 26 / 255
    var backgroundGreen: CGFloat = 12 / 255
    var backgroundBlue: CGFloat = 51 / 255
    var boxRed: CGFloat = 58 / 255
    var boxGreen: CGFloat = 32 / 255
    var boxBlue: CGFloat = 96 / 255
    var arrowRed: CGFloat = 1
    var arrowGreen: CGFloat = 1
    var arrowBlue: CGFloat = 1
    var cyanRed: CGFloat = 40 / 255
    var cyanGreen: CGFloat = 220 / 255
    var cyanBlue: CGFloat = 230 / 255
    var yellowRed: CGFloat = 1
    var yellowGreen: CGFloat = 214 / 255
    var yellowBlue: CGFloat = 70 / 255
    var orangeRed: CGFloat = 1
    var orangeGreen: CGFloat = 140 / 255
    var orangeBlue: CGFloat = 48 / 255
    var redRed: CGFloat = 1
    var redGreen: CGFloat = 72 / 255
    var redBlue: CGFloat = 72 / 255

    static let reference = SwipeFastGameConfig()

    var backgroundColor: UIColor {
        UIColor(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, alpha: 1)
    }

    var boxColor: UIColor {
        UIColor(red: boxRed, green: boxGreen, blue: boxBlue, alpha: 1)
    }

    var arrowColor: UIColor {
        UIColor(red: arrowRed, green: arrowGreen, blue: arrowBlue, alpha: 1)
    }

    func barColor(for stage: SwipeFastBarStage) -> UIColor {
        switch stage {
        case .cyan:
            UIColor(red: cyanRed, green: cyanGreen, blue: cyanBlue, alpha: 1)
        case .yellow:
            UIColor(red: yellowRed, green: yellowGreen, blue: yellowBlue, alpha: 1)
        case .orange:
            UIColor(red: orangeRed, green: orangeGreen, blue: orangeBlue, alpha: 1)
        case .red:
            UIColor(red: redRed, green: redGreen, blue: redBlue, alpha: 1)
        }
    }

    func barStage(remainingFraction: Double) -> SwipeFastBarStage {
        let fraction = min(max(remainingFraction, 0), 1)
        if fraction > cyanRemainingThreshold { return .cyan }
        if fraction > yellowRemainingThreshold { return .yellow }
        if fraction > orangeRemainingThreshold { return .orange }
        return .red
    }
}
