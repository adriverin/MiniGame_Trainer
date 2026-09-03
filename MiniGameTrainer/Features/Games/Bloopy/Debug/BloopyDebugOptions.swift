import Foundation

struct BloopyDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var showTrail = true
    var autoSteer = false
    var forcedScore: Int?

    static let none = BloopyDebugOptions()
}
