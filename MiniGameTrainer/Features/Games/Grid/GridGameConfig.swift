import CoreGraphics
import Foundation
import UIKit

struct GridCell: Hashable, Comparable, Codable {
    let row: Int
    let column: Int

    static func < (lhs: GridCell, rhs: GridCell) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.column < rhs.column
    }
}

/// Reference-derived GRID layout, timing and scoring. Ratios keep later 7×7 boards inside the
/// same envelope used by the 3×3 opening round.
struct GridGameConfig: Equatable, Codable {
    var gridWidthRatio: CGFloat = 0.84
    var gridHeightRatio: CGFloat = 0.42
    var gridCenterYRatio: CGFloat = 0.46
    var cellGapToSizeRatio: CGFloat = 0.12
    var cellCornerRadiusRatio: CGFloat = 0.22

    var scoreYRatio: CGFloat = 0.78
    var levelYRatio: CGFloat = 0.72
    var timerBarYRatio: CGFloat = 0.835
    var timerBarWidthRatio: CGFloat = 0.56
    var timerBarHeightRatio: CGFloat = 0.012

    var submitButtonWidthRatio: CGFloat = 0.72
    var submitButtonHeightRatio: CGFloat = 0.072
    var submitButtonYRatio: CGFloat = 0.155
    var submitButtonCornerRadiusRatio: CGFloat = 0.45

    var presentationDuration: TimeInterval = 1.40
    var recallTimeout: TimeInterval = 15.0
    var feedbackDuration: TimeInterval = 0.35
    var resultHoldDuration: TimeInterval = 0.42
    var maximumSimulationDelta: TimeInterval = 0.25

    var allowsDeselection = true
    var incorrectSubmitEndsRun = true
    var timeoutEndsRun = true
    var requiresTapToStart = false

    static let reference = GridGameConfig()

    var backgroundColor: UIColor { AppTheme.UIColors.gameBackground }
    var inactiveCellColor: UIColor { UIColor(red: 72 / 255, green: 78 / 255, blue: 148 / 255, alpha: 1) }
    var activeCellColor: UIColor { AppTheme.UIColors.activeTile }
    var submitColor: UIColor { UIColor(red: 86 / 255, green: 214 / 255, blue: 122 / 255, alpha: 1) }
    var submitDisabledColor: UIColor { UIColor(white: 1, alpha: 0.18) }
    var timerTrackColor: UIColor { UIColor(white: 1, alpha: 0.16) }
    var timerFillColor: UIColor { UIColor(red: 86 / 255, green: 214 / 255, blue: 122 / 255, alpha: 1) }
}
