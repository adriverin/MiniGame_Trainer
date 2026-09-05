import CoreGraphics
import Foundation

/// SpriteKit-independent fixed-step Bloopy simulation.
final class BloopyGameLogic {
    let config: BloopyGameConfig
    let geometry: BloopyGeometry
    let difficulty: BloopyDifficultyModel

    private(set) var state: BloopyGameState = .ready
    private(set) var score = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var ballPosition: CGPoint
    private(set) var ballVelocity: CGVector
    private(set) var previousBallPosition: CGPoint
    private(set) var cameraY: CGFloat = 0
    private(set) var platforms: [BloopyPlatform] = []
    private(set) var trailSamples: [BloopyTrailSample] = []
    private(set) var horizontalInput: BloopyHorizontalInput = .none
    private(set) var landingCount = 0
    private(set) var maxWorldY: CGFloat
    private(set) var lastLanding: BloopyLanding?
    var scoreOverride: Int?

    private var generator: BloopyPlatformGenerator
    private var events: [BloopyGameEvent] = []
    private var trailAccumulator: TimeInterval = 0
    private(set) var lastLandedPlatformID: Int?
    private(set) var startWorldY: CGFloat
    private var highestPlatformY: CGFloat = 0

    init(config: BloopyGameConfig, sceneSize: CGSize) {
        self.config = config
        geometry = BloopyGeometry(sceneSize: sceneSize, config: config)
        difficulty = BloopyDifficultyModel(config: config)
        generator = BloopyPlatformGenerator(config: config)
        let startX = sceneSize.width * config.startingBallXRatio
        let startPlatformY = sceneSize.height * config.startingPlatformYRatio
        let startY = startPlatformY + geometry.platformHeight / 2 + geometry.ballRadius
        ballPosition = CGPoint(x: startX, y: startY)
        previousBallPosition = ballPosition
        ballVelocity = CGVector(dx: 0, dy: difficulty.bounceImpulse(sceneHeight: sceneSize.height))
        maxWorldY = startY
        startWorldY = startY
        reset()
    }

    var isFinished: Bool { state == .gameOver }
    var gravity: CGFloat { difficulty.gravity(sceneHeight: geometry.height) }
    var bounceImpulse: CGFloat { difficulty.bounceImpulse(sceneHeight: geometry.height) }
    var horizontalAcceleration: CGFloat { difficulty.horizontalAcceleration(sceneWidth: geometry.width) }
    var maximumHorizontalSpeed: CGFloat { difficulty.maximumHorizontalSpeed(sceneWidth: geometry.width) }
    var effectiveScore: Int { scoreOverride ?? score }
    var trailCapacity: Int { max(1, config.trailMaximumCount) }
    var ballScreenPosition: CGPoint {
        CGPoint(x: ballPosition.x, y: geometry.screenY(worldY: ballPosition.y, cameraY: cameraY))
    }

    func start() {
        guard state == .ready else { return }
        state = .playing
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        horizontalInput = .none
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
    }

    func reset() {
        state = .ready
        score = 0
        elapsedTime = 0
        cameraY = 0
        landingCount = 0
        horizontalInput = .none
        trailSamples = []
        trailAccumulator = 0
        lastLanding = nil
        lastLandedPlatformID = nil
        events.removeAll(keepingCapacity: true)
        platforms = generator.initialPlatforms(geometry: geometry)
        let start = platforms[0]
        let startY = geometry.platformTop(worldY: start.worldY) + geometry.ballRadius
        ballPosition = CGPoint(x: start.worldX, y: startY)
        previousBallPosition = ballPosition
        ballVelocity = CGVector(dx: 0, dy: bounceImpulse)
        startWorldY = startY
        maxWorldY = startY
        highestPlatformY = platforms.map(\.worldY).max() ?? start.worldY
        lastLandedPlatformID = start.id
        #if DEBUG
        assert(start.kind == .stable, "starting platform must be stable")
        assert(start.landingCount == 0, "starting on a platform must not consume durability")
        #endif
    }

    func setHorizontalInput(_ input: BloopyHorizontalInput) {
        horizontalInput = input
    }

    func beginTouch(at position: CGPoint) {
        horizontalInput = input(for: position)
    }

    func moveTouch(to position: CGPoint) {
        horizontalInput = input(for: position)
    }

    func endTouch() {
        horizontalInput = .none
    }

    func update(deltaTime: TimeInterval) {
        guard state == .playing else { return }
        var remaining = min(max(0, deltaTime), max(0, config.maximumFrameDelta))
        let stepLimit = max(1.0 / 1_000.0, config.maximumPhysicsStep)
        while remaining > 1e-12, state == .playing {
            let step = min(remaining, stepLimit)
            simulateStep(step)
            remaining -= step
        }
    }

