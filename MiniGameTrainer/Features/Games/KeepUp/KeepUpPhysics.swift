import CoreGraphics
import Foundation

struct KeepUpCollision: Equatable {
    let point: CGPoint
    let platformPoint: CGPoint
    let normal: CGVector
    let segmentFraction: CGFloat
}

enum KeepUpPhysics {
    /// Exact constant-acceleration vertical integration, with optional overshoot-preserving ceiling reflection.
    static func verticalStep(
        position: CGFloat,
        velocity: CGFloat,
        gravity: CGFloat,
        deltaTime: TimeInterval,
        upperBound: CGFloat? = nil,
        restitution: CGFloat = 1
    ) -> (position: CGFloat, velocity: CGFloat, hitUpperBound: Bool) {
        let delta = CGFloat(max(0, deltaTime))
        let bounce = min(max(restitution, 0), 1)
        guard let upperBound, delta > 0 else {
            return (
                position + velocity * delta - 0.5 * gravity * delta * delta,
                velocity - gravity * delta,
                false
            )
        }
        var y = position
        var v = velocity
        var remaining = delta
        var hit = false
        var iterations = 0
        while remaining > 1e-12, iterations < 8 {
            iterations += 1
            if y > upperBound, v > 0 {
                let excess = y - upperBound
                y = upperBound - excess * bounce
                v = -abs(v) * bounce
                hit = true
                continue
            }
            if let timeToHit = timeToReach(position: y, velocity: v, gravity: gravity, target: upperBound),
               timeToHit <= remaining + 1e-9 {
                let t = min(max(timeToHit, 0), remaining)
                let velocityAtHit = v - gravity * t
                y = upperBound
                remaining -= t
                if velocityAtHit > 1e-12 {
                    v = -velocityAtHit * bounce
                    hit = true
                    continue
                }
                v = velocityAtHit
                if remaining <= 1e-12 { break }
                y = y + v * remaining - 0.5 * gravity * remaining * remaining
                v = v - gravity * remaining
                remaining = 0
                break
            }
            y = y + v * remaining - 0.5 * gravity * remaining * remaining
            v = v - gravity * remaining
            remaining = 0
        }
        if y > upperBound {
            let excess = y - upperBound
            y = upperBound - excess * bounce
            if v > 0 { v = -abs(v) * bounce }
            hit = true
        }
        return (y, v, hit)
    }

    /// Time until `position + velocity t - 0.5 gravity t²` reaches `target` with non-negative outgoing speed.
    static func timeToReach(position: CGFloat, velocity: CGFloat, gravity: CGFloat, target: CGFloat) -> CGFloat? {
        let travel = target - position
        if travel <= 1e-12 {
            return velocity > 0 ? 0 : nil
        }
        if abs(gravity) < 1e-12 {
            guard velocity > 1e-12 else { return nil }
            let time = travel / velocity
            return time >= 0 ? time : nil
        }
        let discriminant = velocity * velocity - 2 * gravity * travel
        guard discriminant >= 0 else { return nil }
        let root = sqrt(discriminant)
        let candidates = [(velocity - root) / gravity, (velocity + root) / gravity]
        return candidates.filter { $0 >= -1e-12 }.map { max(0, $0) }.min()
    }

    /// Triangular-wave reflection preserves overshoot, including multiple wall crossings.
    static func horizontalStep(
        position: CGFloat,
        velocity: CGFloat,
        deltaTime: TimeInterval,
        lowerBound: CGFloat,
        upperBound: CGFloat,
        reflects: Bool
    ) -> (position: CGFloat, velocity: CGFloat) {
        let delta = CGFloat(max(0, deltaTime))
        guard reflects, upperBound > lowerBound, velocity != 0 else {
            return (position + velocity * delta, velocity)
        }
        let width = upperBound - lowerBound
        let period = 2 * width
        let clamped = min(max(position, lowerBound), upperBound)
        var phase = velocity >= 0 ? clamped - lowerBound : period - (clamped - lowerBound)
        phase = (phase + abs(velocity) * delta).truncatingRemainder(dividingBy: period)
        if phase < width { return (lowerBound + phase, abs(velocity)) }
        return (lowerBound + period - phase, -abs(velocity))
    }

    /// Sweeps the ball against a simultaneously moving platform in platform-relative space.
    /// Only approaching contacts on the platform's playable upper face are accepted.
    static func sweptMovingUpperArcCollision(
        previousBallPosition: CGPoint,
        currentBallPosition: CGPoint,
        previousPlatformPosition: CGPoint,
        currentPlatformPosition: CGPoint,
        platformRadius: CGFloat,
        ballRadius: CGFloat,
        effectiveCatchRadius: CGFloat,
        tolerance: CGFloat,
        minimumNormalY: CGFloat
    ) -> KeepUpCollision? {
        let radius = max(0, platformRadius + ballRadius + tolerance)
        let ox = previousBallPosition.x - previousPlatformPosition.x
        let oy = previousBallPosition.y - previousPlatformPosition.y
        let dx = (currentBallPosition.x - previousBallPosition.x) - (currentPlatformPosition.x - previousPlatformPosition.x)
        let dy = (currentBallPosition.y - previousBallPosition.y) - (currentPlatformPosition.y - previousPlatformPosition.y)
        let a = dx * dx + dy * dy
        guard a > .ulpOfOne else { return nil }
        let b = 2 * (ox * dx + oy * dy)
        let c = ox * ox + oy * oy - radius * radius
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let root = sqrt(discriminant)
        let candidates = [(-b - root) / (2 * a), (-b + root) / (2 * a)]
        for fraction in candidates where fraction >= 0 && fraction <= 1 {
            let relativePoint = CGPoint(x: ox + dx * fraction, y: oy + dy * fraction)
            let normal = CGVector(dx: relativePoint.x / radius, dy: relativePoint.y / radius)
            let relativeApproach = dx * normal.dx + dy * normal.dy
            guard normal.dy >= min(max(minimumNormalY, 0), 1),
                  relativeApproach < 0,
                  abs(relativePoint.x) <= max(0, effectiveCatchRadius) + tolerance else { continue }
            let point = CGPoint(
                x: previousBallPosition.x + (currentBallPosition.x - previousBallPosition.x) * fraction,
                y: previousBallPosition.y + (currentBallPosition.y - previousBallPosition.y) * fraction
            )
            let platformPoint = CGPoint(
                x: previousPlatformPosition.x + (currentPlatformPosition.x - previousPlatformPosition.x) * fraction,
                y: previousPlatformPosition.y + (currentPlatformPosition.y - previousPlatformPosition.y) * fraction
            )
            return KeepUpCollision(point: point, platformPoint: platformPoint, normal: normal, segmentFraction: fraction)
        }
        return nil
    }

    static func outgoingHorizontalVelocity(
        normalizedImpactOffset: CGFloat,
        maximumSpeed: CGFloat,
        exponent: CGFloat,
        platformVelocity: CGFloat,
        transferCoefficient: CGFloat
    ) -> CGFloat {
        let offset = min(max(normalizedImpactOffset, -1), 1)
        let shaped = copysign(pow(abs(offset), max(0.05, exponent)), offset)
        let result = shaped * max(0, maximumSpeed) + platformVelocity * transferCoefficient
        return min(max(result, -abs(maximumSpeed)), abs(maximumSpeed))
    }
}
