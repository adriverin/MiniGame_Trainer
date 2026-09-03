import Foundation

struct ColorReflexDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var skipStartCue = false
    var autoReact = false
    var autoReactDelay: TimeInterval = 0.218
    var autoPremature = false
    var autoPrematureAt: TimeInterval = 0.40
    var forcedScore: Int?
    var forcedColorSequence: [ColorReflexSwatch]?
    var waitDelayOverride: TimeInterval?
    var sessionDurationOverride: TimeInterval?
    var prematurePenaltyOverride: TimeInterval?
    var seed: UInt64?

    static let none = ColorReflexDebugOptions()
}
