import CoreGraphics
import Foundation

struct KeepUpBouncePerformance: Equatable {
    let score: Int
    let ballPosition: CGPoint
    let platformPosition: CGPoint
    let impactOffset: CGFloat
    let normalizedImpactOffset: CGFloat
    let incomingVelocity: CGVector
    let outgoingVelocity: CGVector
    let platformVelocity: CGVector
    let contactNormal: CGVector
    let bounceDuration: TimeInterval
}

struct KeepUpSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let bounces: [KeepUpBouncePerformance]
    let peakBallSpeed: CGFloat
    let platformTravel: CGFloat

    var averageCatchError: CGFloat? { average(bounces.map { abs($0.normalizedImpactOffset) }) }
    var bestCatchError: CGFloat? { bounces.map { abs($0.normalizedImpactOffset) }.min() }
    var closestSaveError: CGFloat? { bounces.map { abs($0.normalizedImpactOffset) }.max() }
    var averageHorizontalCorrection: CGFloat? { average(bounces.map { abs($0.outgoingVelocity.dx - $0.incomingVelocity.dx) }) }

    private func average(_ values: [CGFloat]) -> CGFloat? {
        values.isEmpty ? nil : values.reduce(0, +) / CGFloat(values.count)
    }
}

struct KeepUpPerformanceTracker {
    private(set) var bounces: [KeepUpBouncePerformance] = []
    private(set) var peakBallSpeed: CGFloat = 0
    private(set) var platformTravel: CGFloat = 0

    mutating func recordBallVelocity(_ velocity: CGVector) {
        peakBallSpeed = max(peakBallSpeed, hypot(velocity.dx, velocity.dy))
    }

    mutating func recordPlatformMovement(_ distance: CGFloat) {
        platformTravel += abs(distance)
    }

    mutating func recordBounce(_ bounce: KeepUpBouncePerformance) { bounces.append(bounce) }
    mutating func reset() { self = KeepUpPerformanceTracker() }
}
