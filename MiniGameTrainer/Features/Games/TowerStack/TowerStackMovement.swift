import CoreGraphics
import Foundation

/// The sliding block above the tower. Pure value type so movement can be advanced analytically to
/// an arbitrary timestamp (touch time) without touching the rendering layer.
struct TowerStackMovingBlock: Equatable {
    let axis: TowerStackAxis
    /// World coordinate along `axis`.
    var position: CGFloat
    /// +1 or −1 along `axis`.
    var direction: CGFloat
    /// World units per second.
    let speed: CGFloat
    /// Reflection bounds of the path along `axis`.
    let minimum: CGFloat
    let maximum: CGFloat
    /// Footprint inherited from the tower top; only `center(along: axis)` changes while sliding.
    private let baseFootprint: TowerStackFootprint
    /// Index of the layer this block will occupy once placed (0 = first block on the pedestal).
    let layer: Int

    init(
        axis: TowerStackAxis,
        position: CGFloat,
        direction: CGFloat,
        speed: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        footprint: TowerStackFootprint,
        layer: Int
    ) {
        self.axis = axis
        self.position = position
        self.direction = direction >= 0 ? 1 : -1
        self.speed = speed
        self.minimum = min(minimum, maximum)
        self.maximum = max(minimum, maximum)
        baseFootprint = footprint
        self.layer = layer
    }

    var footprint: TowerStackFootprint {
        baseFootprint.moved(to: position, along: axis)
    }

    /// Advances by `deltaTime` with exact reflection at both ends: the overshoot beyond a boundary
    /// is mirrored back into the range rather than discarded, so behaviour is frame-rate independent.
    mutating func advance(by deltaTime: TimeInterval) {
        guard deltaTime > 0, speed > 0 else { return }
        let range = maximum - minimum
        guard range > 0 else {
            position = minimum
            return
        }
        var remaining = speed * CGFloat(deltaTime)
        // A very large delta could bounce many times; fold whole round trips first.
        let roundTrip = range * 2
        if remaining > roundTrip {
            remaining = remaining.truncatingRemainder(dividingBy: roundTrip)
        }
        while remaining > 0 {
            let distanceToWall = direction > 0 ? maximum - position : position - minimum
            if remaining <= distanceToWall {
                position += direction * remaining
                remaining = 0
            } else {
                position = direction > 0 ? maximum : minimum
                remaining -= distanceToWall
                direction = -direction
            }
        }
    }

    func advanced(by deltaTime: TimeInterval) -> TowerStackMovingBlock {
        var copy = self
        copy.advance(by: deltaTime)
        return copy
    }

    /// Time until the centre reaches `target` on the current heading, or `nil` if the block
    /// would have to reverse first. Used by the deterministic auto-place test mode.
    func timeToReach(_ target: CGFloat) -> TimeInterval? {
        guard speed > 0 else { return nil }
        let distance = (target - position) * direction
        guard distance >= 0, target >= minimum - 1e-9, target <= maximum + 1e-9 else { return nil }
        return TimeInterval(distance / speed)
    }
}

/// Speed as a function of score. The reference shows a linear rise (≈ +0.7 %/point, no steps,
/// no visible cap up to 173).
struct TowerStackDifficultyModel: Equatable {
    let config: TowerStackGameConfig

    init(config: TowerStackGameConfig) {
        self.config = config
    }

    func speed(forScore score: Int) -> CGFloat {
        let raw = config.initialSpeed * (1 + config.speedGrowthPerPoint * CGFloat(max(0, score)))
        return min(config.maximumSpeed, raw)
    }

    /// Time for a freshly spawned block to travel from the far end of its path to the tower centre.
    func travelTime(forScore score: Int) -> TimeInterval {
        TimeInterval(config.movementRange / speed(forScore: score))
    }

    func cameraStepDuration(forScore score: Int) -> TimeInterval {
        max(config.minimumCameraStepDuration, travelTime(forScore: score) * TimeInterval(config.cameraStepDurationMultiplier))
    }
}
