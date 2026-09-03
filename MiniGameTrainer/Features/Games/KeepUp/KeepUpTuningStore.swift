import Combine
import Foundation

@MainActor
final class KeepUpTuningStore: ObservableObject {
    static let shared = KeepUpTuningStore()

    @Published var config: KeepUpGameConfig = .reference
    @Published var debugOptions: KeepUpDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-keepUpOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-keepUpGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-keepUpAutoCatch") { debugOptions.autoCatch = true }
        if arguments.contains("-keepUpNoTrail") { debugOptions.showTrail = false }
        if let index = arguments.firstIndex(of: "-keepUpEdgeCatch"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.autoCatch = true
            debugOptions.autoCatchOffset = CGFloat(min(max(value, -0.9), 0.9))
        }
        if let index = arguments.firstIndex(of: "-keepUpMissAt"), arguments.indices.contains(index + 1),
           let value = Int(arguments[index + 1]) {
            debugOptions.autoCatch = true
            debugOptions.intentionalMissAtScore = max(0, value)
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
