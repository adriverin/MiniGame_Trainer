import Foundation

enum MonetizationLog {
    static func debug(_ message: String) {
        #if DEBUG
        print("[Monetization] \(message)")
        #endif
    }
}
