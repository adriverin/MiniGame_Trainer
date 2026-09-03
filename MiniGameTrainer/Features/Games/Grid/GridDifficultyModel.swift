import Foundation

struct GridStage: Equatable {
    let level: Int
    let rows: Int
    let columns: Int
    let targetCount: Int
    let presentationDuration: TimeInterval
    let recallTimeout: TimeInterval

    var totalCells: Int { rows * columns }
}

/// Level schedule measured from the GRID reference recording (see GRID_GAME_ANALYSIS.md).
enum GridDifficultyModel {
    /// Score deltas after each correct round in the recording, used as target-cell counts.
    static let referenceTargetCounts: [Int: Int] = [
        1: 4, 2: 6, 3: 6, 4: 12, 5: 13, 6: 19, 7: 17, 8: 20, 9: 23, 10: 28,
    ]

    static func gridSize(forLevel level: Int) -> (rows: Int, columns: Int) {
        switch max(1, level) {
        case 1...2: return (3, 3)
        case 3...4: return (4, 4)
        case 5...6: return (5, 5)
        case 7...9: return (6, 6)
        default: return (7, 7)
        }
    }

    static func targetCount(forLevel level: Int, rows: Int, columns: Int) -> Int {
        let cap = max(1, rows * columns - 1)
        if let counted = referenceTargetCounts[level] {
            return min(max(1, counted), cap)
        }
        return min(cap, 28 + max(0, level - 10) * 2)
    }

    static func stage(forLevel level: Int, config: GridGameConfig) -> GridStage {
        let resolved = max(1, level)
        let size = gridSize(forLevel: resolved)
        return GridStage(
            level: resolved,
            rows: size.rows,
            columns: size.columns,
            targetCount: targetCount(forLevel: resolved, rows: size.rows, columns: size.columns),
            presentationDuration: max(0.05, config.presentationDuration),
            recallTimeout: max(0.05, config.recallTimeout)
        )
    }

    /// 3×3 QA pattern: top-left, center, bottom-right.
    static let qualityAssurancePattern: Set<GridCell> = [
        GridCell(row: 0, column: 0),
        GridCell(row: 1, column: 1),
        GridCell(row: 2, column: 2),
    ]

    static func generatePattern(
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
            let clipped = Set(forced.filter { (0..<boundedRows).contains($0.row) && (0..<boundedColumns).contains($0.column) })
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
}
