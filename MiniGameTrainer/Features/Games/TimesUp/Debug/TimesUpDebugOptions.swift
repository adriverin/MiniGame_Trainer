import Foundation

enum TimesUpAutoPlayMode: Equatable, Hashable {
    case off
    /// Tap exactly at the target duration.
    case exact
    /// Tap this many seconds after the target. Positive = late.
    case offset(TimeInterval)
    /// One signed error per level, repeating the last value if the session is longer.
    case scripted([TimeInterval])
}

struct TimesUpDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var skipStartCue = false
    var autoPlay: TimesUpAutoPlayMode = .off

    static let none = TimesUpDebugOptions()

    func signedError(forLevelIndex index: Int) -> TimeInterval? {
        switch autoPlay {
        case .off:
            return nil
        case .exact:
            return 0
        case .offset(let value):
            return value
        case .scripted(let values):
            guard !values.isEmpty else { return 0 }
            return values[min(max(0, index), values.count - 1)]
        }
    }
}
