import Foundation

struct TraceNode: Hashable, Codable, Comparable, CustomStringConvertible {
    var row: Int
    var column: Int

    var description: String { "(\(row),\(column))" }

    static func < (lhs: TraceNode, rhs: TraceNode) -> Bool {
        (lhs.row, lhs.column) < (rhs.row, rhs.column)
    }
}

struct TraceGridSize: Hashable, Codable {
    var rows: Int
    var columns: Int

    var nodeCount: Int { max(0, rows) * max(0, columns) }

    var allNodes: [TraceNode] {
        guard rows > 0, columns > 0 else { return [] }
        return (0..<rows).flatMap { row in (0..<columns).map { TraceNode(row: row, column: $0) } }
    }

    func contains(_ node: TraceNode) -> Bool {
        node.row >= 0 && node.row < rows && node.column >= 0 && node.column < columns
    }

    static let smallest = TraceGridSize(rows: 3, columns: 2)
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
    case patternStarted(sequence: [TraceNode], grid: TraceGridSize)
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
    var grid: TraceGridSize
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
