import Combine
import Foundation

@MainActor
final class SwipeFastTuningStore: ObservableObject {
    static let shared = SwipeFastTuningStore()

    @Published var config: SwipeFastGameConfig = .reference
    @Published var debugOptions: SwipeFastDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-swipeFastOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-swipeFastGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-swipeFastAutoStart") { config.requiresTapToStart = false }
        if arguments.contains("-swipeFastAutoPlay") {
            debugOptions.autoPlay = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-swipeFastAutoWrong") {
            debugOptions.autoPlay = true
            debugOptions.autoPlayWrong = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-swipeFastAutoExpire") {
            debugOptions.autoPlay = true
            debugOptions.autoPlayExpire = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-swipeFastScore"),
           arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedScore = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-swipeFastSeed"),
           arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.seed = value
            config.generatorSeed = value
        }
        if let index = arguments.firstIndex(of: "-swipeFastAllowedTime"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.allowedTimeOverride = value
        }
        if arguments.contains("-swipeFastWrongFails") {
            debugOptions.wrongSwipeBehavior = .gameOver
            config.wrongSwipeBehavior = .gameOver
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
