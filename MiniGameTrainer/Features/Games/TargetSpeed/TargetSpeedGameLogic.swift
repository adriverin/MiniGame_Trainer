import CoreGraphics
import Foundation

/// Timestamp-driven TARGET SPEED state machine. SpriteKit-free; tests drive it with monotonic time.
final class TargetSpeedGameLogic {
    let config: TargetSpeedGameConfig
    let difficulty: TargetSpeedDifficultyModel
    let geometry: TargetSpeedGeometry
    private(set) var spawner: TargetSpeedSpawner

    private(set) var state: TargetSpeedGameState = .ready
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var targets: [TargetSpeedTargetState] = []
    private(set) var nextSpawnTimestamp: TimeInterval?
    private(set) var lastSimulationTimestamp: TimeInterval?
    private(set) var endReason: TargetSpeedEndReason?
    private(set) var hits = 0
    private(set) var misses = 0
    private(set) var ignoredTaps = 0
    private(set) var reactionTimes: [TimeInterval] = []
    private(set) var hasTerminated = false
    private(set) var nextTargetID = 1

    var scoreOverride: Int?
    var livesOverride: Int?
    var radiusOverride: CGFloat?
    var positionOverride: CGPoint?
    var spawnIntervalOverride: TimeInterval?
    var lifetimeOverride: TimeInterval?
    var maxActiveOverride: Int?

    private var rng: AnyRandomNumberGenerator
    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0

    init(
        config: TargetSpeedGameConfig = .reference,
        sceneSize: CGSize,
        seed: UInt64? = nil
    ) {
        self.config = config
        difficulty = TargetSpeedDifficultyModel(config: config)
        geometry = TargetSpeedGeometry(sceneSize: sceneSize, config: config)
        spawner = TargetSpeedSpawner(config: config, difficulty: difficulty, geometry: geometry)
        rng = .seeded(seed ?? config.generatorSeed)
        lives = config.startingLives
    }

    var isFinished: Bool { state == .gameOver }
    var isPlaying: Bool { state == .playing }
    var effectiveScore: Int { scoreOverride ?? score }
    var effectiveLives: Int { livesOverride ?? lives }

    func difficultySnapshot(at score: Int? = nil) -> TargetSpeedDifficultySnapshot {
        difficulty.snapshot(forScore: score ?? effectiveScore)
    }

    func lifetime(forScore score: Int) -> TimeInterval {
        lifetimeOverride ?? difficulty.lifetime(forScore: score)
    }

    func spawnInterval(forScore score: Int) -> TimeInterval {
        spawnIntervalOverride ?? difficulty.spawnInterval(forScore: score)
    }

    func maxActive(forScore score: Int) -> Int {
        min(maxActiveOverride ?? difficulty.maxActive(forScore: score), config.maximumActiveTargets)
    }

    func liveTargets(at time: TimeInterval) -> [TargetSpeedTargetState] {
        targets.filter { $0.isAlive(at: time) }
    }

    func visibleTargets(at time: TimeInterval) -> [TargetSpeedTargetState] {
        targets.filter { target in
            if !target.isResolved { return true }
            if let missedAt = target.missedAt {
                return time < missedAt + config.missFadeDuration
            }
            return false
        }
    }

    func start(at time: TimeInterval) {
        guard state == .ready || state == .paused else { return }
        if state == .paused {
            resetPreservingSeed()
        }
        sessionStartTime = time
        lastSimulationTimestamp = time
        score = max(0, scoreOverride ?? 0)
        lives = max(0, livesOverride ?? config.startingLives)
        scoreOverride = nil
        livesOverride = nil
        hasTerminated = false
        endReason = nil
        nextSpawnTimestamp = time + config.firstTargetDelay
        state = .playing
        spawnAvailable(at: time)
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        guard state == .playing, !hasTerminated else { return }
        resolveExpiredTargets(at: time)
        prune(at: time)
        spawnAvailable(at: time)
    }

    @discardableResult
    func handleTap(at location: CGPoint, time: TimeInterval) -> TargetSpeedInputOutcome {
        lastSimulationTimestamp = time
        guard state == .playing, !hasTerminated else { return .ignored }

        if let target = geometry.nearestTarget(at: location, among: targets, time: time) {
            return resolveHit(target, at: time)
        }

        resolveExpiredTargets(at: time)
        spawnAvailable(at: time)
        ignoredTaps += 1
        return .ignored
    }

    @discardableResult
    func hit(id: Int, at time: TimeInterval) -> TargetSpeedInputOutcome {
        lastSimulationTimestamp = time
        guard state == .playing, !hasTerminated else { return .ignored }
        guard let target = targets.first(where: { $0.id == id && $0.isAlive(at: time) }) else {
            resolveExpiredTargets(at: time)
            return .ignored
        }
        return resolveHit(target, at: time)
    }

