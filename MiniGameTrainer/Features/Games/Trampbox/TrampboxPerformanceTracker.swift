import CoreGraphics
import Foundation

struct TrampboxPerformanceTracker {
    private(set) var landings: [TrampboxLandingPerformance] = []

    mutating func record(_ landing: TrampboxLandingPerformance) {
        landings.append(landing)
    }

    mutating func reset() {
        landings.removeAll(keepingCapacity: true)
    }

    func summary(
        score: Int,
        duration: TimeInterval,
        finalBounceDuration: TimeInterval,
        reason: TrampboxGameOverReason
    ) -> TrampboxSessionSummary {
        let precisions = landings.map(\.precision)
        let errors = landings.map(\.horizontalError).sorted()
        let averagePrecision = precisions.isEmpty ? nil : precisions.reduce(0, +) / Double(precisions.count)
        let bestPrecision = precisions.max()
        let closestEdgeSave = landings.map { max(0, $0.platformWidth / 2 - $0.horizontalError) }.min()
        let averageWidth = landings.isEmpty ? nil : landings.map(\.platformWidth).reduce(0, +) / CGFloat(landings.count)

        let medianError: CGFloat?
        if errors.isEmpty {
            medianError = nil
        } else if errors.count.isMultiple(of: 2) {
            medianError = (errors[errors.count / 2 - 1] + errors[errors.count / 2]) / 2
        } else {
            medianError = errors[errors.count / 2]
        }

        return TrampboxSessionSummary(
            score: score,
            duration: duration,
            landings: landings.count,
            averagePrecision: averagePrecision,
            medianLandingError: medianError,
            bestPrecision: bestPrecision,
            closestEdgeSave: closestEdgeSave,
            averagePlatformWidth: averageWidth,
            finalBounceDuration: finalBounceDuration,
            reason: reason
        )
    }
}
