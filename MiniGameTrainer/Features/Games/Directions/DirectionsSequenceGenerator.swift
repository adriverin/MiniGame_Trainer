import CoreGraphics
import Foundation

enum Direction: String, Equatable, CaseIterable, Codable {
    case up
    case right
    case down
    case left

    var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    var zRotation: CGFloat {
        switch self {
        case .up: 0
        case .left: .pi / 2
        case .down: .pi
        case .right: -.pi / 2
        }
    }

    var accessibilityName: String {
        rawValue.capitalized
    }
}

/// Independent per-round sequences. Consecutive repeats are allowed because they appear in
/// the reference (including four LEFT in a row at level 10).
struct DirectionsSequenceGenerator: Equatable {
    let config: DirectionsGameConfig

    func generate(
        length: Int,
        rng: inout some RandomNumberGenerator
    ) -> [Direction] {
        let count = max(1, length)
        let options = Direction.allCases
        var sequence: [Direction] = []
        sequence.reserveCapacity(count)
        for _ in 0..<count {
            let direction = options.randomElement(using: &rng) ?? .up
            if !config.allowsConsecutiveRepeats, let last = sequence.last, direction == last {
                sequence.append(direction.opposite)
            } else {
                sequence.append(direction)
            }
        }
        return sequence
    }
}
