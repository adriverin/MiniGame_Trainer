import CoreGraphics
import Foundation

enum TrampboxGameState: Equatable {
    case ready
    case countdown
    case playing
    case paused
    case falling
    case gameOver(TrampboxGameOverReason)
}

enum TrampboxGameOverReason: String, Equatable {
    case missedPlatform
    case aborted
}

struct TrampboxPlatform: Equatable, Identifiable {
    let id: Int
    let centerX: CGFloat
    let width: CGFloat
    let scoreLevel: Int
}

struct TrampboxLandingPerformance: Equatable {
    let platformID: Int
    let platformCenterX: CGFloat
    let ballCenterX: CGFloat
    let horizontalError: CGFloat
    let normalizedError: CGFloat
    let platformWidth: CGFloat
    let score: Int

    /// 1 is centered; 0 is at or beyond the platform edge.
    var precision: Double {
        Double(max(0, 1 - normalizedError))
    }
}

enum TrampboxGameEvent: Equatable {
    case stateChanged(TrampboxGameState)
    case landed(TrampboxLandingPerformance)
    case scoreChanged(Int)
    case gameEnded(TrampboxGameOverReason)
}

struct TrampboxSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let landings: Int
    let averagePrecision: Double?
    let medianLandingError: CGFloat?
    let bestPrecision: Double?
    let closestEdgeSave: CGFloat?
    let averagePlatformWidth: CGFloat?
    let finalBounceDuration: TimeInterval
    let reason: TrampboxGameOverReason
}
