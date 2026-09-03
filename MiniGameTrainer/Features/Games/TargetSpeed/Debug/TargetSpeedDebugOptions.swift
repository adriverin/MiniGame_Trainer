import CoreGraphics
import Foundation

struct TargetSpeedDebugOptions: Equatable {
    var showOverlay = false
    var showHitboxes = false
    var autoHit = false
    var autoMiss = false
    var autoPlayReactionDelay: TimeInterval = 0.12
    var forcedScore: Int?
    var forcedLives: Int?
    var forcedRadius: CGFloat?
    var forcedPosition: CGPoint?
    var spawnIntervalOverride: TimeInterval?
    var lifetimeOverride: TimeInterval?
    var maxActiveOverride: Int?
    var seed: UInt64?

    static let none = TargetSpeedDebugOptions()
}
