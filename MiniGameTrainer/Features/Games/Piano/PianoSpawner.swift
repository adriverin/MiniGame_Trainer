import Foundation

/// Lane pattern generator reproducing the rules observed in the reference:
/// - a row's primary lane never repeats the previous row's primary lane,
/// - after `doubleTileUnlockScore`, a row gains a second tile in another lane with probability
///   `doubleTileProbability` (that extra lane is unrestricted).
struct PianoSpawner {
    struct RowPlan: Equatable {
        let primaryLane: Int
        let extraLane: Int?

        var lanes: [Int] {
            [primaryLane] + (extraLane.map { [$0] } ?? [])
        }
    }

    private(set) var previousPrimaryLane: Int?
    private var rng: AnyRandomNumberGenerator
    private let laneCount: Int
    private let allowSameLane: Bool
    private let doubleUnlockScore: Int
    private let doubleProbability: Double

    init(config: PianoGameConfig) {
        laneCount = max(1, config.laneCount)
        allowSameLane = config.allowSameLaneAsPrevious || config.laneCount < 2
        doubleUnlockScore = config.doubleTileUnlockScore
        doubleProbability = min(1, max(0, config.doubleTileProbability))
        rng = .seeded(config.randomSeed)
    }

    mutating func nextRow(score: Int) -> RowPlan {
        let primary = nextLane(previousLane: previousPrimaryLane)
        previousPrimaryLane = primary

        var extra: Int?
        if laneCount > 1, score >= doubleUnlockScore, doubleProbability > 0,
           Double.random(in: 0..<1, using: &rng) < doubleProbability {
            extra = randomLane(excluding: primary)
        }
        return RowPlan(primaryLane: primary, extraLane: extra)
    }

    /// Picks a lane for a single tile given the previous row's primary lane.
    mutating func nextLane(previousLane: Int?) -> Int {
        if allowSameLane || previousLane == nil {
            return Int.random(in: 0..<laneCount, using: &rng)
        }
        return randomLane(excluding: previousLane)
    }

    private mutating func randomLane(excluding excluded: Int?) -> Int {
        guard let excluded, laneCount > 1 else {
            return Int.random(in: 0..<laneCount, using: &rng)
        }
        let index = Int.random(in: 0..<(laneCount - 1), using: &rng)
        return index >= excluded ? index + 1 : index
    }
}
