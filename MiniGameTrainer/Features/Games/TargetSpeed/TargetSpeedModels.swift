import CoreGraphics
import Foundation

enum TargetSpeedGameState: String, Equatable {
    case ready
    case playing
    case paused
    case gameOver
}

enum TargetSpeedEndReason: String, Equatable {
    case outOfLives
}

enum TargetSpeedSizeTier: String, Equatable, CaseIterable {
    case large
    case medium
    case small
    case tiny
}

enum TargetSpeedRingStage: String, Equatable {
    case green
    case yellow
    case orange
    case red
}

struct TargetSpeedTargetState: Equatable, Identifiable {
    let id: Int
    var center: CGPoint
    var radius: CGFloat
    var spawnedAt: TimeInterval
    var expiresAt: TimeInterval
    var pointValue: Int
    var sizeTier: TargetSpeedSizeTier
    var isResolved: Bool = false
    var missedAt: TimeInterval?

    var lifetime: TimeInterval { max(0, expiresAt - spawnedAt) }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        max(0, time - spawnedAt)
    }

    func remaining(at time: TimeInterval) -> TimeInterval {
        max(0, expiresAt - time)
    }

    func remainingFraction(at time: TimeInterval) -> Double {
        guard lifetime > 0 else { return 0 }
        return min(max(remaining(at: time) / lifetime, 0), 1)
    }

    func isAlive(at time: TimeInterval) -> Bool {
        !isResolved && time <= expiresAt
    }

    func contains(_ point: CGPoint, minimumHitRadius: CGFloat) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let limit = max(radius, minimumHitRadius)
        return dx * dx + dy * dy <= limit * limit
    }
}

enum TargetSpeedInputOutcome: Equatable {
    case ignored
    case hit(id: Int, score: Int, points: Int)
    case missed(id: Int, lives: Int)
    case gameOver(id: Int)
}

struct TargetSpeedSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let livesRemaining: Int
    let hits: Int
    let misses: Int
    let ignoredTaps: Int
    let endReason: TargetSpeedEndReason?
    let averageReactionTime: TimeInterval?
    let bestReactionTime: TimeInterval?
}

struct TargetSpeedDifficultySnapshot: Equatable {
    let stageIndex: Int
    let lifetime: TimeInterval
    let spawnInterval: TimeInterval
    let maxActive: Int
    let minDiameterRatio: CGFloat
    let maxDiameterRatio: CGFloat
}
