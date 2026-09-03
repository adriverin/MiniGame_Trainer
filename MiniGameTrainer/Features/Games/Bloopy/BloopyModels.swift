import CoreGraphics
import Foundation

enum BloopyGameState: Equatable {
    case ready
    case playing
    case paused
    case gameOver
}

enum BloopyHorizontalInput: Int, Equatable {
    case none = 0
    case left = -1
    case right = 1
}

enum BloopyPlatformKind: String, Equatable, Codable, CaseIterable {
    case fresh
    case used
}

struct BloopyPlatform: Equatable, Identifiable {
    let id: Int
    var worldX: CGFloat
    var worldY: CGFloat
    var width: CGFloat
    var kind: BloopyPlatformKind
}

struct BloopyTrailSample: Equatable {
    var position: CGPoint
    var age: TimeInterval
}

enum BloopyGameEvent: Equatable {
    case bounced(platformID: Int, score: Int)
    case scoreChanged(Int)
    case failed
}

struct BloopySessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let landings: Int
    let maxWorldY: CGFloat
    let wrapCount: Int
    let usedPlatformCount: Int
}

struct BloopyLanding: Equatable {
    let platformID: Int
    let time: TimeInterval
    let ballPosition: CGPoint
    let remainingTime: TimeInterval
}
