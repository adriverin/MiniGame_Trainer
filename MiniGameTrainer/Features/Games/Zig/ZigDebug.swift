import Combine
import Foundation

struct ZigDebugOptions: Equatable {
    var showOverlay = false
    var showSupport = false
    var autoPlay = false
    var holdFailure = false
    static let none = ZigDebugOptions()
}

@MainActor
final class ZigTuningStore: ObservableObject {
    static let shared = ZigTuningStore()
    @Published var config = ZigGameConfig.reference
    @Published var debugOptions = ZigDebugOptions.none
    func resetToReference() { config = .reference; debugOptions = .none }
}
