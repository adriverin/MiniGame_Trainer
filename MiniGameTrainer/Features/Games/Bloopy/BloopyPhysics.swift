import CoreGraphics
import Foundation

struct BloopyLandingContact: Equatable {
    let platformID: Int
    let worldPosition: CGPoint
    let remainingTime: TimeInterval
    let wrappedOffset: CGFloat
}

enum BloopyPhysics {
    /// Positive-modulo wrap that preserves overshoot. `98 + 5` on width 100 becomes `3`, not `0`.
    static func wrap(_ value: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return value }
        let wrapped = value.truncatingRemainder(dividingBy: width)
        return wrapped >= 0 ? wrapped : wrapped + width
    }

    static func wrapPoint(_ point: CGPoint, width: CGFloat) -> CGPoint {
        CGPoint(x: wrap(point.x, width: width), y: point.y)
    }

    static func toroidalDelta(from origin: CGFloat, to destination: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return destination - origin }
        var delta = wrap(destination - origin, width: width)
        if delta > width / 2 { delta -= width }
        return delta
    }

    static func toroidalDistance(_ a: CGFloat, _ b: CGFloat, width: CGFloat) -> CGFloat {
        abs(toroidalDelta(from: a, to: b, width: width))
    }

    static func horizontalStep(
        position: CGFloat,
        velocity: CGFloat,
        input: BloopyHorizontalInput,
        acceleration: CGFloat,
        damping: CGFloat,
        maximumSpeed: CGFloat,
        deltaTime: TimeInterval,
        worldWidth: CGFloat
    ) -> (position: CGFloat, velocity: CGFloat) {
        let dt = CGFloat(max(0, deltaTime))
        var vx = velocity
        if input == .none {
            let decay = exp(-max(0, damping) * dt)
            vx *= decay
            if abs(vx) < 1e-4 { vx = 0 }
        } else {
            vx += CGFloat(input.rawValue) * max(0, acceleration) * dt
        }
        let cap = abs(maximumSpeed)
        vx = min(max(vx, -cap), cap)
        let x = wrap(position + vx * dt, width: worldWidth)
        return (x, vx)
    }

    static func verticalStep(
        position: CGFloat,
        velocity: CGFloat,
        gravity: CGFloat,
        deltaTime: TimeInterval
    ) -> (position: CGFloat, velocity: CGFloat) {
        let dt = CGFloat(max(0, deltaTime))
        return (
            position + velocity * dt - 0.5 * gravity * dt * dt,
            velocity - gravity * dt
        )
    }

    /// Descending-only swept contact against the top face. `previous`/`current` are ball centers.
    static func sweptTopLanding(
        previous: CGPoint,
        current: CGPoint,
        platform: BloopyPlatform,
        ballRadius: CGFloat,
        platformHeight: CGFloat,
        worldWidth: CGFloat,
        deltaTime: TimeInterval
    ) -> BloopyLandingContact? {
        let top = platform.worldY + platformHeight / 2
        let previousBottom = previous.y - ballRadius
        let currentBottom = current.y - ballRadius
        guard previousBottom > top + 1e-9, currentBottom <= top + 1e-9 else { return nil }
        let travel = current.y - previous.y
        guard travel < -1e-9 else { return nil }

        let fraction = min(max((top + ballRadius - previous.y) / travel, 0), 1)
        let contactX = previous.x + (current.x - previous.x) * fraction
        let contactY = top + ballRadius
        guard let offset = overlappingWrapOffset(
            ballX: contactX,
            platformX: platform.worldX,
            platformWidth: platform.width,
            ballRadius: ballRadius,
            worldWidth: worldWidth
        ) else { return nil }

        let remaining = max(0, deltaTime) * TimeInterval(1 - fraction)
        return BloopyLandingContact(
            platformID: platform.id,
            worldPosition: CGPoint(x: wrap(contactX, width: worldWidth), y: contactY),
            remainingTime: remaining,
            wrappedOffset: offset
        )
    }

    static func overlappingWrapOffset(
        ballX: CGFloat,
        platformX: CGFloat,
        platformWidth: CGFloat,
        ballRadius: CGFloat,
        worldWidth: CGFloat
    ) -> CGFloat? {
        let half = platformWidth / 2
        for offset: CGFloat in [0, -worldWidth, worldWidth] {
            let x = ballX + offset
            if x + ballRadius >= platformX - half - 1e-9, x - ballRadius <= platformX + half + 1e-9 {
                return offset
            }
        }
        return nil
    }

    static func timeToDescend(
        from startY: CGFloat,
        to destinationY: CGFloat,
        velocity: CGFloat,
        gravity: CGFloat
    ) -> TimeInterval? {
        let travel = destinationY - startY
        if abs(gravity) < 1e-12 {
            guard velocity < -1e-12 else { return nil }
            let time = travel / velocity
            return time >= 0 ? TimeInterval(time) : nil
        }
        let discriminant = velocity * velocity - 2 * gravity * travel
        guard discriminant >= 0 else { return nil }
        let root = sqrt(discriminant)
        let candidates = [(velocity - root) / gravity, (velocity + root) / gravity]
        let landing = candidates.filter { $0 >= 1e-6 }.min()
        return landing.map { TimeInterval($0) }
    }

    static func bounceFlightTime(impulse: CGFloat, gravity: CGFloat, heightGain: CGFloat) -> TimeInterval? {
        guard gravity > 0, impulse > 0 else { return nil }
        let apex = impulse * impulse / (2 * gravity)
        guard heightGain < apex - 1e-6 else { return nil }
        return timeToDescend(from: 0, to: heightGain, velocity: impulse, gravity: gravity)
    }

    static func maximumHorizontalTravel(
        acceleration: CGFloat,
        maximumSpeed: CGFloat,
        flightTime: TimeInterval
    ) -> CGFloat {
        let t = CGFloat(max(0, flightTime))
        let accel = max(0, acceleration)
        let cap = max(0, maximumSpeed)
        guard t > 0, cap > 0 else { return 0 }
        if accel <= 1e-9 { return cap * t }
        let timeToCap = cap / accel
        if t <= timeToCap {
            return 0.5 * accel * t * t
        }
        let distanceToCap = 0.5 * accel * timeToCap * timeToCap
        return distanceToCap + cap * (t - timeToCap)
    }
}
