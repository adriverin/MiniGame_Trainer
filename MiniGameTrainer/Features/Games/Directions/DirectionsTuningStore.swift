import Combine
import Foundation

@MainActor
final class DirectionsTuningStore: ObservableObject {
    static let shared = DirectionsTuningStore()

    @Published var config: DirectionsGameConfig = .reference
    @Published var debugOptions: DirectionsDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-directionsOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-directionsGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-directionsSkipPresentation") { debugOptions.skipPresentation = true }
        if arguments.contains("-directionsAutoInput") { debugOptions.autoInputCorrect = true }
        if arguments.contains("-directionsAutoStart") { config.requiresTapToStart = false }
        if let index = arguments.firstIndex(of: "-directionsFailAt"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.autoInputCorrect = true
            debugOptions.autoInputFailAt = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-directionsLevel"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedLevel = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-directionsLength"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.sequenceLengthOverride = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-directionsSeed"), arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.seed = value
            config.generatorSeed = value
        }
        if let index = arguments.firstIndex(of: "-directionsSequence"), arguments.indices.contains(index + 1) {
            debugOptions.forcedSequence = arguments[index + 1]
                .split(separator: ",")
                .compactMap { Direction(rawValue: $0.trimmingCharacters(in: .whitespaces).lowercased()) }
        }
        #endif
    }

    func resolvedConfig() -> DirectionsGameConfig {
        var resolved = config
        if let duration = debugOptions.arrowOnDurationOverride { resolved.arrowOnDuration = duration }
        if let gap = debugOptions.interArrowGapOverride { resolved.interArrowGap = gap }
        if let transition = debugOptions.transitionDurationOverride { resolved.transitionToRecallDuration = transition }
        if let seed = debugOptions.seed { resolved.generatorSeed = seed }
        if let length = debugOptions.sequenceLengthOverride {
            resolved.sequenceLengthOffset = length - 1
            resolved.sequenceLengthCap = length
        }
        return resolved
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
