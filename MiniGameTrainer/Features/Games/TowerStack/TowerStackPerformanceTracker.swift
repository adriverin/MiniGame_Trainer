import CoreGraphics
import Foundation

/// Accumulates per-placement precision data for the results screen. Keeps only aggregates plus the
/// last placement so memory stays constant regardless of tower height.
struct TowerStackPerformanceTracker {
    private(set) var successfulPlacements = 0
    private(set) var nearPerfectPlacements = 0
    private(set) var highestSpeed: CGFloat = 0
    private(set) var lastPlacement: TowerStackPlacement?
    private var overlapSum: Double = 0
    private var offsetSum: Double = 0
    private var bestOverlap: Double?
    private var worstOverlap: Double?

    mutating func reset() {
        self = TowerStackPerformanceTracker()
    }

    mutating func record(_ placement: TowerStackPlacement, perfectTolerance: CGFloat) {
        lastPlacement = placement
        highestSpeed = max(highestSpeed, placement.movementSpeed)
        guard !placement.isMiss else { return }
        successfulPlacements += 1
        let overlap = Double(placement.overlapRatio)
        overlapSum += overlap
        offsetSum += Double(placement.normalizedOffset)
        bestOverlap = max(bestOverlap ?? overlap, overlap)
        worstOverlap = min(worstOverlap ?? overlap, overlap)
        if placement.normalizedOffset <= perfectTolerance {
            nearPerfectPlacements += 1
        }
    }

    var averageOverlapRatio: Double? {
        successfulPlacements > 0 ? overlapSum / Double(successfulPlacements) : nil
    }

    var averageNormalizedOffset: Double? {
        successfulPlacements > 0 ? offsetSum / Double(successfulPlacements) : nil
    }

    var bestOverlapRatio: Double? { bestOverlap }
    var worstOverlapRatio: Double? { worstOverlap }
}
