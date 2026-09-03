import Combine
import Foundation

@MainActor
final class TapSevenTuningStore: ObservableObject {
    static let shared = TapSevenTuningStore()

    @Published var config: TapSevenGameConfig = .reference
    @Published var debugOptions: TapSevenDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-tapSevenOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-tapSevenGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-tapSevenAutoStart") {
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-tapSevenAutoTap") {
            debugOptions.autoTapOffset = 0
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-tapSevenAutoOffset"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.autoTapOffset = value
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-tapSevenTarget"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            config.targetDuration = value
        }
        if let index = arguments.firstIndex(of: "-tapSevenPerfect"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            config.perfectThreshold = value
        }
        if let index = arguments.firstIndex(of: "-tapSevenMax"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            config.maxAttemptDuration = value
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
