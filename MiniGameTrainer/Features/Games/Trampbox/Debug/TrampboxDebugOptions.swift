import Foundation

struct TrampboxDebugOptions: Equatable {
    var showPerformanceOverlay = false
    var showGeometry = false
    var skipCountdown = false
    /// Launch-only visual QA aid; it steers toward the current logical target.
    var autoSteer = false
    /// Launch-only capture aid; freezes shortly after this landing so departure geometry is visible.
    var pauseAtScore: Int?

    static let none = TrampboxDebugOptions()
}
