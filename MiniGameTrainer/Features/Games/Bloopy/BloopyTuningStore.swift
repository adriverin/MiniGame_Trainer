import Combine
import Foundation

@MainActor
final class BloopyTuningStore: ObservableObject {
    static let shared = BloopyTuningStore()

    @Published var config: BloopyGameConfig = .reference
    @Published var debugOptions: BloopyDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-bloopyOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-bloopyGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-bloopyAutoSteer") { debugOptions.autoSteer = true }
        if arguments.contains("-bloopyNoTrail") { debugOptions.showTrail = false }
        if let index = arguments.firstIndex(of: "-bloopyScore"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedScore = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-bloopySeed"), arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            config.randomSeed = value
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
