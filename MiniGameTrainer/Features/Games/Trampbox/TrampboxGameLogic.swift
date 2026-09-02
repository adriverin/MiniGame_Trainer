import CoreGraphics
import Foundation

/// Framework-free deterministic Trampbox simulation. SpriteKit only renders this state.
final class TrampboxGameLogic {
    let config: TrampboxGameConfig
    let geometry: TrampboxGeometry
    let difficulty: TrampboxDifficultyModel

    private(set) var state: TrampboxGameState = .ready
    private(set) var score = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var bouncePhase: CGFloat = 0
    private(set) var ballX: CGFloat
    private(set) var desiredBallX: CGFloat
    private(set) var horizontalVelocity: CGFloat = 0
    private(set) var platforms: [TrampboxPlatform] = []
    private(set) var lastLanding: TrampboxLandingPerformance?

    private var fallBallY: CGFloat
    private var fallVelocity: CGFloat = 0
    private var generator: TrampboxPlatformGenerator
    private var tracker = TrampboxPerformanceTracker()
    private var pendingEvents: [TrampboxGameEvent] = []
    private var stateBeforePause: TrampboxGameState?

    init(config: TrampboxGameConfig, sceneSize: CGSize) {
        self.config = config
        geometry = TrampboxGeometry(sceneSize: sceneSize, config: config)
        difficulty = TrampboxDifficultyModel(config: config)
        generator = TrampboxPlatformGenerator(config: config)
        ballX = sceneSize.width * config.startingXRatio
        desiredBallX = ballX
        fallBallY = sceneSize.height * config.landingYRatio
        reset()
    }

    var bounceDuration: TimeInterval { difficulty.bounceDuration(for: score) }
    var platformWidth: CGFloat { difficulty.platformWidthRatio(for: score) * geometry.width }
    var ballScreenY: CGFloat {
        state == .falling ? fallBallY : geometry.ballCenterY(bouncePhase: bouncePhase)
    }
    var targetPlatform: TrampboxPlatform? { platforms.count > 1 ? platforms[1] : nil }
    var reachableRange: CGFloat {
        guard let departure = platforms.first else { return 0 }
        return generator.maximumReach(from: departure, geometry: geometry)
    }

    // MARK: Session control

    func reset() {
        score = 0
        elapsedTime = 0
        bouncePhase = 0
        ballX = geometry.clampBallX(config.startingXRatio * geometry.width)
        desiredBallX = ballX
        horizontalVelocity = 0
        fallBallY = geometry.ballCenterY(bouncePhase: 0)
        fallVelocity = 0
        lastLanding = nil
        tracker.reset()
        pendingEvents.removeAll(keepingCapacity: true)
        stateBeforePause = nil
        platforms = generator.initialPlatforms(geometry: geometry)
        setState(.ready)
    }

    func beginCountdown() {
        guard state == .ready else { return }
        setState(.countdown)
    }

    func startPlaying() {
        guard state == .ready || state == .countdown else { return }
        setState(.playing)
    }

    func pause() {
        switch state {
        case .playing, .falling, .countdown:
            stateBeforePause = state
            setState(.paused)
        default:
            break
        }
    }

    func resume() {
        guard state == .paused else { return }
        setState(stateBeforePause ?? .playing)
        stateBeforePause = nil
    }

    func abort() {
        end(reason: .aborted)
    }

    // MARK: Input

    /// Relative drag: every finger delta moves the desired ball position by sensitivity × delta.
    func applyDrag(deltaX: CGFloat) {
        guard state == .playing || state == .falling else { return }
        desiredBallX = geometry.clampBallX(desiredBallX + deltaX * config.horizontalControlSensitivity)
    }

    // MARK: Simulation

    func update(deltaTime rawDelta: TimeInterval) {
        let delta = min(max(0, rawDelta), config.maximumFrameDelta)
        guard delta > 0 else { return }

        switch state {
        case .playing:
            elapsedTime += delta
            advancePlaying(by: delta)
        case .falling:
            elapsedTime += delta
            advanceHorizontal(by: delta)
            fallVelocity += geometry.height * config.fallGravityRatio * CGFloat(delta)
            fallBallY += fallVelocity * CGFloat(delta)
            if fallBallY - geometry.ballRadius >= geometry.failureY {
                end(reason: .missedPlatform)
            }
        default:
            break
        }
    }

