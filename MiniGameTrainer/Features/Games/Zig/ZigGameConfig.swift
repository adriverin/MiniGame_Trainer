import CoreGraphics
import Foundation
import UIKit

struct ZigGameConfig: Equatable {
    var baseSpeed: CGFloat = 1.45
    var accelerationPerScore: CGFloat = 0.0305
    var maximumSpeed: CGFloat = 8.0
    var turnProbability: Double = 0.55
    var trackWidth: CGFloat = 1.0
    var supportTolerance: CGFloat = 0.04
    var startingPadHalfWidth: CGFloat = 3.0
    var startingPadBack: CGFloat = 3.0
    var startingPadFront: CGFloat = 3.0
    var guaranteedStraightCells = 2
    var lookaheadUnits = 64
    var retainedUnitsBehind = 20
    var maximumFrameDelta: TimeInterval = 0.05
    var maximumSimulationStep: TimeInterval = 1.0 / 240.0
    var fallDuration: TimeInterval = 0.45
    var horizontalScaleRatio: CGFloat = 0.085
    var verticalScaleRatio: CGFloat = 0.0475
    var cameraAnchorYRatio: CGFloat = 0.43
    var horizontalFollowResponse: TimeInterval = 0.15
    var slabDepthRatio: CGFloat = 0.20
    var ballRadiusRatio: CGFloat = 0.020
    var randomSeed: UInt64?
    var startingScore = 0

    static let reference = ZigGameConfig()

    var topColor: UIColor { UIColor(red: 1.00, green: 0.83, blue: 0.12, alpha: 1) }
    var leftSideColor: UIColor { UIColor(red: 0.56, green: 0.43, blue: 0.08, alpha: 1) }
    var rightSideColor: UIColor { UIColor(red: 0.38, green: 0.27, blue: 0.055, alpha: 1) }
    var ballColor: UIColor { UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1) }
    var backgroundTopColor: UIColor { UIColor(red: 0.12, green: 0.075, blue: 0.25, alpha: 1) }
    var backgroundBottomColor: UIColor { UIColor(red: 0.36, green: 0.16, blue: 0.70, alpha: 1) }
}

struct ZigDifficultyModel {
    let config: ZigGameConfig

    func speed(forScore score: Int) -> CGFloat {
        min(config.maximumSpeed, config.baseSpeed + config.accelerationPerScore * CGFloat(max(0, score)))
    }
}
