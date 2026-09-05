import Foundation

struct GridDebugOptions: Equatable {
    var showOverlay = false
    var forceLevel: Int?
    var forceRows: Int?
    var forceColumns: Int?
    var forceTargetCount: Int?
    var presentationDurationOverride: TimeInterval?
    var recallTimeoutOverride: TimeInterval?
    /// DEBUG-only deterministic seed. Production must leave this `nil`.
    var seed: UInt64?
    var autoCorrect = false
    var useQualityAssurancePattern = false

    static let none = GridDebugOptions()
}
