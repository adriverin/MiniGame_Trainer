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

enum BloopyPlatformAppearance: String, Equatable, Codable, CaseIterable {
    case peach
    case red
}

struct BloopyPlatform: Equatable, Identifiable {
    /// Source-observed durability: peach after the first landing, red from the second onward.
    static let redLandingThreshold = 2

    let id: Int
    var worldX: CGFloat
    var worldY: CGFloat
    var width: CGFloat
    var landingCount: Int
    var isActive: Bool

    init(
        id: Int,
        worldX: CGFloat,
        worldY: CGFloat,
        width: CGFloat,
        landingCount: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.worldX = worldX
        self.worldY = worldY
        self.width = width
        self.landingCount = landingCount
        self.isActive = isActive
    }

    var appearance: BloopyPlatformAppearance {
        landingCount >= Self.redLandingThreshold ? .red : .peach
    }

    var isCollidable: Bool { isActive }
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
    let redPlatformCount: Int
}

struct BloopyLanding: Equatable {
    let platformID: Int
    let time: TimeInterval
    let ballPosition: CGPoint
    let remainingTime: TimeInterval
}
