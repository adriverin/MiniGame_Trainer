import Foundation

enum TapSevenState: Equatable {
    case ready
    case timing
    case submitted
    case finished
    case paused
}

enum TapSevenTimingDirection: String, Equatable {
    case exact
    case early
    case late
}

enum TapSevenTapOutcome: Equatable {
    case ignored
    case started
    case submitted(TapSevenAttemptResult)
}

enum TapSevenScoring {
    static func signedError(elapsed: TimeInterval, target: TimeInterval) -> TimeInterval {
        elapsed - target
    }

    static func absoluteError(elapsed: TimeInterval, target: TimeInterval) -> TimeInterval {
        abs(signedError(elapsed: elapsed, target: target))
    }

    static func direction(signedError: TimeInterval, perfectThreshold: TimeInterval) -> TapSevenTimingDirection {
        if abs(signedError) < max(0, perfectThreshold) { return .exact }
        return signedError > 0 ? .late : .early
    }

    static func isPerfect(signedError: TimeInterval, perfectThreshold: TimeInterval) -> Bool {
        abs(signedError) < max(0, perfectThreshold)
    }

    /// Linear fill. Holds at 1 after the target so a late tap can still score.
    static func progress(elapsed: TimeInterval, target: TimeInterval) -> Double {
        guard target > 0 else { return 0 }
        return min(max(elapsed / target, 0), 1)
    }

    /// Integer milliseconds persisted in `GameResult.score`.
    static func scoreMilliseconds(absoluteError: TimeInterval) -> Int {
        Int((max(0, absoluteError) * 1000).rounded())
    }
}

enum TapSevenFormatter {
    static func displayedElapsed(_ elapsed: TimeInterval) -> String {
        String(format: "%.2f", max(0, elapsed))
    }

    static func exactElapsed(_ elapsed: TimeInterval) -> String {
        String(format: "%.4f", elapsed)
    }

    static func absoluteError(_ value: TimeInterval) -> String {
        String(format: "%.4f s", abs(value))
    }

    static func seconds(_ value: TimeInterval, signed: Bool = false) -> String {
        let magnitude = String(format: "%.2f", abs(value))
        if signed && value > 0 { return "+\(magnitude) s" }
        return "\(magnitude) s"
    }

    static func bias(_ value: TimeInterval) -> String {
        if abs(value) < 0.0005 { return "0.00 s" }
        let label = value > 0 ? "late" : "early"
        return "\(String(format: "%.2f", abs(value))) s \(label)"
    }

    static func directionCopy(_ direction: TapSevenTimingDirection) -> String {
        switch direction {
        case .exact: "PERFECT"
        case .early: "Early"
        case .late: "Late"
        }
    }
}

struct TapSevenAttemptResult: Equatable {
    let targetDuration: TimeInterval
    let actualElapsed: TimeInterval
    let signedError: TimeInterval
    let absoluteError: TimeInterval
    let isPerfect: Bool
    let direction: TapSevenTimingDirection
    let startTimestamp: TimeInterval
    let tapTimestamp: TimeInterval
    let timedOut: Bool
}

struct TapSevenSessionSummary: Equatable {
    let result: TapSevenAttemptResult
    let duration: TimeInterval

    var scoreMilliseconds: Int {
        TapSevenScoring.scoreMilliseconds(absoluteError: result.absoluteError)
    }
}

/// Timestamp-driven TAP AT 7 state machine. Timing never counts frames.
final class TapSevenGameLogic {
    let config: TapSevenGameConfig

    private(set) var state: TapSevenState = .ready
    private(set) var startTimestamp: TimeInterval?
    private(set) var tapTimestamp: TimeInterval?
    private(set) var result: TapSevenAttemptResult?
    private(set) var lastSimulationTimestamp: TimeInterval?

    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var stateBeforePause: TapSevenState?
    private var restartAttemptOnResume = false
    private var accumulatedPausedTime: TimeInterval = 0
    private var acceptedTouchCount = 0

    init(config: TapSevenGameConfig = .reference) {
        self.config = config
    }

