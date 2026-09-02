import CoreGraphics
import Foundation

/// Per-tile training record.
struct TilePerformance: Equatable {
    let tileID: UUID
    let lane: Int
    /// Seconds between the tile entering the playfield and the tap. `nil` for misses.
    let reactionTime: TimeInterval?
    /// Where the tile's bottom edge was when tapped: 0 = playfield top, 1 = miss line.
    let tapDepth: CGFloat?
    let successful: Bool
}

/// Aggregated session metrics produced at game over.
struct PianoSessionSummary: Equatable {
    var score: Int = 0
    var duration: TimeInterval = 0
    var correctTaps: Int = 0
    var missedTiles: Int = 0
    var wrongTaps: Int = 0
    var averageReactionTime: TimeInterval?
    var medianReactionTime: TimeInterval?
    var bestReactionTime: TimeInterval?
    var averageTapDepth: CGFloat?
    /// Highest scroll speed reached, in scene heights per second.
    var peakSpeed: CGFloat = 0
    var reason: PianoGameOverReason = .aborted

    /// Correct taps over all evaluated actions (misses and wrong taps count against it).
    var accuracy: Double? {
        let total = correctTaps + missedTiles + wrongTaps
        guard total > 0 else { return nil }
        return Double(correctTaps) / Double(total)
    }

    var tapsPerSecond: Double? {
        guard duration > 0 else { return nil }
        return Double(correctTaps) / duration
    }
}

/// Collects raw tile outcomes during play and reduces them into a `PianoSessionSummary`.
struct PianoPerformanceTracker: Equatable {
    private(set) var records: [TilePerformance] = []
    private(set) var wrongTaps: Int = 0

    mutating func recordHit(_ tile: PianoTile) {
        records.append(TilePerformance(
            tileID: tile.id,
            lane: tile.lane,
            reactionTime: tile.reactionTime,
            tapDepth: tile.tapDepth,
            successful: true
        ))
    }

    mutating func recordMiss(_ tile: PianoTile) {
        records.append(TilePerformance(tileID: tile.id, lane: tile.lane, reactionTime: nil, tapDepth: nil, successful: false))
    }

    mutating func recordWrongTap() {
        wrongTaps += 1
    }

    mutating func reset() {
        records.removeAll(keepingCapacity: true)
        wrongTaps = 0
    }

    func summary(score: Int, duration: TimeInterval, peakSpeed: CGFloat, reason: PianoGameOverReason) -> PianoSessionSummary {
        var summary = PianoSessionSummary()
        summary.score = score
        summary.duration = duration
        summary.peakSpeed = peakSpeed
        summary.reason = reason
        summary.correctTaps = records.filter(\.successful).count
        summary.missedTiles = records.count - summary.correctTaps
        summary.wrongTaps = wrongTaps

        // Misses have no reaction time and are excluded from the averages by construction.
        let reactions = records.compactMap(\.reactionTime).sorted()
        if !reactions.isEmpty {
            summary.averageReactionTime = reactions.reduce(0, +) / Double(reactions.count)
            summary.bestReactionTime = reactions[0]
            let mid = reactions.count / 2
            summary.medianReactionTime = reactions.count.isMultiple(of: 2)
                ? (reactions[mid - 1] + reactions[mid]) / 2
                : reactions[mid]
        }
        let depths = records.compactMap(\.tapDepth)
        if !depths.isEmpty {
            summary.averageTapDepth = depths.reduce(0, +) / CGFloat(depths.count)
        }
        return summary
    }
}
