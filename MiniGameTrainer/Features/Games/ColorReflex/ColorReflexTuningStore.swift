import Combine
import Foundation

@MainActor
final class ColorReflexTuningStore: ObservableObject {
    static let shared = ColorReflexTuningStore()

    @Published var config: ColorReflexGameConfig = .reference
    @Published var debugOptions: ColorReflexDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-colorReflexOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-colorReflexGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-colorReflexAutoStart") {
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-colorReflexAutoReact") {
            debugOptions.autoReact = true
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-colorReflexAutoPremature") {
            debugOptions.autoPremature = true
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-colorReflexAutoDelay"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.autoReact = true
            debugOptions.autoReactDelay = max(0, value)
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-colorReflexScore"),
           arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedScore = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-colorReflexSeed"),
           arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.seed = value
            config.generatorSeed = value
        }
        if let index = arguments.firstIndex(of: "-colorReflexDuration"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.sessionDurationOverride = value
            config.sessionDuration = value
        }
        if let index = arguments.firstIndex(of: "-colorReflexPenalty"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.prematurePenaltyOverride = value
            config.prematurePenalty = value
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
