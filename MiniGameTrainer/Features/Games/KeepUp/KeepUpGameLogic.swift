import CoreGraphics
import Foundation

enum KeepUpGameState: Equatable { case ready, running, paused, gameOver }
enum KeepUpGameEvent: Equatable { case bounced(KeepUpBouncePerformance), failed }

struct KeepUpTrailSample: Equatable {
    let position: CGPoint
    var age: TimeInterval
}

/// SpriteKit-independent fixed-step simulation, input state, scoring, trail history and metrics.
final class KeepUpGameLogic {
    let config: KeepUpGameConfig
    let geometry: KeepUpGeometry

    private(set) var state: KeepUpGameState = .ready
    private(set) var score = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var ballPosition: CGPoint
    private(set) var ballVelocity: CGVector
    private(set) var previousBallPosition: CGPoint
    private(set) var desiredPlatformPosition: CGPoint
    private(set) var platformPosition: CGPoint
    private(set) var previousPlatformPosition: CGPoint
    private(set) var lastPlatformSweepStart: CGPoint
    private(set) var platformVelocity = CGVector.zero
    private(set) var currentTouchPosition: CGPoint?
    private(set) var previousTouchPosition: CGPoint?
    private(set) var trailSamples: [KeepUpTrailSample] = []
    private(set) var performance = KeepUpPerformanceTracker()
    private(set) var ceilingContactCount = 0
    private(set) var lastCeilingIncomingVY: CGFloat = 0
    private(set) var lastCeilingOutgoingVY: CGFloat = 0
    private(set) var lastPlatformToCeilingTime: TimeInterval = 0
    private(set) var lastCeilingToPlatformTime: TimeInterval = 0
    private(set) var lastCeilingContactTime: TimeInterval = 0

    private var events: [KeepUpGameEvent] = []
    private var trailAccumulator: TimeInterval = 0
    private var lastBounceTime: TimeInterval = 0
    private var lastTouchTime: TimeInterval?
    private var pendingPlatformSweepStart: CGPoint?

    init(config: KeepUpGameConfig, sceneSize: CGSize) {
        self.config = config
        geometry = KeepUpGeometry(sceneSize: sceneSize, config: config)
        let startX = sceneSize.width * config.startingBallXRatio
        let startY = sceneSize.height * config.startingBallYRatio
        ballPosition = CGPoint(x: startX, y: startY)
        previousBallPosition = ballPosition
        ballVelocity = CGVector(
            dx: sceneSize.width * config.startingHorizontalVelocityWidthRatio,
            dy: sceneSize.height * config.startingVerticalVelocityHeightRatio
        )
        let startPlatform = geometry.clampedPlatformPosition(CGPoint(
            x: sceneSize.width * config.startingPlatformXRatio,
            y: sceneSize.height * config.startingPlatformYRatio
        ))
        desiredPlatformPosition = startPlatform
        platformPosition = startPlatform
        previousPlatformPosition = startPlatform
        lastPlatformSweepStart = startPlatform
    }

    var isFinished: Bool { state == .gameOver }
    var platformCenter: CGPoint { platformPosition }
    var platformX: CGFloat { platformPosition.x }
    var platformY: CGFloat { platformPosition.y }
    var gravity: CGFloat { geometry.sceneSize.height * config.gravityHeightRatio }
    var bounceImpulse: CGFloat { geometry.sceneSize.height * config.bounceImpulseHeightRatio }
    var maximumHorizontalBounceSpeed: CGFloat { geometry.sceneSize.width * config.maximumHorizontalBounceSpeedWidthRatio }
    var trailCapacity: Int { max(1, config.trailMaximumCount) }
    var timeSinceLastPlatformBounce: TimeInterval { elapsedTime - lastBounceTime }
    var ballTopY: CGFloat { ballPosition.y + geometry.ballRadius }
    var distanceToCeiling: CGFloat { geometry.ceilingY - ballTopY }

    func start() {
        guard state == .ready else { return }
        state = .running
    }

    func beginTouch(position: CGPoint, at time: TimeInterval) {
        previousTouchPosition = currentTouchPosition
        currentTouchPosition = position
        lastTouchTime = time
        setPlatformPosition(position)
        platformVelocity = .zero
    }

