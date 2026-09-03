import Foundation

enum ColorReflexState: String, Equatable {
    case ready
    case waiting
    case tapNow
    case gameOver
    case paused
}

enum ColorReflexTapOutcome: Equatable {
    case ignored
    case started
    case premature(penalty: TimeInterval, remaining: TimeInterval)
    case scored(reaction: TimeInterval, score: Int)
    case ended
}

enum ColorReflexEndReason: String, Equatable {
    case timeExpired
}

struct ColorReflexSessionSummary: Equatable {
    var score: Int
    var duration: TimeInterval
    var reactionTimes: [TimeInterval]
    var prematureTapCount: Int
    var endReason: ColorReflexEndReason?

    var averageReactionTime: TimeInterval? {
        guard !reactionTimes.isEmpty else { return nil }
        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }

    var bestReactionTime: TimeInterval? { reactionTimes.min() }
}

enum ColorReflexScoring {
    static func remaining(deadline: TimeInterval, now: TimeInterval) -> TimeInterval {
        max(0, deadline - now)
    }

    static func remainingFraction(
        remaining: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(remaining / duration, 0), 1)
    }

    static func reactionTime(tap: TimeInterval, trigger: TimeInterval) -> TimeInterval {
        max(0, tap - trigger)
    }
}

/// Timestamp-driven COLOR REFLEX state machine. SpriteKit-free; tests drive it
/// with monotonic time. Timing never counts frames.
final class ColorReflexGameLogic {
    let config: ColorReflexGameConfig
    let difficulty: ColorReflexDifficultyModel
    let palette: ColorReflexPalette

    private(set) var state: ColorReflexState = .ready
    private(set) var score = 0
    private(set) var currentColor: ColorReflexSwatch = .teal
    private(set) var nextColor: ColorReflexSwatch?
    private(set) var sessionStartTimestamp: TimeInterval?
    private(set) var sessionDeadline: TimeInterval?
    private(set) var waitStartTimestamp: TimeInterval?
    private(set) var scheduledWaitDelay: TimeInterval?
    private(set) var triggerTimestamp: TimeInterval?
    private(set) var lastTapTimestamp: TimeInterval?
    private(set) var lastReactionTime: TimeInterval?
    private(set) var reactionTimes: [TimeInterval] = []
    private(set) var prematureTapCount = 0
    private(set) var lastSimulationTimestamp: TimeInterval?
    private(set) var endReason: ColorReflexEndReason?
    private(set) var hasTerminated = false
    private(set) var touchHeldFromWait = false

    var forcedColorSequence: [ColorReflexSwatch]?
    var scoreOverride: Int?
    var waitDelayOverride: TimeInterval?

    private var rng: AnyRandomNumberGenerator
    private var forcedColorIndex = 0
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0
    private var stateBeforePause: ColorReflexState?

    init(config: ColorReflexGameConfig = .reference, seed: UInt64? = nil) {
        self.config = config
        difficulty = ColorReflexDifficultyModel(config: config)
        palette = ColorReflexPalette()
        rng = .seeded(seed ?? config.generatorSeed)
    }