    func drainEvents() -> [BloopyGameEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func makeSummary() -> BloopySessionSummary {
        BloopySessionSummary(
            score: score,
            duration: elapsedTime,
            landings: landingCount,
            maxWorldY: maxWorldY,
            redPlatformCount: platforms.filter { $0.appearance == .red }.count
        )
    }

    func nearestPlatforms(limit: Int = 4) -> [BloopyPlatform] {
        platforms
            .sorted { abs($0.worldY - ballPosition.y) < abs($1.worldY - ballPosition.y) }
            .prefix(limit)
            .map { $0 }
    }

    func nextPlatformAboveBall() -> BloopyPlatform? {
        platforms
            .filter { $0.worldY > ballPosition.y + 1 }
            .min(by: { $0.worldY < $1.worldY })
    }

    /// Target platform for auto-steer: nearest platform above when rising, nearest below when falling.
    func autoSteerTarget() -> BloopyPlatform? {
        if ballVelocity.dy >= 0 {
            return platforms
                .filter { $0.isCollidable }
                .filter { $0.worldY > ballPosition.y + 1 }
                .min { $0.worldY < $1.worldY }
        } else {
            let below = platforms
                .filter { $0.isCollidable }
                .filter { $0.id != lastLandedPlatformID }
                .filter { $0.worldY + geometry.platformHeight < ballPosition.y }
                .filter { $0.worldY > cameraY - geometry.failureMargin }
                .max { $0.worldY < $1.worldY }
            return below ?? platforms
                .filter { $0.isCollidable }
                .filter { $0.worldY > ballPosition.y + 1 }
                .min { $0.worldY < $1.worldY }
        }
    }

    func autoSteerInput() -> BloopyHorizontalInput {
        guard let next = autoSteerTarget() else { return .none }
        let delta = next.worldX - ballPosition.x
        let tolerance = next.width * 0.3
        if abs(delta) <= tolerance {
            return .none
        }
        return delta < 0 ? .left : .right
    }

    func applyAutoSteer() {
        setHorizontalInput(autoSteerInput())
    }

    func landingContact(
        from previous: CGPoint,
        to current: CGPoint,
        deltaTime: TimeInterval
    ) -> BloopyLandingContact? {
        firstLanding(from: previous, to: current, deltaTime: deltaTime)
    }

    func replacePlatformsForTesting(_ value: [BloopyPlatform]) {
        platforms = value
        highestPlatformY = value.map(\.worldY).max() ?? highestPlatformY
    }

    func placeBallForTesting(position: CGPoint, velocity: CGVector, previous: CGPoint? = nil) {
        ballPosition = CGPoint(
            x: BloopyPhysics.clampBallCenter(position.x, worldWidth: geometry.width, ballRadius: geometry.ballRadius),
            y: position.y
        )
        previousBallPosition = previous ?? ballPosition
        ballVelocity = velocity
        lastLandedPlatformID = nil
    }

    private func input(for position: CGPoint) -> BloopyHorizontalInput {
        position.x < geometry.width * 0.5 ? .left : .right
    }

    private func simulateStep(_ deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        ageTrail(by: deltaTime)
        previousBallPosition = ballPosition

        let horizontal = BloopyPhysics.horizontalStep(
            position: ballPosition.x,
            velocity: ballVelocity.dx,
            input: horizontalInput,
            acceleration: horizontalAcceleration,
            damping: config.horizontalDampingPerSecond,
            maximumSpeed: maximumHorizontalSpeed,
            deltaTime: deltaTime,
            worldWidth: geometry.width,
            ballRadius: geometry.ballRadius
        )

        let vertical = BloopyPhysics.verticalStep(
            position: ballPosition.y,
            velocity: ballVelocity.dy,
            gravity: gravity,
            deltaTime: deltaTime
        )
        let candidate = CGPoint(x: horizontal.position, y: vertical.position)
        if let contact = firstLanding(from: previousBallPosition, to: candidate, deltaTime: deltaTime) {
            applyLanding(contact, horizontalVelocity: horizontal.velocity)
        } else {
            ballPosition = candidate
            ballVelocity = CGVector(dx: horizontal.velocity, dy: vertical.velocity)
            if lastLandedPlatformID != nil, !stillOverlappingLastPlatform() {
                lastLandedPlatformID = nil
            }
        }

        maxWorldY = max(maxWorldY, ballPosition.y)
        updateScore()
        updateCamera()
        maintainPlatforms()
        sampleTrailIfNeeded(deltaTime: deltaTime)

        let screenBottom = ballPosition.y + geometry.ballRadius
        if screenBottom < cameraY - geometry.failureMargin {
            state = .gameOver
            events.append(.failed)
        }
    }

    private func firstLanding(from previous: CGPoint, to current: CGPoint, deltaTime: TimeInterval) -> BloopyLandingContact? {
        var best: BloopyLandingContact?
        for platform in platforms {
            guard platform.isCollidable else { continue }
            if geometry.platformTop(worldY: platform.worldY) < cameraY - geometry.recycleDistance - 1e-6 {
                continue
            }
            if platform.id == lastLandedPlatformID { continue }
            guard let contact = BloopyPhysics.sweptTopLanding(
                previous: previous,
                current: current,
                platform: platform,
                ballRadius: geometry.ballRadius,
                platformHeight: geometry.platformHeight,
                deltaTime: deltaTime
            ) else { continue }
            if best == nil || contact.remainingTime > best!.remainingTime {
                best = contact
            }
        }
        return best
    }

    private func applyLanding(_ contact: BloopyLandingContact, horizontalVelocity: CGFloat) {
        ballPosition = contact.worldPosition
        ballVelocity = CGVector(dx: horizontalVelocity, dy: bounceImpulse)
        lastLandedPlatformID = contact.platformID
        landingCount += 1
        lastLanding = BloopyLanding(
            platformID: contact.platformID,
            time: elapsedTime,
            ballPosition: contact.worldPosition,
            remainingTime: contact.remainingTime
        )
        registerLanding(on: contact.platformID)
        events.append(.bounced(platformID: contact.platformID, score: score))
        if contact.remainingTime > 1e-12 {
            let leftover = BloopyPhysics.verticalStep(
                position: ballPosition.y,
                velocity: ballVelocity.dy,
                gravity: gravity,
                deltaTime: contact.remainingTime
            )
            let leftoverX = BloopyPhysics.horizontalStep(
                position: ballPosition.x,
                velocity: ballVelocity.dx,
                input: horizontalInput,
                acceleration: horizontalAcceleration,
                damping: config.horizontalDampingPerSecond,
                maximumSpeed: maximumHorizontalSpeed,
                deltaTime: contact.remainingTime,
                worldWidth: geometry.width,
                ballRadius: geometry.ballRadius
            )
            ballPosition = CGPoint(x: leftoverX.position, y: leftover.position)
            ballVelocity = CGVector(dx: leftoverX.velocity, dy: leftover.velocity)
        }
    }

    /// Same physical contact may span several frames. A later genuine landing on the
    /// same platform is allowed only after the ball has left the top face.
    private func stillOverlappingLastPlatform() -> Bool {
        guard let id = lastLandedPlatformID, let platform = platforms.first(where: { $0.id == id }) else {
            return false
        }
        guard platform.isCollidable else { return false }
        let top = geometry.platformTop(worldY: platform.worldY)
        let hasLeftTopFace = ballPosition.y - geometry.ballRadius > top + 1e-6
        if hasLeftTopFace { return false }
        return BloopyPhysics.horizontallyOverlaps(
            ballX: ballPosition.x,
            platformX: platform.worldX,
            platformWidth: platform.width,
            ballRadius: geometry.ballRadius
        )
    }

    private func registerLanding(on platformID: Int) {
        guard let index = platforms.firstIndex(where: { $0.id == platformID }) else { return }
        platforms[index].landingCount += 1
        if platforms[index].isConsumed {
            platforms[index].isActive = false
        }
    }

    private func updateScore() {
        let next = BloopyScoring.score(maxWorldY: maxWorldY, startWorldY: startWorldY, unit: geometry.scoreUnit)
        let resolved = scoreOverride ?? next
        if resolved != score {
            score = resolved
            events.append(.scoreChanged(score))
        } else {
            score = resolved
        }
    }

    private func updateCamera() {
        let follow = cameraY + geometry.cameraFollowY
        if ballPosition.y > follow {
            cameraY = ballPosition.y - geometry.cameraFollowY
        }
    }

    private func maintainPlatforms() {
        for index in platforms.indices {
            let top = geometry.platformTop(worldY: platforms[index].worldY)
            if top < cameraY - geometry.recycleDistance {
                // Camera culling is independent of fragile consumption.
                platforms[index].isActive = false
            }
        }
        #if DEBUG
        assert(platforms.filter(\.isActive).allSatisfy(\.isCollidable), "inactive platforms must not stay collidable")
        assert(platforms.filter(\.isCollidable).allSatisfy(\.isActive), "collidable platforms must remain active")
        #endif
        platforms.removeAll { !$0.isActive }

        while platforms.count < max(2, config.lookaheadPlatformCount),
              let last = platforms.max(by: { $0.worldY < $1.worldY }) {
            let spawned = generator.next(after: last, score: effectiveScore, geometry: geometry)
            platforms.append(spawned)
            highestPlatformY = max(highestPlatformY, spawned.worldY)
        }
        let ceiling = cameraY + geometry.height * 1.35
        while highestPlatformY < ceiling, let last = platforms.max(by: { $0.worldY < $1.worldY }) {
            let spawned = generator.next(after: last, score: effectiveScore, geometry: geometry)
            platforms.append(spawned)
            highestPlatformY = spawned.worldY
        }
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
            trailSamples.append(BloopyTrailSample(position: ballPosition, age: 0))
        }
        if trailSamples.count > trailCapacity {
            trailSamples.removeFirst(trailSamples.count - trailCapacity)
        }
    }
}
