import Foundation

struct TraceDifficultyModel: Equatable {
    var config: TraceGameConfig

    func radius(forRoundIndex roundIndex: Int) -> Int {
        let index = max(0, roundIndex)
        let radius: Int
        if index < 2 {
            radius = 1
        } else if index < 5 {
            radius = 2
        } else {
            radius = 3
        }
        return min(max(1, radius), max(1, config.maximumBoardRadius))
    }

    func field(forRoundIndex roundIndex: Int) -> TraceHexField {
        TraceHexField(radius: radius(forRoundIndex: roundIndex))
    }

    func edgeCount(forRoundIndex roundIndex: Int) -> Int {
        max(0, roundIndex) + max(0, config.baseEdgeCount)
    }

    func nodeCount(forRoundIndex roundIndex: Int, field: TraceHexField) -> Int {
        min(edgeCount(forRoundIndex: roundIndex) + 1, field.nodeCount)
    }

    func recallDuration(segmentCount: Int) -> TimeInterval {
        max(0.5, config.recallBaseDuration + config.recallDurationPerSegment * TimeInterval(max(0, segmentCount)))
    }

    func presentationDuration(nodeCount: Int) -> TimeInterval {
        let segments = max(0, nodeCount - 1)
        return TimeInterval(segments) * max(0, config.segmentRevealDuration) + max(0, config.patternHoldDuration)
    }

    /// Largest completed-round count whose cumulative score is still ≤ `score`.
    func roundIndex(afterCompletedScore score: Int) -> Int {
        let value = max(0, score)
        var completed = 0
        while Self.cumulativeScore(afterCompletedRounds: completed + 1) <= value, completed < 256 {
            completed += 1
        }
        return completed
    }

    static func cumulativeScore(afterCompletedRounds completed: Int) -> Int {
        let n = max(0, completed)
        return n * (n + 5) / 2
    }

    static let successfulMilestones = [3, 7, 12, 18, 25, 33, 42, 52, 63, 75, 88]
}

enum TraceHexNeighbors {
    static let directions: [(q: Int, r: Int)] = [
        (1, 0), (-1, 0), (0, 1), (0, -1), (1, -1), (-1, 1),
    ]

    static func neighbors(of node: TraceNode) -> [TraceNode] {
        directions.map { TraceNode(q: node.q + $0.q, r: node.r + $0.r) }
    }

    static func isNeighbor(_ a: TraceNode, _ b: TraceNode) -> Bool {
        neighbors(of: a).contains(b)
    }
}
