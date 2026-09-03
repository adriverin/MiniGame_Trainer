import Foundation

struct CenterHitDebugOptions: Equatable {
    var showTimingOverlay = false
    var showGeometry = false
    var skipStartCue = false
    /// Deterministic visual QA: taps at five fixed signed normalized center errors.
    var autoTap = false

    static let none = CenterHitDebugOptions()
}
