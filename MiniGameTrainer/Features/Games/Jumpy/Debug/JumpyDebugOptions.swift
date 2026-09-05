import Foundation

struct JumpyDebugOptions: Equatable {
    var showOverlay = false
    var showHitboxes = false
    var autoAdvance = false
    var holdCollision = false
    var controlQAScript = false
    var disableCollisions = false
    var forcedDifficultyScore: Int?

    static let none = JumpyDebugOptions()
}
