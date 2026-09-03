import Foundation

enum TimesUpState: Equatable {
    case ready
    case visible(level: Int)
    case hidden(level: Int)
    case feedback(level: Int)
    case finished
    case paused
}

enum TimesUpTimingDirection: String, Equatable {
    case exact
    case early
    case late
}

enum TimesUpTapOutcome: Equatable {
    case ignored
    case started
    case scored(TimesUpLevelResult)
    case finished(TimesUpLevelResult)
}

enum TimesUpScoring {
    static func signedError(elapsed: TimeInterval, target: TimeInterval) -> TimeInterval {
        elapsed - target
    }

    static func absoluteError(elapsed: TimeInterval, target: TimeInterval) -> TimeInterval {
        abs(signedError(elapsed: elapsed, target: target))
    }

    static func direction(signedError: TimeInterval, exactTolerance: TimeInterval = 0) -> TimesUpTimingDirection {
        if abs(signedError) <= max(0, exactTolerance) { return .exact }
        return signedError > 0 ? .late : .early
    }

    static func progress(elapsed: TimeInterval, target: TimeInterval) -> Double {
        guard target > 0 else { return 0 }
        return min(max(1 - elapsed / target, 0), 1)
    }

    static func isBarVisible(
        elapsed: TimeInterval,
        target: TimeInterval,
        visibilityFraction: Double
    ) -> Bool {
        elapsed < target * min(max(visibilityFraction, 0), 1)
    }

    static func averageAbsoluteError(_ results: [TimesUpLevelResult]) -> TimeInterval {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.absoluteError } / Double(results.count)
    }

    static func meanSignedError(_ results: [TimesUpLevelResult]) -> TimeInterval {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.signedError } / Double(results.count)
    }

    /// Integer milliseconds persisted in `GameResult.score`.
    static func scoreMilliseconds(averageAbsoluteError: TimeInterval) -> Int {
        Int((max(0, averageAbsoluteError) * 1000).rounded())
    }
}

/// Timestamp-driven TIME'S UP state machine. Timing never counts frames.
final class TimesUpGameLogic {
    let config: TimesUpGameConfig

    private(set) var state: TimesUpState = .ready
    private(set) var currentLevelIndex = 0
    private(set) var levelStartTimestamp: TimeInterval?
    private(set) var lastTapTimestamp: TimeInterval?
    private(set) var results: [TimesUpLevelResult] = []
    private(set) var lastSimulationTimestamp: TimeInterval?

    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var stateBeforePause: TimesUpState?
    private var restartLevelOnResume = false
    private var accumulatedPausedTime: TimeInterval = 0

    init(config: TimesUpGameConfig = .reference) {
        self.config = config
    }

    var currentLevelNumber: Int { min(currentLevelIndex + 1, config.resolvedLevelCount) }
    var currentTargetDuration: TimeInterval { config.targetDuration(forLevelIndex: currentLevelIndex) }
    var currentVisibleDuration: TimeInterval { currentTargetDuration * config.resolvedVisibilityFraction }
    var isFinished: Bool { state == .finished }
    var isTiming: Bool {
        switch state {
        case .visible, .hidden: true
        default: false
        }
    }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        guard let levelStartTimestamp, isTiming else { return 0 }
        return max(0, time - levelStartTimestamp)
    }

    func remaining(at time: TimeInterval) -> TimeInterval {
        max(0, currentTargetDuration - elapsed(at: time))
    }

    func progress(at time: TimeInterval) -> Double {
        TimesUpScoring.progress(elapsed: elapsed(at: time), target: currentTargetDuration)
    }

    func isBarVisible(at time: TimeInterval) -> Bool {
        guard state == .visible(level: currentLevelNumber) else { return false }
        return TimesUpScoring.isBarVisible(
            elapsed: elapsed(at: time),
            target: currentTargetDuration,
            visibilityFraction: config.resolvedVisibilityFraction
        )
    }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        if sessionStartTime == nil { sessionStartTime = time }
        beginLevel(index: currentLevelIndex, at: time)
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        switch state {
        case .visible(let level):
            if !TimesUpScoring.isBarVisible(
                elapsed: elapsed(at: time),
                target: currentTargetDuration,
                visibilityFraction: config.resolvedVisibilityFraction
            ) {
                state = .hidden(level: level)
            }
        default:
            break
        }
    }

    @discardableResult
    func handleTap(at time: TimeInterval) -> TimesUpTapOutcome {
        lastTapTimestamp = time
        switch state {
        case .ready:
            start(at: time)
            return .started
        case .visible, .hidden:
            return submitEstimate(at: time)
        case .feedback, .finished, .paused:
            return .ignored
        }
    }

    func startNextLevel(at time: TimeInterval) {
        guard case .feedback = state else { return }
        beginLevel(index: currentLevelIndex + 1, at: time)
    }

    func pause(at time: TimeInterval) {
        guard state != .paused, state != .finished else { return }
        update(at: time)
        restartLevelOnResume = isTiming
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
        levelStartTimestamp = nil
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pauseStartTime { accumulatedPausedTime += max(0, time - pauseStartTime) }
        self.pauseStartTime = nil
        lastSimulationTimestamp = time
        let previous = stateBeforePause
        stateBeforePause = nil
        if restartLevelOnResume {
            restartLevelOnResume = false
            state = .ready
            levelStartTimestamp = nil
            if !config.requiresTapToStart {
                beginLevel(index: currentLevelIndex, at: time)
            }
            return
        }
        switch previous {
        case .ready: state = .ready
        case .feedback(let level): state = .feedback(level: level)
        case .finished: state = .finished
        default: state = .ready
        }
    }

    func reset() {
        state = .ready
        currentLevelIndex = 0
        levelStartTimestamp = nil
        lastTapTimestamp = nil
        results = []
        lastSimulationTimestamp = nil
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        stateBeforePause = nil
        restartLevelOnResume = false
        accumulatedPausedTime = 0
    }

    func makeSummary(at time: TimeInterval) -> TimesUpSessionSummary {
        let end = finishTime ?? time
        let duration = max(0, end - (sessionStartTime ?? end) - accumulatedPausedTime)
        return TimesUpSessionSummary(results: results, duration: duration)
    }

    private func beginLevel(index: Int, at time: TimeInterval) {
        currentLevelIndex = min(max(0, index), config.resolvedLevelCount - 1)
        levelStartTimestamp = time
        if sessionStartTime == nil { sessionStartTime = time }
        state = .visible(level: currentLevelNumber)
        lastSimulationTimestamp = time
        update(at: time)
    }

    private func submitEstimate(at time: TimeInterval) -> TimesUpTapOutcome {
        let elapsed = elapsed(at: time)
        let target = currentTargetDuration
        let signed = TimesUpScoring.signedError(elapsed: elapsed, target: target)
        let result = TimesUpLevelResult(
            levelIndex: currentLevelNumber,
            targetDuration: target,
            visibleDuration: currentVisibleDuration,
            actualElapsed: elapsed,
            signedError: signed,
            absoluteError: abs(signed),
            direction: TimesUpScoring.direction(signedError: signed, exactTolerance: config.exactTolerance),
            tapTimestamp: time
        )
        results.append(result)
        levelStartTimestamp = nil
        if results.count >= config.resolvedLevelCount {
            state = .finished
            finishTime = time
            return .finished(result)
        }
        state = .feedback(level: result.levelIndex)
        return .scored(result)
    }
}