    func moveTouch(position: CGPoint, at time: TimeInterval) {
        previousTouchPosition = currentTouchPosition
        currentTouchPosition = position
        let oldPosition = platformPosition
        setPlatformPosition(position)
        if let lastTouchTime, time > lastTouchTime {
            let duration = CGFloat(time - lastTouchTime)
            platformVelocity = CGVector(
                dx: (platformPosition.x - oldPosition.x) / duration,
                dy: (platformPosition.y - oldPosition.y) / duration
            )
        } else {
            platformVelocity = .zero
        }
        self.lastTouchTime = time
    }

    func endTouch() {
        previousTouchPosition = currentTouchPosition
        currentTouchPosition = nil
        lastTouchTime = nil
        platformVelocity = .zero
    }

    /// Also used by deterministic visual QA. Control is absolute in both axes.
    func setPlatformPosition(_ position: CGPoint) {
        desiredPlatformPosition = geometry.clampedPlatformPosition(position)
        let oldPosition = platformPosition
        guard desiredPlatformPosition != oldPosition else { return }
        if pendingPlatformSweepStart == nil { pendingPlatformSweepStart = oldPosition }
        platformPosition = desiredPlatformPosition
        performance.recordPlatformMovement(hypot(platformPosition.x - oldPosition.x, platformPosition.y - oldPosition.y))
    }

