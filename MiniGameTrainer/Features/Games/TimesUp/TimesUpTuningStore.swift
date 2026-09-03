import Combine
import Foundation

@MainActor
final class TimesUpTuningStore: ObservableObject {
    static let shared = TimesUpTuningStore()

    @Published var config: TimesUpGameConfig = .reference
    @Published var debugOptions: TimesUpDebugOptions = .none

    private init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if arguments.contains("-timesUpOverlay") { debugOptions.showOverlay = true }
        if arguments.contains("-timesUpGeometry") { debugOptions.showGeometry = true }
        if arguments.contains("-timesUpAutoStart") {
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if arguments.contains("-timesUpAutoTap") {
            debugOptions.autoPlay = .exact
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-timesUpAutoOffset"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]) {
            debugOptions.autoPlay = .offset(value)
            debugOptions.skipStartCue = true
            config.requiresTapToStart = false
        }
        if let index = arguments.firstIndex(of: "-timesUpScript"), arguments.indices.contains(index + 1) {
            let values = arguments[index + 1].split(separator: ",").compactMap { Double($0) }
            if !values.isEmpty {
                debugOptions.autoPlay = .scripted(values)
                debugOptions.skipStartCue = true
                config.requiresTapToStart = false
            }
        }
        #endif
    }

    func resetToReference() {
        config = .reference
        debugOptions = .none
    }
}
