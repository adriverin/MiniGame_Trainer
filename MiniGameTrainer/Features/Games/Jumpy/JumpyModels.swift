import CoreGraphics
import Foundation

enum JumpyMove: Equatable {
    case up, down, left, right
}

enum JumpyFacing: Equatable {
    case up, down, left, right
}

struct JumpyGridPosition: Equatable {
    var row: Int
    var column: Int
}

enum JumpyGestureInterpreter {
    static func move(from start: CGPoint, to end: CGPoint, threshold: CGFloat) -> JumpyMove {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard hypot(dx, dy) >= threshold else { return .up }
        if abs(dx) > abs(dy) { return dx < 0 ? .left : .right }
        return dy < 0 ? .down : .up
    }
}

enum JumpyLaneDirection: Int, Equatable {
    case left = -1
    case right = 1
}

struct JumpyLane: Equatable {
    let id: Int
    let worldRow: Int
    let direction: JumpyLaneDirection
    let speed: CGFloat
    let vehicleWidth: CGFloat
    let vehicleOffsets: [CGFloat]
    let groupStartIndices: [Int]
    let cycleLength: CGFloat
    var phase: CGFloat

    var vehicleCount: Int { vehicleOffsets.count }

    func vehicleCenters(margin: CGFloat) -> [CGFloat] {
        let lower = -margin
        return vehicleOffsets.map { offset in
            lower + positiveModulo(phase + offset, cycleLength)
        }
    }

    mutating func advance(by deltaTime: TimeInterval, margin: CGFloat) {
        phase = positiveModulo(phase + CGFloat(direction.rawValue) * speed * deltaTime, cycleLength)
    }

    func bumperGaps() -> [CGFloat] {
        let sorted = vehicleOffsets.sorted()
        guard let first = sorted.first, let last = sorted.last else { return [] }
        var gaps = zip(sorted, sorted.dropFirst()).map { $1 - $0 - vehicleWidth }
        gaps.append(cycleLength - last + first - vehicleWidth)
        return gaps
    }
}

enum JumpyRowKind: Equatable {
    case safe
    case road(JumpyLane)
}

struct JumpyWorldRow: Equatable {
    let worldRow: Int
    var kind: JumpyRowKind
}

struct JumpyHop: Equatable {
    let from: JumpyGridPosition
    let to: JumpyGridPosition
    let move: JumpyMove
    var elapsed: TimeInterval
}

enum JumpyEvent: Equatable {
    case hopped
    case collided
}

struct JumpySessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let totalJumps: Int
    let forwardJumps: Int
    let sidewaysJumps: Int
    let backwardJumps: Int
}

func positiveModulo(_ value: CGFloat, _ modulus: CGFloat) -> CGFloat {
    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return remainder < 0 ? remainder + modulus : remainder
}

enum JumpyCollision {
    static func sweptAABB(
        playerFrom: CGPoint,
        playerTo: CGPoint,
        playerSize: CGSize,
        vehicleFrom: CGPoint,
        vehicleTo: CGPoint,
        vehicleSize: CGSize
    ) -> Bool {
        let relativeStart = CGPoint(x: playerFrom.x - vehicleFrom.x, y: playerFrom.y - vehicleFrom.y)
        let relativeEnd = CGPoint(x: playerTo.x - vehicleTo.x, y: playerTo.y - vehicleTo.y)
        let halfX = (playerSize.width + vehicleSize.width) / 2
        let halfY = (playerSize.height + vehicleSize.height) / 2
        if abs(relativeStart.x) <= halfX && abs(relativeStart.y) <= halfY { return true }

        let velocity = CGVector(dx: relativeEnd.x - relativeStart.x, dy: relativeEnd.y - relativeStart.y)
        var entry: CGFloat = 0
        var exit: CGFloat = 1
        for (origin, delta, half) in [(relativeStart.x, velocity.dx, halfX), (relativeStart.y, velocity.dy, halfY)] {
            if abs(delta) < 1e-9 {
                if abs(origin) > half { return false }
                continue
            }
            let a = (-half - origin) / delta
            let b = (half - origin) / delta
            entry = max(entry, min(a, b))
            exit = min(exit, max(a, b))
            if entry > exit { return false }
        }
        return exit >= 0 && entry <= 1
    }
}
