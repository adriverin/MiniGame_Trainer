import Combine
import Foundation

@MainActor
final class JumpyTuningStore: ObservableObject {
    static let shared = JumpyTuningStore()
    @Published var config = JumpyGameConfig.reference
    @Published var debugOptions = JumpyDebugOptions.none

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