    func update(deltaTime: TimeInterval) {
        guard state == .running else { return }
        var remaining = min(max(0, deltaTime), max(0, config.maximumFrameDelta))
        let stepLimit = max(1.0 / 1_000.0, config.maximumPhysicsStep)
        while remaining > 1e-12, state == .running {
            let step = min(remaining, stepLimit)
            simulateStep(step)
            remaining -= step
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        platformVelocity = .zero
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
    }

    func reset() {
        state = .ready
        score = 0
        elapsedTime = 0
        ballPosition = CGPoint(
            x: geometry.sceneSize.width * config.startingBallXRatio,
            y: geometry.sceneSize.height * config.startingBallYRatio
        )
        previousBallPosition = ballPosition
        ballVelocity = CGVector(
            dx: geometry.sceneSize.width * config.startingHorizontalVelocityWidthRatio,
            dy: geometry.sceneSize.height * config.startingVerticalVelocityHeightRatio
        )
        platformPosition = geometry.clampedPlatformPosition(CGPoint(
            x: geometry.sceneSize.width * config.startingPlatformXRatio,
            y: geometry.sceneSize.height * config.startingPlatformYRatio
        ))
        desiredPlatformPosition = platformPosition
        previousPlatformPosition = platformPosition
        lastPlatformSweepStart = platformPosition
        pendingPlatformSweepStart = nil
        platformVelocity = .zero
        currentTouchPosition = nil
        previousTouchPosition = nil
        lastTouchTime = nil
        trailSamples = []
        trailAccumulator = 0
        lastBounceTime = 0
        ceilingContactCount = 0
        lastCeilingIncomingVY = 0
        lastCeilingOutgoingVY = 0
        lastPlatformToCeilingTime = 0
        lastCeilingToPlatformTime = 0
        lastCeilingContactTime = 0
        performance.reset()
        events = []
    }

    func drainEvents() -> [KeepUpGameEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func makeSummary() -> KeepUpSessionSummary {
        KeepUpSessionSummary(
            score: score,
            duration: elapsedTime,
            bounces: performance.bounces,
            peakBallSpeed: performance.peakBallSpeed,
            platformTravel: performance.platformTravel
        )
    }

    private func simulateStep(_ deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        ageTrail(by: deltaTime)
        previousBallPosition = ballPosition
        if let pendingPlatformSweepStart { lastPlatformSweepStart = pendingPlatformSweepStart }
        previousPlatformPosition = pendingPlatformSweepStart ?? platformPosition
        pendingPlatformSweepStart = nil

        let horizontal = KeepUpPhysics.horizontalStep(
            position: ballPosition.x,
            velocity: ballVelocity.dx,
            deltaTime: deltaTime,
            lowerBound: geometry.minimumBallX,
            upperBound: geometry.maximumBallX,
            reflects: config.reflectsAtSideWalls
        )
        let vertical = KeepUpPhysics.verticalStep(
            position: ballPosition.y,
            velocity: ballVelocity.dy,
            gravity: gravity,
            deltaTime: deltaTime,
            upperBound: config.reflectsAtCeiling ? geometry.maximumBallY : nil,
            restitution: config.ceilingRestitution
        )
        let candidate = CGPoint(x: horizontal.position, y: vertical.position)
        let incomingVelocity = CGVector(dx: horizontal.velocity, dy: vertical.velocity)

        if vertical.hitUpperBound {
            recordCeilingContact(incomingY: ballVelocity.dy, outgoingY: vertical.velocity)
        }

        if let collision = KeepUpPhysics.sweptMovingUpperArcCollision(
               previousBallPosition: previousBallPosition,
               currentBallPosition: candidate,
               previousPlatformPosition: previousPlatformPosition,
               currentPlatformPosition: platformPosition,
               platformRadius: geometry.platformRadius,
               ballRadius: geometry.ballRadius,
               effectiveCatchRadius: geometry.effectiveCatchRadius,
               tolerance: geometry.landingTolerance,
               minimumNormalY: config.minimumCatchNormalY
           ) {
            ballPosition = collision.point
            let impactOffset = collision.point.x - collision.platformPoint.x
            let normalized = min(max(impactOffset / geometry.effectiveCatchRadius, -1), 1)
            let outgoingX = KeepUpPhysics.outgoingHorizontalVelocity(
                normalizedImpactOffset: normalized,
                maximumSpeed: maximumHorizontalBounceSpeed,
                exponent: config.impactResponseExponent,
                platformVelocity: platformVelocity.dx,
                transferCoefficient: config.platformHorizontalVelocityTransferCoefficient
            )
            let outgoingY = max(
                bounceImpulse * 0.2,
                bounceImpulse + platformVelocity.dy * config.platformVerticalVelocityTransferCoefficient
            )
            ballVelocity = CGVector(dx: outgoingX, dy: outgoingY)
            score += max(0, config.pointsPerBounce)
            let bounce = KeepUpBouncePerformance(
                score: score,
                ballPosition: collision.point,
                platformPosition: collision.platformPoint,
                impactOffset: impactOffset,
                normalizedImpactOffset: normalized,
                incomingVelocity: incomingVelocity,
                outgoingVelocity: ballVelocity,
                platformVelocity: platformVelocity,
                contactNormal: collision.normal,
                bounceDuration: elapsedTime - lastBounceTime
            )
            lastBounceTime = elapsedTime
            if lastCeilingContactTime > 0 {
                lastCeilingToPlatformTime = elapsedTime - lastCeilingContactTime
            }
            performance.recordBounce(bounce)
            performance.recordBallVelocity(ballVelocity)
            events.append(.bounced(bounce))
        } else {
            ballPosition = candidate
            ballVelocity = incomingVelocity
            performance.recordBallVelocity(ballVelocity)
        }

        sampleTrailIfNeeded(deltaTime: deltaTime)
        if ballPosition.y + geometry.ballRadius < geometry.failureY {
            state = .gameOver
            events.append(.failed)
        }
    }

    private func recordCeilingContact(incomingY: CGFloat, outgoingY: CGFloat) {
        ceilingContactCount += 1
        lastCeilingIncomingVY = incomingY
        lastCeilingOutgoingVY = outgoingY
        lastCeilingContactTime = elapsedTime
        lastPlatformToCeilingTime = elapsedTime - lastBounceTime
    }

    private func ageTrail(by deltaTime: TimeInterval) {
        for index in trailSamples.indices { trailSamples[index].age += deltaTime }
        trailSamples.removeAll { $0.age > max(0, config.trailLifetime) }
    }

    private func sampleTrailIfNeeded(deltaTime: TimeInterval) {
        trailAccumulator += deltaTime
        let interval = max(1.0 / 240.0, config.trailSampleInterval)
        while trailAccumulator >= interval {
            trailAccumulator -= interval
            trailSamples.append(KeepUpTrailSample(position: ballPosition, age: 0))
        }
        if trailSamples.count > trailCapacity {
            trailSamples.removeFirst(trailSamples.count - trailCapacity)
        }
    }
}
