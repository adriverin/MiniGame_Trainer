import Combine
import CoreGraphics
import Foundation

@MainActor
final class TargetSpeedTuningStore: ObservableObject {
    static let shared = TargetSpeedTuningStore()

    @Published var config: TargetSpeedGameConfig = .reference
    @Published var debugOptions: TargetSpeedDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-targetSpeedOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-targetSpeedHitboxes") { debugOptions.showHitboxes = true }
        if arguments.contains("-targetSpeedAutoStart") { config.requiresTapToStart = false }
        if arguments.contains("-targetSpeedAutoHit") {
            debugOptions.autoHit = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-targetSpeedAutoMiss") {
            debugOptions.autoMiss = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-targetSpeedScore"),
           arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedScore = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-targetSpeedLives"),
           arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedLives = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-targetSpeedSeed"),
           arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.seed = value
            config.generatorSeed = value
        }
        if let index = arguments.firstIndex(of: "-targetSpeedLifetime"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.lifetimeOverride = value
        }
        if let index = arguments.firstIndex(of: "-targetSpeedSpawn"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.spawnIntervalOverride = value
        }
        if let index = arguments.firstIndex(of: "-targetSpeedMaxActive"),
           arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.maxActiveOverride = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-targetSpeedRadius"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.forcedRadius = CGFloat(value)
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
