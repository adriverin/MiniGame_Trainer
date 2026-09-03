import Combine
import Foundation

@MainActor
final class GridTuningStore: ObservableObject {
    static let shared = GridTuningStore()

    @Published var config: GridGameConfig = .reference
    @Published var debugOptions: GridDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-gridOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-gridAutoCorrect") { debugOptions.autoCorrect = true }
        if arguments.contains("-gridForcePattern") { debugOptions.useQualityAssurancePattern = true }
        if let index = arguments.firstIndex(of: "-gridSeed"), arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.seed = value
        }
        if let index = arguments.firstIndex(of: "-gridLevel"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forceLevel = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-gridRows"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forceRows = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-gridColumns"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forceColumns = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-gridTargets"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forceTargetCount = max(1, value)
        }
        if let index = arguments.firstIndex(of: "-gridPresentation"), arguments.indices.contains(index + 1),
           let value = TimeInterval(arguments[index + 1]) {
            debugOptions.presentationDurationOverride = max(0.05, value)
        }
        if let index = arguments.firstIndex(of: "-gridTimeout"), arguments.indices.contains(index + 1),
           let value = TimeInterval(arguments[index + 1]) {
            debugOptions.recallTimeoutOverride = max(0.05, value)
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
