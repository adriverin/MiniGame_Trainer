import Foundation

struct TraceDifficultyModel: Equatable {
    var config: TraceGameConfig

    func grid(forScore score: Int) -> TraceGridSize {
        let index = stageIndex(forScore: max(0, score))
        let rows = config.gridAnchorRows.indices.contains(index) ? config.gridAnchorRows[index] : (config.gridAnchorRows.last ?? 3)
        let columns = config.gridAnchorColumns.indices.contains(index) ? config.gridAnchorColumns[index] : (config.gridAnchorColumns.last ?? 2)
        return TraceGridSize(rows: max(1, rows), columns: max(1, columns))
    }

    func typicalPathLength(forScore score: Int) -> Int {
        let index = stageIndex(forScore: max(0, score))
        return config.pathTypicalCounts.indices.contains(index)
            ? config.pathTypicalCounts[index]
            : (config.pathTypicalCounts.last ?? config.minimumPathLength)
    }

    func pathLengthRange(forScore score: Int, grid: TraceGridSize) -> ClosedRange<Int> {
        let typical = typicalPathLength(forScore: score)
        let jitter = max(0, config.pathLengthJitter)
        let upperBound = max(2, min(config.maximumPathLength, grid.nodeCount))
        let lower = min(max(config.minimumPathLength, typical - jitter), upperBound)
        let upper = min(max(lower, typical + jitter), upperBound)
        return lower...upper
    }

    func samplePathLength(forScore score: Int, grid: TraceGridSize, rng: inout some RandomNumberGenerator) -> Int {
        let range = pathLengthRange(forScore: score, grid: grid)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int.random(in: 0...span, using: &rng)
    }

    func recallDuration(segmentCount: Int) -> TimeInterval {
        max(0.5, config.recallBaseDuration + config.recallDurationPerSegment * TimeInterval(max(0, segmentCount)))
    }

    func presentationDuration(nodeCount: Int) -> TimeInterval {
        let segments = max(0, nodeCount - 1)
        return TimeInterval(segments) * max(0, config.segmentRevealDuration) + max(0, config.patternHoldDuration)
    }

    func stageIndex(forScore score: Int) -> Int {
        let anchors = config.gridAnchorScores
        guard !anchors.isEmpty else { return 0 }
        var index = 0
        for candidate in anchors.indices where anchors[candidate] <= score {
            index = candidate
        }
        return index
    }
}

enum TraceHexNeighbors {
    /// Odd-r horizontal layout: even rows unshifted, odd rows shifted +0.5 column.
    static func neighbors(of node: TraceNode) -> [TraceNode] {
        let even = [(1, 0), (-1, 0), (0, -1), (-1, -1), (0, 1), (-1, 1)]
        let odd = [(1, 0), (-1, 0), (1, -1), (0, -1), (1, 1), (0, 1)]
        let deltas = node.row & 1 == 0 ? even : odd
        return deltas.map { TraceNode(row: node.row + $0.1, column: node.column + $0.0) }
    }

    static func isNeighbor(_ a: TraceNode, _ b: TraceNode) -> Bool {
        neighbors(of: a).contains(b)
    }
}
