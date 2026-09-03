import Combine
import Foundation

@MainActor
final class CenterHitTuningStore: ObservableObject {
    static let shared = CenterHitTuningStore()

    @Published var config: CenterHitGameConfig = .reference
    @Published var debugOptions: CenterHitDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-centerHitOverlay") { debugOptions.showTimingOverlay = true }
        if arguments.contains("-centerHitGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-centerHitSkipStart") { debugOptions.skipStartCue = true }
        if arguments.contains("-centerHitAutoTap") { debugOptions.autoTap = true }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