    @discardableResult
    func expire(id: Int? = nil, at time: TimeInterval) -> TargetSpeedInputOutcome {
        lastSimulationTimestamp = time
        guard state == .playing, !hasTerminated else { return .ignored }
        let candidate = id.flatMap { wanted in targets.first { $0.id == wanted && !$0.isResolved } }
            ?? targets.first { !$0.isResolved }
        guard var target = candidate else { return .ignored }
        target.expiresAt = min(target.expiresAt, time)
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            targets[index] = target
        }
        return resolveExpiredTargets(at: time).last ?? .ignored
    }

    func pause(at time: TimeInterval) {
        guard state == .playing else { return }
        update(at: time)
        pauseStartTime = time
        state = .paused
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pausedAt = pauseStartTime {
            accumulatedPausedTime += max(0, time - pausedAt)
        }
        pauseStartTime = nil
        resetPreservingSeed()
        start(at: time)
    }

    func reset() {
        resetPreservingSeed()
        rng = .seeded(config.generatorSeed)
    }

    func makeSummary(at time: TimeInterval? = nil) -> TargetSpeedSessionSummary {
        let end = time ?? finishTime ?? lastSimulationTimestamp ?? 0
        let start = sessionStartTime ?? end
        let duration = max(0, end - start - accumulatedPausedTime)
        return TargetSpeedSessionSummary(
            score: score,
            duration: duration,
            livesRemaining: max(0, lives),
            hits: hits,
            misses: misses,
            ignoredTaps: ignoredTaps,
            endReason: endReason,
            averageReactionTime: reactionTimes.isEmpty ? nil : reactionTimes.reduce(0, +) / Double(reactionTimes.count),
            bestReactionTime: reactionTimes.min()
        )
    }

    @discardableResult
    private func resolveHit(_ target: TargetSpeedTargetState, at time: TimeInterval) -> TargetSpeedInputOutcome {
        guard let index = targets.firstIndex(where: { $0.id == target.id }), !targets[index].isResolved else {
            return .ignored
        }
        targets.remove(at: index)
        let points = target.pointValue
        score += points
        hits += 1
        reactionTimes.append(target.elapsed(at: time))
        resolveExpiredTargets(at: time)
        spawnAvailable(at: time)
        return .hit(id: target.id, score: score, points: points)
    }

    @discardableResult
    private func resolveExpiredTargets(at time: TimeInterval) -> [TargetSpeedInputOutcome] {
        var outcomes: [TargetSpeedInputOutcome] = []
        for index in targets.indices {
            guard !targets[index].isResolved, time > targets[index].expiresAt else { continue }
            targets[index].isResolved = true
            targets[index].missedAt = time
            misses += 1
            lives = max(0, lives - 1)
            let id = targets[index].id
            if lives == 0 {
                terminate(at: time)
                outcomes.append(.gameOver(id: id))
                return outcomes
            }
            outcomes.append(.missed(id: id, lives: lives))
        }
        return outcomes
    }

    private func spawnAvailable(at time: TimeInterval) {
        guard state == .playing, !hasTerminated else { return }
        var guardCount = 0
        while guardCount < 16 {
            guard let due = nextSpawnTimestamp, time >= due else { return }
            let live = liveTargets(at: time)
            if live.count >= maxActive(forScore: effectiveScore) {
                return
            }
            if let target = spawner.makeTarget(
                id: nextTargetID,
                at: time,
                score: effectiveScore,
                existing: live,
                rng: &rng,
                lifetimeOverride: lifetimeOverride,
                radiusOverride: radiusOverride,
                positionOverride: positionOverride
            ) {
                nextTargetID += 1
                targets.append(target)
                nextSpawnTimestamp = spawner.nextSpawnTime(
                    after: due,
                    score: effectiveScore,
                    intervalOverride: spawnIntervalOverride
                )
            } else {
                nextSpawnTimestamp = due + 0.05
                return
            }
            guardCount += 1
        }
    }

    private func prune(at time: TimeInterval) {
        targets.removeAll { target in
            guard let missedAt = target.missedAt else { return false }
            return time >= missedAt + config.missFadeDuration
        }
    }

    private func terminate(at time: TimeInterval) {
        guard !hasTerminated else { return }
        hasTerminated = true
        endReason = .outOfLives
        finishTime = time
        state = .gameOver
    }

    private func resetPreservingSeed() {
        state = .ready
        score = 0
        lives = config.startingLives
        targets = []
        nextSpawnTimestamp = nil
        lastSimulationTimestamp = nil
        endReason = nil
        hits = 0
        misses = 0
        ignoredTaps = 0
        reactionTimes = []
        hasTerminated = false
        nextTargetID = 1
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        accumulatedPausedTime = 0
    }
}
