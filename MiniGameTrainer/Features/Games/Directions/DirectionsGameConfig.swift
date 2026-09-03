import CoreGraphics
import Foundation
import UIKit

/// Reference-derived DIRECTIONS calibration. Sequence length and scoring come from the
/// Memorizer recording (see `Documentation/DIRECTIONS_GAME_ANALYSIS.md`).
struct DirectionsGameConfig: Equatable, Codable {
    /// `sequenceLength = min(cap, max(1, level + offset))`. Level 1 is length 3.
    var sequenceLengthOffset = 2
    var sequenceLengthCap = 16

    var arrowOnDuration: TimeInterval = 0.600
    var interArrowGap: TimeInterval = 0.266
    var transitionToRecallDuration: TimeInterval = 0.350
    var roundSuccessHoldDuration: TimeInterval = 0.720
    var gameOverHoldDuration: TimeInterval = 0.450
    var autoInputInterval: TimeInterval = 0.080

    var pointsPerCorrectInput = 1
    var failsOnFirstWrongInput = true
    var allowsConsecutiveRepeats = true
    var requiresTapToStart = false

    var scoreXRatio: CGFloat = 0.085
    var scoreYRatio: CGFloat = 0.905
    var scoreFontWidthRatio: CGFloat = 0.145
    var levelXRatio: CGFloat = 0.915
    var levelYRatio: CGFloat = 0.905
    var levelFontWidthRatio: CGFloat = 0.048
    var phaseXRatio: CGFloat = 0.085
    var phaseYRatio: CGFloat = 0.825
    var phaseFontWidthRatio: CGFloat = 0.055
    var sequenceRowYRatio: CGFloat = 0.745
    var sequenceIconWidthRatio: CGFloat = 0.042
    var sequenceIconSpacingRatio: CGFloat = 0.012
    var sequenceRowMaxItems = 9

    var observeArrowCenterXRatio: CGFloat = 0.500
    var observeArrowCenterYRatio: CGFloat = 0.470
    var observeArrowWidthRatio: CGFloat = 0.280
    var observeArrowHeightRatio: CGFloat = 0.210

    var dpadCenterXRatio: CGFloat = 0.500
    var dpadCenterYRatio: CGFloat = 0.385
    var buttonSizeRatio: CGFloat = 0.210
    var buttonGapRatio: CGFloat = 0.042
    var buttonCornerRadiusRatio: CGFloat = 0.220
    var buttonArrowSizeRatio: CGFloat = 0.42
    var buttonHitPaddingRatio: CGFloat = 1.06

    var maximumSimulationDelta: TimeInterval = 0.250
    var generatorSeed: UInt64?

    static let reference = DirectionsGameConfig()

    func sequenceLength(forLevel level: Int) -> Int {
        DirectionsDifficultyModel(config: self).sequenceLength(forLevel: level)
    }

    func presentationDuration(forSequenceLength length: Int) -> TimeInterval {
        DirectionsDifficultyModel(config: self).presentationDuration(forSequenceLength: length)
    }

    var backgroundColor: UIColor { UIColor(red: 46 / 255, green: 138 / 255, blue: 230 / 255, alpha: 1) }
    var observeArrowColor: UIColor { UIColor(red: 246 / 255, green: 242 / 255, blue: 228 / 255, alpha: 1) }
    var buttonFillColor: UIColor { UIColor(red: 244 / 255, green: 241 / 255, blue: 232 / 255, alpha: 1) }
    var buttonArrowColor: UIColor { UIColor(red: 42 / 255, green: 42 / 255, blue: 46 / 255, alpha: 1) }
    var successTextColor: UIColor { UIColor(red: 72 / 255, green: 220 / 255, blue: 150 / 255, alpha: 1) }
    var hudTextColor: UIColor { .white }
}
