import Foundation

struct ReactSessionSummary: Equatable {
    let reactionTimes: [TimeInterval]
    let validReactionTimes: [TimeInterval]
    let prematureTaps: Int
    let wrongTargetTaps: Int
    let duration: TimeInterval

    var average: TimeInterval? { reactionTimes.isEmpty ? nil : reactionTimes.reduce(0, +) / Double(reactionTimes.count) }
    var fastest: TimeInterval? { validReactionTimes.min() }
    var slowest: TimeInterval? { validReactionTimes.max() }
    var validRounds: Int { validReactionTimes.count }
    var completedRounds: Int { reactionTimes.count }

    var median: TimeInterval? {
        guard !validReactionTimes.isEmpty else { return nil }
        let sorted = validReactionTimes.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// Population standard deviation for all valid reactions in this session.
    var standardDeviation: TimeInterval? {
        guard !validReactionTimes.isEmpty else { return nil }
        let mean = validReactionTimes.reduce(0, +) / Double(validReactionTimes.count)
        let variance = validReactionTimes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(validReactionTimes.count)
        return sqrt(variance)
    }

    var spread: TimeInterval? {
        guard let fastest, let slowest else { return nil }
        return slowest - fastest
    }

    var score: Int {
        Int(((average ?? 0) * 1_000).rounded())
    }
}
