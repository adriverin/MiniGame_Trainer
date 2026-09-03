import Foundation

struct DirectionsDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var skipPresentation = false
    var autoInputCorrect = false
    var autoInputFailAt: Int?
    var forcedLevel: Int?
    var forcedSequence: [Direction]?
    var sequenceLengthOverride: Int?
    var arrowOnDurationOverride: TimeInterval?
    var interArrowGapOverride: TimeInterval?
    var transitionDurationOverride: TimeInterval?
    var seed: UInt64?

    static let none = DirectionsDebugOptions()
}
