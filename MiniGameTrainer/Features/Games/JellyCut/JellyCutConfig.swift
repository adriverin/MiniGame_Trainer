import CoreGraphics
import Foundation

struct JellyCutConfig: Equatable {
    var boundaryPointCount = 18
    var minimumGestureLength: CGFloat = 30
    var minimumPieceFraction = 0.0075
    var geometryEpsilon = 1e-8
    var resultHoldDuration: TimeInterval = 1.65
    var summaryHoldDuration: TimeInterval = 1.9
    var cutAnimationDuration: TimeInterval = 0.26
    var separationWidthRatio: CGFloat = 0.055
    var jellyWidthRatio: CGFloat = 0.66
    var jellyHeightRatio: CGFloat = 0.31
}
