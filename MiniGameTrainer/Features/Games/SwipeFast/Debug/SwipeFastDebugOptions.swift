import Foundation

struct SwipeFastDebugOptions: Equatable {
    var showOverlay = false
    var showGeometry = false
    var autoPlay = false
    var autoPlayWrong = false
    var autoPlayExpire = false
    var autoPlayReactionDelay: TimeInterval = 0.08
    var forcedScore: Int?
    var forcedDirections: [SwipeDirection]?
    var allowedTimeOverride: TimeInterval?
    var seed: UInt64?
    var wrongSwipeBehavior: SwipeFastWrongSwipeBehavior?
    var expireBox: SwipeFastBoxIndex?

    static let none = SwipeFastDebugOptions()
}
