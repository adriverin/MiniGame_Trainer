import Foundation

/// Developer toggles. The struct exists in every build so the scene has a single code path;
/// the editing UI (`PianoDebugSettingsView`) is DEBUG-only.
struct PianoDebugOptions: Equatable {
    var showHitboxes = false
    var showPerformanceOverlay = false
    var skipCountdown = false
    var showMissLine = false

    static let none = PianoDebugOptions()
}
