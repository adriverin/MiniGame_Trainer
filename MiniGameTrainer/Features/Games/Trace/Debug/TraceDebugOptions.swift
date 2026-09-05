import Foundation

struct TraceDebugOptions: Equatable {
    var showOverlay = false
    var showHitboxes = false
    var autoSolve = false
    var autoSolveWrong = false
    var skipPresentation = false
    var forcedScore: Int?
    var forcedRadius: Int?
    var forcedTargetCount: Int?
    var forcedSeed: UInt64?
    var forcedPattern: [TraceNode]?

    static let none = TraceDebugOptions()
}
