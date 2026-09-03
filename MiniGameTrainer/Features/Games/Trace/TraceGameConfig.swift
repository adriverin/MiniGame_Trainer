import CoreGraphics
import Foundation
import UIKit

/// Reference-derived TRACE configuration. Ratios are of the SpriteKit scene.
struct TraceGameConfig: Equatable, Codable {
    var scoreYFromTopRatio: CGFloat = 0.120
    var timerYFromTopRatio: CGFloat = 0.155
    var timerWidthRatio: CGFloat = 0.560
    var timerThicknessRatio: CGFloat = 0.007
    var gridCenterXRatio: CGFloat = 0.500
    var gridCenterYRatio: CGFloat = 0.420
    var gridWidthRatio: CGFloat = 0.780
    var gridHeightRatio: CGFloat = 0.520
    var nodeVisualRadiusToSpacing: CGFloat = 0.220
    var lineWidthToSpacing: CGFloat = 0.420
    var nodeHitRadiusToSpacing: CGFloat = 0.420
    var requireAdjacentSteps = true
    var acceptReverseSequence = false
    var pointsPerCorrectSegment = 1
    var segmentRevealDuration: TimeInterval = 0.32
    var patternHoldDuration: TimeInterval = 0.40
    var transitionDuration: TimeInterval = 0.35
    var evaluationDuration: TimeInterval = 0.18
    var recallBaseDuration: TimeInterval = 2.80
    var recallDurationPerSegment: TimeInterval = 0.55
    /// 0 disables the inferred score-attack session clock.
    var sessionDuration: TimeInterval = 110
    var timeoutEndsSession = false
    var wrongNodeEndsSession = false
    var incompleteLiftEndsSession = false
    var restartPatternOnBackground = true
    var maximumFrameDelta: TimeInterval = 0.100
    var gridAnchorScores: [Int] = [0, 8, 16, 28, 42, 60, 80]
    var gridAnchorRows: [Int] = [3, 4, 5, 6, 7, 8, 9]
    var gridAnchorColumns: [Int] = [2, 3, 4, 5, 6, 7, 8]
    var pathTypicalCounts: [Int] = [4, 5, 6, 7, 9, 11, 13]
    var pathLengthJitter = 2
    var minimumPathLength = 3
    var maximumPathLength = 16
    var generatorRestartLimit = 48

    static let reference = TraceGameConfig()

    var backgroundColor: UIColor { UIColor(red: 36 / 255, green: 82 / 255, blue: 230 / 255, alpha: 1) }
    var inactiveNodeColor: UIColor { UIColor(red: 90 / 255, green: 120 / 255, blue: 255 / 255, alpha: 0.42) }
    var referenceColor: UIColor { UIColor(red: 1.00, green: 0.86, blue: 0.28, alpha: 1) }
    var playerColor: UIColor { UIColor(red: 0.35, green: 0.95, blue: 0.96, alpha: 1) }
    var incorrectColor: UIColor { UIColor(red: 0.95, green: 0.28, blue: 0.32, alpha: 1) }
    var scoreColor: UIColor { .white }
    var timerTrackColor: UIColor { UIColor(white: 1, alpha: 0.16) }
    var timerFillColor: UIColor { UIColor(red: 1.00, green: 0.86, blue: 0.28, alpha: 1) }
}
