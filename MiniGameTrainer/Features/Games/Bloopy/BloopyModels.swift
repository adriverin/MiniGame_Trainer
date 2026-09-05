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
    case stable
    case fragile
}

enum BloopyPlatformAppearance: String, Equatable, Codable, CaseIterable {
    case peach
    case red
}

enum BloopyFragilePhase: String, Equatable, Codable, CaseIterable {
    case fresh
    case damaged
    case consumed
}

struct BloopyPlatform: Equatable, Identifiable {
    let id: Int
    var worldX: CGFloat
    var worldY: CGFloat
    var width: CGFloat
    var kind: BloopyPlatformKind
    var landingCount: Int
    var isActive: Bool

    init(
        id: Int,
        worldX: CGFloat,
        worldY: CGFloat,
        width: CGFloat,
        kind: BloopyPlatformKind = .stable,
        landingCount: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.worldX = worldX
        self.worldY = worldY
        self.width = width
        self.kind = kind
        self.landingCount = landingCount
        self.isActive = isActive
    }

    /// Visual state is derived from kind + landings. Stable stays peach forever.
    var appearance: BloopyPlatformAppearance {
        switch kind {
        case .stable:
            return .peach
        case .fragile:
            return landingCount >= 1 ? .red : .peach
        }
    }

    var fragilePhase: BloopyFragilePhase? {
        guard kind == .fragile else { return nil }
        if landingCount <= 0 { return .fresh }
        if landingCount == 1 { return .damaged }
        return .consumed
    }

    var isConsumed: Bool { kind == .fragile && landingCount >= 2 }

    var isCollidable: Bool { isActive && !isConsumed }
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
