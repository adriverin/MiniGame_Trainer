import CoreGraphics
import Foundation
import UIKit

enum CenterHitDirection: Int, Codable, CaseIterable, Identifiable {
    case left = -1
    case right = 1

    var id: Int { rawValue }
    var symbol: String { self == .right ? "→" : "←" }
    var displayName: String { self == .right ? "Right" : "Left" }
}

/// Reference-derived geometry, movement and scoring calibration. Ratios keep the mechanic
/// consistent across portrait iPhone sizes instead of baking in pixels from the recording.
struct CenterHitGameConfig: Equatable, Codable {
    var attemptCount = 5
    var barWidthRatio: CGFloat = 0.80
    var barHeightToWidthRatio: CGFloat = 0.249
    var barCenterYRatio: CGFloat = 0.264
    var redZoneRatio: CGFloat = 0.125
    var orangeZoneRatio: CGFloat = 0.125
    var yellowZoneRatio: CGFloat = 0.15

    var indicatorWidthToBarRatio: CGFloat = 0.0156
    var indicatorHeightToBarRatio: CGFloat = 1.20
    var centerLineWidthToBarRatio: CGFloat = 0.006

    /// Explicit reference-calibrated speeds in complete bar widths per second.
    var speedLevels: [CGFloat] = [0.94, 1.44, 1.90, 2.30, 3.00]
    var initialPositionRatio: CGFloat = 0.5
    var initialDirection: CenterHitDirection = .right
    var requiresTapToStart = false
    var sessionEndHoldDuration: TimeInterval = 0.35
    var maximumSimulationDelta: TimeInterval = 0.25

    /// 0 means only the mathematical center is perfect. Kept configurable for calibration.
    var perfectCenterHalfWidthRatio: CGFloat = 0
    var precisionExponent: Double = 1
    var precisionCoefficient: Double = 1

    static let reference = CenterHitGameConfig()

    var backgroundColor: UIColor { UIColor(red: 32 / 255, green: 35 / 255, blue: 57 / 255, alpha: 1) }
    var redColor: UIColor { UIColor(red: 240 / 255, green: 64 / 255, blue: 67 / 255, alpha: 1) }
    var orangeColor: UIColor { UIColor(red: 251 / 255, green: 133 / 255, blue: 54 / 255, alpha: 1) }
    var yellowColor: UIColor { UIColor(red: 232 / 255, green: 168 / 255, blue: 8 / 255, alpha: 1) }
    var greenColor: UIColor { UIColor(red: 32 / 255, green: 188 / 255, blue: 83 / 255, alpha: 1) }
    var precisionColor: UIColor { UIColor(red: 8 / 255, green: 183 / 255, blue: 216 / 255, alpha: 1) }

    func speedRatio(forAttemptIndex index: Int) -> CGFloat {
        guard !speedLevels.isEmpty else { return 1 }
        return max(0, speedLevels[min(max(0, index), speedLevels.count - 1)])
    }

    /// Symmetric seven-zone layout. Invalid DEBUG combinations are proportionally contracted.
    var normalizedZoneFractions: [CGFloat] {
        let side = [max(0, redZoneRatio), max(0, orangeZoneRatio), max(0, yellowZoneRatio)]
        let sideTotal = side.reduce(0, +)
        let safeSide = sideTotal >= 0.495 ? side.map { $0 * 0.495 / sideTotal } : side
        let green = max(0.01, 1 - 2 * safeSide.reduce(0, +))
        return safeSide + [green] + safeSide.reversed()
    }
}
