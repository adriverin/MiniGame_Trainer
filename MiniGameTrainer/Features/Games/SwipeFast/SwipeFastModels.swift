import CoreGraphics
import Foundation

enum SwipeDirection: String, Equatable, CaseIterable, Codable {
    case up
    case right
    case down
    case left
}

enum SwipeFastBoxIndex: Int, Equatable, CaseIterable {
    case topLeft = 0
    case topRight = 1
    case bottomLeft = 2
    case bottomRight = 3

    var label: String {
        switch self {
        case .topLeft: "TL"
        case .topRight: "TR"
        case .bottomLeft: "BL"
        case .bottomRight: "BR"
        }
    }
}

enum SwipeFastGameState: String, Equatable {
    case ready
    case playing
    case paused
    case gameOver
}

enum SwipeFastWrongSwipeBehavior: String, Equatable, CaseIterable, Codable {
    case ignore
    case gameOver
}

enum SwipeFastBarStage: String, Equatable {
    case cyan
    case yellow
    case orange
    case red
}

enum SwipeFastEndReason: String, Equatable {
    case expired
    case wrongSwipe
}

struct SwipeFastBoxState: Equatable {
    var direction: SwipeDirection
    var spawnedAt: TimeInterval
    var allowedTime: TimeInterval

    var deadline: TimeInterval { spawnedAt + allowedTime }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        max(0, time - spawnedAt)
    }

    func remaining(at time: TimeInterval) -> TimeInterval {
        max(0, deadline - time)
    }

    func remainingFraction(at time: TimeInterval) -> Double {
        guard allowedTime > 0 else { return 0 }
        return min(max(1 - elapsed(at: time) / allowedTime, 0), 1)
    }

    func isExpired(at time: TimeInterval) -> Bool {
        time >= deadline
    }
}

struct SwipeFastActiveGesture: Equatable {
    let box: SwipeFastBoxIndex
    let start: CGPoint
    let startedAt: TimeInterval
    var last: CGPoint
}

enum SwipeFastInputOutcome: Equatable {
    case ignored
    case started
    case tooShort
    case correct(box: SwipeFastBoxIndex, score: Int, newDirection: SwipeDirection)
    case wrong(box: SwipeFastBoxIndex, expected: SwipeDirection, actual: SwipeDirection)
    case expired(box: SwipeFastBoxIndex)
}

struct SwipeFastSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let correctSwipes: Int
    let ignoredGestures: Int
    let wrongSwipes: Int
    let expiredBox: SwipeFastBoxIndex?
    let endReason: SwipeFastEndReason?
    let averageReactionTime: TimeInterval?
    let bestReactionTime: TimeInterval?
}
