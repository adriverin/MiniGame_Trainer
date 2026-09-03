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
    var intentionalMissAtScore: Int?

    static let none = KeepUpDebugOptions()
}
