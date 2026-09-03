import Foundation

struct TracePatternGenerator {
    var config: TraceGameConfig

    func generate(
        grid: TraceGridSize,
        length: Int,
        rng: inout some RandomNumberGenerator
    ) -> [TraceNode] {
        let target = min(max(length, 1), grid.nodeCount)
        guard target > 0, grid.nodeCount > 0 else { return [] }
        let nodes = grid.allNodes
        for _ in 0..<max(1, config.generatorRestartLimit) {
            guard let start = nodes.randomElement(using: &rng) else { break }
            if let path = walk(from: start, length: target, grid: grid, rng: &rng) {
                return path
            }
        }
        return fallbackPath(grid: grid, length: target)
    }

    func isValid(_ sequence: [TraceNode], grid: TraceGridSize, requireAdjacent: Bool) -> Bool {
        guard !sequence.isEmpty else { return false }
        var seen = Set<TraceNode>()
        for index in sequence.indices {
            let node = sequence[index]
            guard grid.contains(node), !seen.contains(node) else { return false }
            if index > 0 {
                let previous = sequence[index - 1]
                if previous == node { return false }
                if requireAdjacent, !TraceHexNeighbors.isNeighbor(previous, node) { return false }
            }
            seen.insert(node)
        }
        return true
    }

    private func walk(
        from start: TraceNode,
        length: Int,
        grid: TraceGridSize,
        rng: inout some RandomNumberGenerator
    ) -> [TraceNode]? {
        var path = [start]
        var used: Set<TraceNode> = [start]
        while path.count < length {
            let options = TraceHexNeighbors.neighbors(of: path[path.count - 1])
                .filter { grid.contains($0) && !used.contains($0) }
            guard let next = options.randomElement(using: &rng) else { return nil }
            path.append(next)
            used.insert(next)
        }
        return path
    }

    private func fallbackPath(grid: TraceGridSize, length: Int) -> [TraceNode] {
        var path: [TraceNode] = []
        var used = Set<TraceNode>()
        let start = TraceNode(row: grid.rows / 2, column: 0)
        var current = grid.contains(start) ? start : TraceNode(row: 0, column: 0)
        path.append(current)
        used.insert(current)
        while path.count < length {
            let options = TraceHexNeighbors.neighbors(of: current)
                .filter { grid.contains($0) && !used.contains($0) }
                .sorted()
            guard let next = options.first else { break }
            path.append(next)
            used.insert(next)
            current = next
        }
        return path
    }
}
