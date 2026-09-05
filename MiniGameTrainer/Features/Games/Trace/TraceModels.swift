import Foundation

struct TraceNode: Hashable, Codable, Comparable, CustomStringConvertible {
    var q: Int
    var r: Int

    var s: Int { -q - r }

    var description: String { "(\(q),\(r))" }

    static func < (lhs: TraceNode, rhs: TraceNode) -> Bool {
        (lhs.r, lhs.q) < (rhs.r, rhs.q)
    }
}

/// Centered hexagonal lattice of the given axial radius.
struct TraceHexField: Hashable, Codable {
    var radius: Int

    static let smallest = TraceHexField(radius: 1)

    var nodeCount: Int {
        let radius = max(0, self.radius)
        return 1 + 3 * radius * (radius + 1)
    }

    /// Pointy-top rows from r = -radius (top) to r = +radius (bottom).
    var rowCounts: [Int] {
        let radius = max(0, self.radius)
        return (-radius...radius).map { r in
            let qMin = max(-radius, -radius - r)
            let qMax = min(radius, radius - r)
            return qMax - qMin + 1
        }
    }

    var allNodes: [TraceNode] {
        let radius = max(0, self.radius)
        var nodes: [TraceNode] = []
        nodes.reserveCapacity(nodeCount)
        for r in -radius...radius {
            let qMin = max(-radius, -radius - r)
            let qMax = min(radius, radius - r)
            for q in qMin...qMax {
                nodes.append(TraceNode(q: q, r: r))
            }
        }
        return nodes
    }

    func contains(_ node: TraceNode) -> Bool {
        max(abs(node.q), abs(node.r), abs(node.s)) <= radius
    }
}

enum TracePhase: String, Equatable {
    case ready
    case showingPattern
    case awaitingTrace
    case tracing
    case evaluating
    case transitioning
    case paused
    case gameOver
}

enum TraceFailureReason: String, Equatable {
    case wrongNode
    case incompleteLift
    case recallTimeout
    case sessionTimeout
}

enum TraceAcceptResult: Equatable {
    case ignored
    case duplicate
    case accepted(node: TraceNode, scoreDelta: Int, completed: Bool)
    case rejected
}

enum TraceEvent: Equatable {
    case patternStarted(sequence: [TraceNode], field: TraceHexField)
    case revealAdvanced(visibleCount: Int)
    case patternHidden
    case nodeAccepted(TraceNode, scoreDelta: Int)
    case patternCompleted
    case patternFailed(TraceFailureReason)
    case sessionEnded
}

struct TraceRoundRecord: Equatable {
    var scoreBefore: Int
    var scoreAfter: Int
    var field: TraceHexField
    var targetCount: Int
    var completed: Bool
    var failure: TraceFailureReason?
}

struct TraceSessionSummary: Equatable {
    var score: Int
    var duration: TimeInterval
    var patternsCompleted: Int
    var patternsFailed: Int
    var segmentsScored: Int
    var accuracy: Double?
}
