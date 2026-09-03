import Combine
import Foundation

@MainActor
final class TraceTuningStore: ObservableObject {
    static let shared = TraceTuningStore()

    @Published var config: TraceGameConfig = .reference
    @Published var debugOptions: TraceDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-traceOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-traceHitboxes") { debugOptions.showHitboxes = true }
        if arguments.contains("-traceAutoSolve") { debugOptions.autoSolve = true }
        if arguments.contains("-traceAutoSolveWrong") {
            debugOptions.autoSolve = true
            debugOptions.autoSolveWrong = true
        }
        if arguments.contains("-traceSkipPresentation") { debugOptions.skipPresentation = true }
        if let index = arguments.firstIndex(of: "-traceScore"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.forcedScore = max(0, value)
        }
        if let index = arguments.firstIndex(of: "-traceSeed"), arguments.indices.contains(index + 1),
           let value = UInt64(arguments[index + 1]) {
            debugOptions.forcedSeed = value
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
