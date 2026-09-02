import CoreGraphics
import Foundation
import UIKit

enum ReactInvalidTapRule: String, Equatable, Codable, CaseIterable {
    case restartWaiting
    case recordPenalty

    var displayName: String {
        switch self {
        case .restartWaiting: "Restart wait"
        case .recordPenalty: "Record penalty"
        }
    }
}

/// All gameplay, timing, rendering, and anti-anticipation calibration for REACT.
struct ReactGameConfig: Equatable, Codable {
    var roundCount = 5
    var minimumStimulusDelay: TimeInterval = 1.0
    var maximumStimulusDelay: TimeInterval = 3.5
    var feedbackDuration: TimeInterval = 0.45
    var sessionEndHoldDuration: TimeInterval = 0.35

    var circleDiameterRatio: CGFloat = 0.197
    var horizontalGapToDiameterRatio: CGFloat = 0.135
    var verticalGapToDiameterRatio: CGFloat = 0.135
    /// SpriteKit coordinate ratio measured upward from the scene bottom.
    var gridCenterYRatio: CGFloat = 0.469
    var gridCenterXRatio: CGFloat = 0.5

    var backgroundRed: CGFloat = 27.0 / 255.0
    var backgroundGreen: CGFloat = 23.0 / 255.0
    var backgroundBlue: CGFloat = 27.0 / 255.0
    var inactiveRed: CGFloat = 39.0 / 255.0
    var inactiveGreen: CGFloat = 51.0 / 255.0
    var inactiveBlue: CGFloat = 61.0 / 255.0
    var inactiveIntensity: CGFloat = 1.0
    var activeRed: CGFloat = 94.0 / 255.0
    var activeGreen: CGFloat = 209.0 / 255.0
    var activeBlue: CGFloat = 192.0 / 255.0

    var earlyTapRule: ReactInvalidTapRule = .restartWaiting
    var wrongTapRule: ReactInvalidTapRule = .restartWaiting
    var invalidTapPenalty: TimeInterval = 1.0
    var preventImmediateRepeat = false
    var requiresTapToStart = true
    var randomSeed: UInt64? = nil

    static let reference = ReactGameConfig()

    static func deterministic(seed: UInt64 = 20_260_902) -> ReactGameConfig {
        var config = ReactGameConfig()
        config.randomSeed = seed
        return config
    }

    var inactiveColor: UIColor {
        UIColor(
            red: min(max(inactiveRed * inactiveIntensity, 0), 1),
            green: min(max(inactiveGreen * inactiveIntensity, 0), 1),
            blue: min(max(inactiveBlue * inactiveIntensity, 0), 1),
            alpha: 1
        )
    }

    var activeColor: UIColor {
        UIColor(red: activeRed, green: activeGreen, blue: activeBlue, alpha: 1)
    }

    var backgroundColor: UIColor {
        UIColor(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue, alpha: 1)
    }
}
