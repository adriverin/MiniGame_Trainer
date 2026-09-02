import CoreGraphics
import Foundation

/// Horizontal world axis a block slides along. Successive blocks alternate.
enum TowerStackAxis: String, Equatable, CaseIterable, Codable {
    case x
    case z

    var next: TowerStackAxis { self == .x ? .z : .x }
    var displayName: String { rawValue.uppercased() }
}

/// A point in world space. X/Z are horizontal, Y is up. Units are block widths.
struct TowerStackWorldPoint: Equatable {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    static let zero = TowerStackWorldPoint(x: 0, y: 0, z: 0)

    static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z) }
    static func - (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z) }
    static func * (lhs: Self, rhs: CGFloat) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs) }

    func dot(_ other: Self) -> CGFloat { x * other.x + y * other.y + z * other.z }

    func cross(_ o: Self) -> Self {
        .init(x: y * o.z - z * o.y, y: z * o.x - x * o.z, z: x * o.y - y * o.x)
    }

    var length: CGFloat { sqrt(dot(self)) }
    var normalized: Self { length > 0 ? self * (1 / length) : self }

    func interpolated(to other: Self, progress: CGFloat) -> Self {
        self + (other - self) * progress
    }
}

/// Closed interval on one axis.
struct TowerStackInterval: Equatable {
    var minimum: CGFloat
    var maximum: CGFloat

    init(minimum: CGFloat, maximum: CGFloat) {
        self.minimum = minimum
        self.maximum = maximum
    }

    init(center: CGFloat, length: CGFloat) {
        minimum = center - length / 2
        maximum = center + length / 2
    }

    var length: CGFloat { maximum - minimum }
    var center: CGFloat { (minimum + maximum) / 2 }

    /// Geometric intersection; `length` is ≤ 0 when the intervals do not overlap.
    func intersection(_ other: TowerStackInterval) -> TowerStackInterval {
        TowerStackInterval(minimum: max(minimum, other.minimum), maximum: min(maximum, other.maximum))
    }
}

/// Logical footprint of a tower layer: an axis-aligned rectangle in the horizontal X/Z plane.
struct TowerStackFootprint: Equatable {
    var centerX: CGFloat
    var centerZ: CGFloat
    var width: CGFloat
    var depth: CGFloat

    func center(along axis: TowerStackAxis) -> CGFloat {
        axis == .x ? centerX : centerZ
    }

    func dimension(along axis: TowerStackAxis) -> CGFloat {
        axis == .x ? width : depth
    }

    func interval(along axis: TowerStackAxis) -> TowerStackInterval {
        TowerStackInterval(center: center(along: axis), length: dimension(along: axis))
    }

    /// Returns a copy whose extent along `axis` is replaced by `interval`; the other axis is kept.
    func replacing(_ interval: TowerStackInterval, along axis: TowerStackAxis) -> TowerStackFootprint {
        var copy = self
        switch axis {
        case .x:
            copy.centerX = interval.center
            copy.width = interval.length
        case .z:
            copy.centerZ = interval.center
            copy.depth = interval.length
        }
        return copy
    }

    func moved(to position: CGFloat, along axis: TowerStackAxis) -> TowerStackFootprint {
        var copy = self
        if axis == .x { copy.centerX = position } else { copy.centerZ = position }
        return copy
    }

    var minX: CGFloat { centerX - width / 2 }
    var maxX: CGFloat { centerX + width / 2 }
    var minZ: CGFloat { centerZ - depth / 2 }
    var maxZ: CGFloat { centerZ + depth / 2 }

    var isNumericallyValid: Bool {
        [centerX, centerZ, width, depth].allSatisfy { $0.isFinite } && width > 0 && depth > 0
    }
}

/// Result of comparing an incoming block against the tower top along the active axis.
struct TowerStackPlacementResolution: Equatable {
    /// Footprint that stays on the tower, or `nil` when there was no valid overlap.
    let surviving: TowerStackFootprint?
    /// Overhanging part(s) removed from the incoming block. Empty on a perfect placement or a miss.
    let cutPieces: [TowerStackFootprint]
    /// Intersection length along the active axis (≤ 0 on a miss).
    let overlapLength: CGFloat
    /// `overlapLength / target dimension`, clamped to 0…1.
    let overlapRatio: CGFloat
    /// Signed centre offset incoming − target along the active axis, in world units.
    let offset: CGFloat
    /// `|offset| / target dimension`.
    let normalizedOffset: CGFloat

    var isMiss: Bool { surviving == nil }
}

/// Pure intersection mathematics. No SpriteKit, no state.
enum TowerStackPlacementResolver {
    static func resolve(
        incoming: TowerStackFootprint,
        target: TowerStackFootprint,
        axis: TowerStackAxis,
        overlapTolerance: CGFloat,
        minimumViableDimension: CGFloat
    ) -> TowerStackPlacementResolution {
        let incomingInterval = incoming.interval(along: axis)
        let targetInterval = target.interval(along: axis)
        let overlap = incomingInterval.intersection(targetInterval)
        let targetLength = max(targetInterval.length, .leastNonzeroMagnitude)
        let offset = incomingInterval.center - targetInterval.center
        let normalizedOffset = abs(offset) / targetLength

        guard overlap.length > overlapTolerance, overlap.length >= minimumViableDimension else {
            return TowerStackPlacementResolution(
                surviving: nil,
                cutPieces: [],
                overlapLength: overlap.length,
                overlapRatio: 0,
                offset: offset,
                normalizedOffset: normalizedOffset
            )
        }

        var pieces: [TowerStackFootprint] = []
        if incomingInterval.minimum < overlap.minimum - overlapTolerance {
            pieces.append(incoming.replacing(
                TowerStackInterval(minimum: incomingInterval.minimum, maximum: overlap.minimum),
                along: axis
            ))
        }
        if incomingInterval.maximum > overlap.maximum + overlapTolerance {
            pieces.append(incoming.replacing(
                TowerStackInterval(minimum: overlap.maximum, maximum: incomingInterval.maximum),
                along: axis
            ))
        }

        return TowerStackPlacementResolution(
            surviving: incoming.replacing(overlap, along: axis),
            cutPieces: pieces,
            overlapLength: overlap.length,
            overlapRatio: min(1, max(0, overlap.length / targetLength)),
            offset: offset,
            normalizedOffset: normalizedOffset
        )
    }
}