    var isFinished: Bool { state == .finished || state == .submitted }
    var isTiming: Bool { state == .timing }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        if let result { return result.actualElapsed }
        guard let startTimestamp, isTiming else { return 0 }
        return max(0, time - startTimestamp)
    }

    func progress(at time: TimeInterval) -> Double {
        TapSevenScoring.progress(elapsed: elapsed(at: time), target: config.resolvedTargetDuration)
    }

    func displayedElapsed(at time: TimeInterval) -> String {
        TapSevenFormatter.displayedElapsed(elapsed(at: time))
    }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        beginAttempt(at: time)
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        guard state == .timing, let startTimestamp else { return }
        let elapsed = time - startTimestamp
        if elapsed >= config.resolvedMaxAttemptDuration {
            submit(at: startTimestamp + config.resolvedMaxAttemptDuration, timedOut: true)
        }
    }

    @discardableResult
    func handleTap(at time: TimeInterval) -> TapSevenTapOutcome {
        switch state {
        case .ready:
            acceptedTouchCount = 1
            start(at: time)
            return .started
        case .timing:
            guard let startTimestamp, time > startTimestamp else { return .ignored }
            acceptedTouchCount += 1
            return submit(at: time, timedOut: false)
        case .submitted, .finished, .paused:
            return .ignored
        }
    }

    func pause(at time: TimeInterval) {
        guard state != .paused, state != .finished else { return }
        update(at: time)
        restartAttemptOnResume = isTiming
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
        if restartAttemptOnResume {
            startTimestamp = nil
        }
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pauseStartTime { accumulatedPausedTime += max(0, time - pauseStartTime) }
        self.pauseStartTime = nil
        lastSimulationTimestamp = time
        let previous = stateBeforePause
        stateBeforePause = nil
        if restartAttemptOnResume {
            restartAttemptOnResume = false
            result = nil
            tapTimestamp = nil
            acceptedTouchCount = 0
            state = .ready
            startTimestamp = nil
            if !config.requiresTapToStart {
                beginAttempt(at: time)
            }
            return
        }
        switch previous {
        case .ready: state = .ready
        case .submitted: state = .submitted
        case .finished: state = .finished
        default: state = .ready
        }
    }

    func reset() {
        state = .ready
        startTimestamp = nil
        tapTimestamp = nil
        result = nil
        lastSimulationTimestamp = nil
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        stateBeforePause = nil
        restartAttemptOnResume = false
        accumulatedPausedTime = 0
        acceptedTouchCount = 0
    }

    func makeSummary(at time: TimeInterval) -> TapSevenSessionSummary? {
        guard let result else { return nil }
        let end = finishTime ?? time
        let duration = max(0, end - (sessionStartTime ?? end) - accumulatedPausedTime)
        return TapSevenSessionSummary(result: result, duration: duration)
    }

    @discardableResult
    private func submit(at time: TimeInterval, timedOut: Bool) -> TapSevenTapOutcome {
        guard state == .timing, let startTimestamp else { return .ignored }
        let elapsed = max(0, time - startTimestamp)
        let target = config.resolvedTargetDuration
        let signed = TapSevenScoring.signedError(elapsed: elapsed, target: target)
        let attempt = TapSevenAttemptResult(
            targetDuration: target,
            actualElapsed: elapsed,
            signedError: signed,
            absoluteError: abs(signed),
            isPerfect: TapSevenScoring.isPerfect(
                signedError: signed,
                perfectThreshold: config.resolvedPerfectThreshold
            ),
            direction: TapSevenScoring.direction(
                signedError: signed,
                perfectThreshold: config.resolvedPerfectThreshold
            ),
            startTimestamp: startTimestamp,
            tapTimestamp: time,
            timedOut: timedOut
        )
        self.tapTimestamp = time
        result = attempt
        state = .submitted
        finishTime = time
        lastSimulationTimestamp = time
        return .submitted(attempt)
    }

    private func beginAttempt(at time: TimeInterval) {
        startTimestamp = time
        tapTimestamp = nil
        result = nil
        if sessionStartTime == nil { sessionStartTime = time }
        state = .timing
        lastSimulationTimestamp = time
    }

    func markFinished() {
        guard state == .submitted else { return }
        state = .finished
    }
}
