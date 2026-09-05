import CoreGraphics
import Foundation

enum BloopyScoring {
    /// Height-based score: one point per `scoreUnit` of maximum world Y above the start.
    static func score(maxWorldY: CGFloat, startWorldY: CGFloat, unit: CGFloat) -> Int {
        let span = max(0, maxWorldY - startWorldY)
        let step = max(1, unit)
        if span < 1e-6 { return 0 }
        return Int(span / step)
    }
}
