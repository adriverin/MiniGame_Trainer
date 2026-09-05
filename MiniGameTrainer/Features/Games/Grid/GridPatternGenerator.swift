import Foundation

/// Samples unique GRID cells without replacement and avoids recent target sets.
///
/// Production uses `SystemRandomNumberGenerator` via a `nil` seed. Tests inject a
/// `SeededRandomNumberGenerator` through the same initializer.
struct GridPatternGenerator {
    static let recentHistoryLimit = 5
    static let maxRegenerationAttempts = 16

    private var rng: AnyRandomNumberGenerator
    private(set) var recentPatterns: [Set<GridCell>] = []

    init(seed: UInt64? = nil) {
        rng = .seeded(seed)
    }

    mutating func reset(using seed: UInt64?) {
        rng = .seeded(seed)
        recentPatterns.removeAll(keepingCapacity: true)
    }

    /// Records `patterns` as the most recent target sets (test hook).
    mutating func preloadRecent(_ patterns: [Set<GridCell>]) {
        recentPatterns = Array(patterns.suffix(Self.recentHistoryLimit))
    }

    mutating func nextPattern(
        rows: Int,
        columns: Int,
        count: Int,
        forced: Set<GridCell>? = nil
    ) -> Set<GridCell> {
        if let forced {
            let clipped = Self.clipped(forced, rows: rows, columns: columns)
            if !clipped.isEmpty {
                record(clipped)
                return clipped
            }
        }

        var candidate = Self.sample(rows: rows, columns: columns, count: count, generator: &rng)
        var attempts = 0
        while shouldRegenerate(candidate, rows: rows, columns: columns, count: count),
              attempts < Self.maxRegenerationAttempts {
            candidate = Self.sample(rows: rows, columns: columns, count: count, generator: &rng)
            attempts += 1
        }
        record(candidate)
        return candidate
    }

    /// One-shot unique-cell sample. Does not consult or update recent-pattern history.
    static func sample(
        rows: Int,
        columns: Int,
        count: Int,
        generator: inout some RandomNumberGenerator,
        forced: Set<GridCell>? = nil
    ) -> Set<GridCell> {
        let boundedRows = max(1, rows)
        let boundedColumns = max(1, columns)
        let cap = boundedRows * boundedColumns
        if let forced {
            let clipped = clipped(forced, rows: boundedRows, columns: boundedColumns)
            if !clipped.isEmpty { return clipped }
        }
        let target = min(max(1, count), cap)
        var pool: [GridCell] = []
        pool.reserveCapacity(cap)
        for row in 0..<boundedRows {
            for column in 0..<boundedColumns {
                pool.append(GridCell(row: row, column: column))
            }
        }
        pool.shuffle(using: &generator)
        return Set(pool.prefix(target))
    }

    static func combinationCount(cells: Int, choose count: Int) -> Int {
        let n = max(0, cells)
        let k = max(0, min(count, n))
        if n == 0 { return 0 }
        if k == 0 || k == n { return 1 }
        let take = min(k, n - k)
        var result = 1
        for index in 0..<take {
            let numerator = n - index
            if numerator > 0, result > Int.max / numerator { return Int.max }
            result = result * numerator / (index + 1)
        }
        return result
    }

    private mutating func record(_ pattern: Set<GridCell>) {
        recentPatterns.append(pattern)
        if recentPatterns.count > Self.recentHistoryLimit {
            recentPatterns.removeFirst(recentPatterns.count - Self.recentHistoryLimit)
        }
    }

    private func shouldRegenerate(_ candidate: Set<GridCell>, rows: Int, columns: Int, count: Int) -> Bool {
        guard recentPatterns.contains(candidate) else { return false }
        let cells = max(1, rows) * max(1, columns)
        let target = min(max(1, count), cells)
        let combinations = Self.combinationCount(cells: cells, choose: target)
        return combinations > recentPatterns.count
    }

    private static func clipped(_ forced: Set<GridCell>, rows: Int, columns: Int) -> Set<GridCell> {
        let boundedRows = max(1, rows)
        let boundedColumns = max(1, columns)
        return Set(forced.filter {
            (0..<boundedRows).contains($0.row) && (0..<boundedColumns).contains($0.column)
        })
    }
}
