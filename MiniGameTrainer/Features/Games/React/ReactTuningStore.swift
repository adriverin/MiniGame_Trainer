import Combine
import Foundation

@MainActor
final class ReactTuningStore: ObservableObject {
    static let shared = ReactTuningStore()

    @Published var config: ReactGameConfig = .reference
    @Published var debugOptions: ReactDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-reactSkipStart") { debugOptions.skipStartCue = true }
        if arguments.contains("-reactOverlay") { debugOptions.showTimingOverlay = true }
        if arguments.contains("-reactHitboxes") { debugOptions.showHitboxes = true }
        if arguments.contains("-reactAutoTap") { debugOptions.autoTap = true }
        if let index = arguments.firstIndex(of: "-reactSeed"),
           arguments.indices.contains(index + 1),
           let seed = UInt64(arguments[index + 1]) {
            config.randomSeed = seed
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
