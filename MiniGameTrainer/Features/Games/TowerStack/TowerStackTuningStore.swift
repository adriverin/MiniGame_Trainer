import Combine
import CoreGraphics
import Foundation

@MainActor
final class TowerStackTuningStore: ObservableObject {
    static let shared = TowerStackTuningStore()

    @Published var config: TowerStackGameConfig = .reference
    @Published var debugOptions: TowerStackDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-towerStackAutoStart") {
            debugOptions.skipHint = true
        }
        if arguments.contains("-towerStackOverlay") {
            debugOptions.showPerformanceOverlay = true
        }
        if arguments.contains("-towerStackGeometry") {
            debugOptions.showGeometry = true
        }
        if let value = argumentValue(after: "-towerStackAutoPlace", in: arguments), let fraction = Double(value) {
            debugOptions.autoPlaceOffsetFraction = CGFloat(fraction)
        }
        if let value = argumentValue(after: "-towerStackMissAt", in: arguments), let score = Int(value), score >= 0 {
            debugOptions.autoMissAtScore = score
        }
        if let value = argumentValue(after: "-towerStackPauseAtScore", in: arguments), let score = Int(value), score >= 0 {
            debugOptions.pauseAtScore = score
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }

    #if DEBUG
    private func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    #endif
}
