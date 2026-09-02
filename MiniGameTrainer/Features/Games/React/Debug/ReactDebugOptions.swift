import Foundation

struct ReactDebugOptions: Equatable {
    var showTimingOverlay = false
    var showHitboxes = false
    var skipStartCue = false
    /// Launch-only visual QA aid. Responds to each visible target after 288 ms.
    var autoTap = false

    static let none = ReactDebugOptions()
}
