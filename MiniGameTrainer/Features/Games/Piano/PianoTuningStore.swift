import Foundation
import Combine

/// Holds the configuration used for the next Piano session. In release builds it is always
/// `PianoGameConfig.reference`; in DEBUG the tuning panel edits it live. Scoped to the Piano
/// feature so the application shell stays game-agnostic.
@MainActor
final class PianoTuningStore: ObservableObject {
    static let shared = PianoTuningStore()

    @Published var config: PianoGameConfig = .reference
    @Published var debugOptions: PianoDebugOptions = .none

    private init() {}

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
