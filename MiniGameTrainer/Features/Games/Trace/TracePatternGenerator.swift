import Foundation

struct TracePatternGenerator {
    var config: TraceGameConfig

    func generate(
        field: TraceHexField,
        length: Int,
        rng: inout some RandomNumberGenerator
    ) -> [TraceNode] {
        let target = min(max(length, 1), field.nodeCount)
        guard target > 0, field.nodeCount > 0 else { return [] }
        let nodes = field.allNodes
        for _ in 0..<max(1, config.generatorRestartLimit) {
            guard let start = nodes.randomElement(using: &rng) else { break }
            if let path = walk(from: start, length: target, field: field, rng: &rng) {
                return path
            }
        }
        return guaranteedPath(field: field, length: target)
    }

    func isValid(_ sequence: [TraceNode], field: TraceHexField, requireAdjacent: Bool) -> Bool {
        guard !sequence.isEmpty else { return false }
        var seen = Set<TraceNode>()
        for index in sequence.indices {
            let node = sequence[index]
            guard field.contains(node), !seen.contains(node) else { return false }
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
        field: TraceHexField,
        rng: inout some RandomNumberGenerator
    ) -> [TraceNode]? {
        guard field.contains(start) else { return nil }
        if length <= 1 { return [start] }
        var path = [start]
        var used: Set<TraceNode> = [start]
        var optionStack = [shuffledOptions(from: start, used: used, field: field, rng: &rng)]

        while path.count < length {
            guard var options = optionStack.popLast() else { return nil }
            if options.isEmpty {
                if path.count <= 1 { return nil }
                used.remove(path.removeLast())
                continue
            }
            let next = options.removeFirst()
            optionStack.append(options)
            path.append(next)
            used.insert(next)
            optionStack.append(shuffledOptions(from: next, used: used, field: field, rng: &rng))
        }
        return path
    }

    private func shuffledOptions(
        from node: TraceNode,
        used: Set<TraceNode>,
        field: TraceHexField,
        rng: inout some RandomNumberGenerator
    ) -> [TraceNode] {
        var options = TraceHexNeighbors.neighbors(of: node)
            .filter { field.contains($0) && !used.contains($0) }
        options.shuffle(using: &rng)
        return options
    }

    /// Deterministic complete-length fallback. Never returns a short target.
    private func guaranteedPath(field: TraceHexField, length: Int) -> [TraceNode] {
        let starts = field.allNodes.sorted()
        for start in starts {
            var rng = AnyRandomNumberGenerator.seeded(1)
            if let path = walk(from: start, length: length, field: field, rng: &rng) {
                return path
            }
        }
        var used = Set<TraceNode>()
        var path: [TraceNode] = []
        var current = starts.first ?? TraceNode(q: 0, r: 0)
        path.append(current)
        used.insert(current)
        while path.count < length {
            let options = TraceHexNeighbors.neighbors(of: current)
                .filter { field.contains($0) && !used.contains($0) }
                .sorted()
            guard let next = options.first else { break }
            path.append(next)
            used.insert(next)
            current = next
        }
        return path
    }
}
