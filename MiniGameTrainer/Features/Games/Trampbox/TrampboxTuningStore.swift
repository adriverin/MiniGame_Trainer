import Combine
import Foundation

@MainActor
final class TrampboxTuningStore: ObservableObject {
    static let shared = TrampboxTuningStore()

    @Published var config: TrampboxGameConfig = .reference
    @Published var debugOptions: TrampboxDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-trampboxSkipCountdown") {
            debugOptions.skipCountdown = true
        }
        if arguments.contains("-trampboxAutoSteer") {
            debugOptions.autoSteer = true
        }
        if let index = arguments.firstIndex(of: "-trampboxPauseAtScore"),
           arguments.indices.contains(index + 1),
           let score = Int(arguments[index + 1]), score >= 0 {
            debugOptions.pauseAtScore = score
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
