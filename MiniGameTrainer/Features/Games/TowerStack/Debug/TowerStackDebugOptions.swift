import CoreGraphics
import Foundation

struct TowerStackDebugOptions: Equatable {
    var showPerformanceOverlay = false
    /// Draws the logical incoming/tower footprints, their intersection and the world axes.
    var showGeometry = false
    /// Starts in `.playing` without the "tap to place" hint.
    var skipHint = false
    /// Deterministic test mode: the scene taps automatically when the block centre is at
    /// `fraction × target dimension` from the tower centre (0 = perfect, 0.05 = 5 % offset).
    var autoPlaceOffsetFraction: CGFloat?
    /// With auto-place active, deliberately miss once this score is reached.
    var autoMissAtScore: Int?
    /// Freezes the scene shortly after this score for visual inspection.
    var pauseAtScore: Int?

    static let none = TowerStackDebugOptions()
}
