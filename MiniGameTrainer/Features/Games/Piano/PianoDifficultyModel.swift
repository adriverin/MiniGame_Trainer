import CoreGraphics
import Foundation

/// Score-driven difficulty curve measured from the reference (speed grows linearly with score).
struct PianoDifficultyModel: Equatable {
    let config: PianoGameConfig

    /// Scroll speed in scene heights per second for a given score.
    func speedRatio(forScore score: Int) -> CGFloat {
        let raw = config.initialSpeed + CGFloat(max(0, score)) * config.speedIncreasePerPoint
        return min(raw, config.maximumSpeed)
    }

    /// Scroll speed in points per second for a concrete layout.
    func speed(forScore score: Int, geometry: PianoGeometry) -> CGFloat {
        speedRatio(forScore: score) * geometry.sceneSize.height
    }

    /// Rows are contiguous, so a new row appears every time the column travels one row height.
    func spawnInterval(forScore score: Int, geometry: PianoGeometry) -> TimeInterval {
        let speed = self.speed(forScore: score, geometry: geometry)
        guard speed > 0 else { return .infinity }
        return TimeInterval(geometry.rowHeight / speed)
    }

    /// Seconds a tile is visible between entering the playfield and reaching the miss line.
    func reactionWindow(forScore score: Int, geometry: PianoGeometry) -> TimeInterval {
        let speed = self.speed(forScore: score, geometry: geometry)
        guard speed > 0 else { return .infinity }
        return TimeInterval(geometry.reactionDistance / speed)
    }
}
