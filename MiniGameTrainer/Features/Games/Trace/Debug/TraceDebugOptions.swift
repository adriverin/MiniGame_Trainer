import Foundation

struct TraceDebugOptions: Equatable {
    var showOverlay = false
    var showHitboxes = false
    var autoSolve = false
    var autoSolveWrong = false
    var skipPresentation = false
    var forcedScore: Int?
    var forcedRows: Int?
    var forcedColumns: Int?
    var forcedTargetCount: Int?
    var forcedSeed: UInt64?
    var forcedPattern: [TraceNode]?

    static let none = TraceDebugOptions()
}