    var isFinished: Bool { state == .gameOver }
    var isPlaying: Bool { state == .waiting || state == .tapNow }
    var effectiveScore: Int { scoreOverride ?? score }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        guard let sessionStartTimestamp else { return 0 }
        return max(0, time - sessionStartTimestamp)
    }

    func remaining(at time: TimeInterval) -> TimeInterval {
        guard let sessionDeadline else { return 0 }
        return ColorReflexScoring.remaining(deadline: sessionDeadline, now: time)
    }

    func remainingFraction(at time: TimeInterval) -> Double {
        ColorReflexScoring.remainingFraction(
            remaining: remaining(at: time),
            duration: config.resolvedSessionDuration
        )
    }

    func timeUntilTrigger(at time: TimeInterval) -> TimeInterval? {
        guard state == .waiting, let triggerTimestamp else { return nil }
        return triggerTimestamp - time
    }

    func start(at time: TimeInterval) {
        guard state == .ready || state == .paused else { return }
        if state == .paused {
            resetPreservingSeed()
        }
        sessionStartTimestamp = time
        sessionDeadline = time + config.resolvedSessionDuration
        lastSimulationTimestamp = time
        score = max(0, scoreOverride ?? 0)
        scoreOverride = nil
        hasTerminated = false
        endReason = nil
        finishTime = nil
        currentColor = nextForcedOrRandom(after: nil)
        beginWait(at: time)
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        guard isPlaying, !hasTerminated else { return }
        if let sessionDeadline, time > sessionDeadline {
            terminate(at: time)
            return
        }
        if state == .waiting, let triggerTimestamp, time >= triggerTimestamp {
            if let sessionDeadline, time > sessionDeadline {
                terminate(at: time)
                return
            }
            enterTapNow(at: triggerTimestamp)
        }
    }

    @discardableResult
    func handleTouchBegan(at time: TimeInterval) -> ColorReflexTapOutcome {
        lastTapTimestamp = time
        if state == .ready {
            start(at: time)
            return .started
        }
        if let sessionDeadline, time > sessionDeadline {
            update(at: time)
            return .ended
        }
        update(at: time)
        guard isPlaying else { return state == .gameOver ? .ended : .ignored }

        switch state {
        case .waiting:
            touchHeldFromWait = true
            return applyPremature(at: time)
        case .tapNow:
            if touchHeldFromWait {
                return .ignored
            }
            return applySuccess(at: time)
        default:
            return .ignored
        }
    }

    func handleTouchEnded() {
        touchHeldFromWait = false
    }

    func pause(at time: TimeInterval) {
        guard isPlaying else { return }
        update(at: time)
        guard isPlaying else { return }
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        let paused = max(0, time - (pauseStartTime ?? time))
        accumulatedPausedTime += paused
        if let sessionStartTimestamp { self.sessionStartTimestamp = sessionStartTimestamp + paused }
        if let sessionDeadline { self.sessionDeadline = sessionDeadline + paused }
        if let waitStartTimestamp { self.waitStartTimestamp = waitStartTimestamp + paused }
        if let triggerTimestamp { self.triggerTimestamp = triggerTimestamp + paused }
        pauseStartTime = nil
        lastSimulationTimestamp = time
        state = stateBeforePause ?? .waiting
        stateBeforePause = nil
        update(at: time)
    }

    func reset() {
        resetPreservingSeed()
        rng = .seeded(config.generatorSeed)
    }

    func makeSummary(at time: TimeInterval? = nil) -> ColorReflexSessionSummary {
        let end = time ?? finishTime ?? lastSimulationTimestamp ?? 0
        let start = sessionStartTimestamp ?? end
        let duration = max(0, end - start - accumulatedPausedTime)
        return ColorReflexSessionSummary(
            score: score,
            duration: duration,
            reactionTimes: reactionTimes,
            prematureTapCount: prematureTapCount,
            endReason: endReason
        )
    }

    private func beginWait(at time: TimeInterval) {
        state = .waiting
        waitStartTimestamp = time
        let delay = waitDelayOverride ?? difficulty.waitDelay(rng: &rng)
        scheduledWaitDelay = delay
        triggerTimestamp = time + delay
        nextColor = nextForcedOrRandom(after: currentColor)
        lastSimulationTimestamp = time
        if let sessionDeadline, time > sessionDeadline {
            terminate(at: time)
        }
    }

    private func enterTapNow(at triggerTime: TimeInterval) {
        guard let nextColor else { return }
        currentColor = nextColor
        self.nextColor = nil
        triggerTimestamp = triggerTime
        state = .tapNow
    }

    private func applySuccess(at time: TimeInterval) -> ColorReflexTapOutcome {
        guard let triggerTimestamp else { return .ignored }
        if time > (sessionDeadline ?? time) {
            terminate(at: time)
            return .ended
        }
        let reaction = ColorReflexScoring.reactionTime(tap: time, trigger: triggerTimestamp)
        lastReactionTime = reaction
        reactionTimes.append(reaction)
        score += 1
        touchHeldFromWait = false
        beginWait(at: time)
        return .scored(reaction: reaction, score: score)
    }

    private func applyPremature(at time: TimeInterval) -> ColorReflexTapOutcome {
        prematureTapCount += 1
        let penalty = config.resolvedPrematurePenalty
        if let sessionDeadline {
            self.sessionDeadline = sessionDeadline - penalty
        }
        if let sessionDeadline, time > sessionDeadline {
            terminate(at: time)
            return .ended
        }
        if config.prematureResetsWait {
            beginWait(at: time)
        }
        return .premature(penalty: penalty, remaining: remaining(at: time))
    }

    private func terminate(at time: TimeInterval) {
        guard !hasTerminated else { return }
        hasTerminated = true
        endReason = .timeExpired
        finishTime = time
        state = .gameOver
        triggerTimestamp = nil
        scheduledWaitDelay = nil
        nextColor = nil
    }

    private func nextForcedOrRandom(after current: ColorReflexSwatch?) -> ColorReflexSwatch {
        if let forcedColorSequence, forcedColorIndex < forcedColorSequence.count {
            let color = forcedColorSequence[forcedColorIndex]
            forcedColorIndex += 1
            return color
        }
        return palette.color(after: current, rng: &rng)
    }

    private func resetPreservingSeed() {
        state = .ready
        score = 0
        currentColor = .teal
        nextColor = nil
        sessionStartTimestamp = nil
        sessionDeadline = nil
        waitStartTimestamp = nil
        scheduledWaitDelay = nil
        triggerTimestamp = nil
        lastTapTimestamp = nil
        lastReactionTime = nil
        reactionTimes = []
        prematureTapCount = 0
        lastSimulationTimestamp = nil
        endReason = nil
        hasTerminated = false
        touchHeldFromWait = false
        scoreOverride = nil
        finishTime = nil
        pauseStartTime = nil
        accumulatedPausedTime = 0
        stateBeforePause = nil
        forcedColorIndex = 0
    }
}