    private func advancePlaying(by delta: TimeInterval) {
        var remaining = delta
        var iterations = 0
        while remaining > 0.000_001, state == .playing, iterations < 4 {
            iterations += 1
            let duration = max(0.001, bounceDuration)
            let timeToLanding = duration * Double(max(0, 1 - bouncePhase))
            let step = min(remaining, timeToLanding)
            let previousPhase = bouncePhase
            advanceHorizontal(by: step)
            bouncePhase = min(1, bouncePhase + CGFloat(step / duration))
            remaining -= step

            if bouncePhase >= 1 - 0.000_001 {
                evaluateLanding(previousPhase: previousPhase)
            }
        }
    }

    private func advanceHorizontal(by delta: TimeInterval) {
        let difference = desiredBallX - ballX
        let maximumStep = geometry.maximumHorizontalSpeed * CGFloat(delta)
        let movement = min(max(difference, -maximumStep), maximumStep)
        ballX = geometry.clampBallX(ballX + movement)
        horizontalVelocity = delta > 0 ? movement / CGFloat(delta) : 0
    }

    private func evaluateLanding(previousPhase: CGFloat) {
        guard let target = targetPlatform else {
            beginFall()
            return
        }
        let previousBottom = geometry.ballCenterY(bouncePhase: previousPhase) + geometry.ballRadius
        let currentBottom = geometry.ballCenterY(bouncePhase: 1) + geometry.ballRadius
        let previousTop = geometry.platformTopY(slot: 1, bouncePhase: previousPhase)
        let currentTop = geometry.platformTopY(slot: 1, bouncePhase: 1)
        let landed = TrampboxCollisionDetector.didLand(
            previousBallBottom: previousBottom,
            currentBallBottom: currentBottom,
            previousPlatformTop: previousTop,
            currentPlatformTop: currentTop,
            descending: previousPhase >= 0.5,
            ballX: ballX,
            ballRadius: geometry.ballRadius,
            platformCenterX: target.centerX,
            platformWidth: target.width,
            rule: config.landingRule,
            tolerance: config.landingTolerance
        )
        guard landed else {
            beginFall()
            return
        }

        score += config.pointsPerLanding
        let error = abs(ballX - target.centerX)
        let performance = TrampboxLandingPerformance(
            platformID: target.id,
            platformCenterX: target.centerX,
            ballCenterX: ballX,
            horizontalError: error,
            normalizedError: error / max(1, target.width / 2),
            platformWidth: target.width,
            score: score
        )
        lastLanding = performance
        tracker.record(performance)
        pendingEvents.append(.landed(performance))
        pendingEvents.append(.scoreChanged(score))

        platforms.removeFirst()
        if let last = platforms.last {
            let futureScore = score + platforms.count
            platforms.append(generator.next(after: last, score: futureScore, geometry: geometry))
        }
        bouncePhase = 0
    }

    private func beginFall() {
        bouncePhase = 1
        fallBallY = geometry.ballCenterY(bouncePhase: 1)
        fallVelocity = geometry.height * config.fallInitialSpeedRatio
        setState(.falling)
    }

    // MARK: Events / result

    func drainEvents() -> [TrampboxGameEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    func makeSummary() -> TrampboxSessionSummary {
        let reason: TrampboxGameOverReason
        if case .gameOver(let value) = state { reason = value } else { reason = .aborted }
        return tracker.summary(
            score: score,
            duration: elapsedTime,
            finalBounceDuration: bounceDuration,
            reason: reason
        )
    }

    private func setState(_ newState: TrampboxGameState) {
        guard state != newState else { return }
        state = newState
        pendingEvents.append(.stateChanged(newState))
    }

    private func end(reason: TrampboxGameOverReason) {
        if case .gameOver = state { return }
        setState(.gameOver(reason))
        pendingEvents.append(.gameEnded(reason))
    }
}
