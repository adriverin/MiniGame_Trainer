import CoreGraphics
import Foundation

struct KeepUpDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var showTrail = true
    /// Visual QA only: continually places the platform for a deterministic catch.
    var autoCatch = false
    /// Signed normalized ball-to-platform impact offset requested by auto-catch.
    var autoCatchOffset: CGFloat = 0
    /// When set, auto-catch holds this platform-center Y ratio instead of a small sine wobble.
    var autoCatchPlatformYRatio: CGFloat?
    /// Inspect physics at a calibrated score without playing up to that score.
    var physicsScoreOverride: Int?
    var intentionalMissAtScore: Int?

    static let none = KeepUpDebugOptions()
}
