import Foundation

struct TapSevenDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var skipStartCue = false
    /// Signed offset from the target duration. `0` taps exactly at 7.000.
    var autoTapOffset: TimeInterval?

    static let none = TapSevenDebugOptions()
}
