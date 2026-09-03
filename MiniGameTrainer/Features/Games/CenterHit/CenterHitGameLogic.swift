import Foundation

enum CenterHitGameState: Equatable {
    case ready
    case running
    case paused
    case finished
}

struct CenterHitAttempt: Equatable {
    let attemptNumber: Int
    let tapTimestamp: TimeInterval
    let indicatorX: Double
    let centerX: Double
    let absoluteError: Double
    let normalizedError: Double
    let precision: Double
    let direction: CenterHitDirection
    let speed: Double
}

enum CenterHitTapOutcome: Equatable {
    case ignored
    case started
    case scored(CenterHitAttempt)
    case finished(CenterHitAttempt)
}

enum CenterHitScoring {
    static func precision(
        indicatorX: Double,
        centerX: Double,
        halfWidth: Double,
        perfectCenterHalfWidthRatio: Double = 0,
        exponent: Double = 1,
        coefficient: Double = 1
    ) -> Double {
        guard halfWidth > 0 else { return indicatorX == centerX ? 100 : 0 }
        let absoluteError = abs(indicatorX - centerX)
        let perfectHalfWidth = halfWidth * min(max(perfectCenterHalfWidthRatio, 0), 0.99)
        let effectiveError = max(0, absoluteError - perfectHalfWidth)
        let scoringSpan = max(.ulpOfOne, halfWidth - perfectHalfWidth)
        let normalized = min(max(effectiveError / scoringSpan, 0), 1)
        let loss = max(0, coefficient) * pow(normalized, max(0.01, exponent))
        return min(max(100 * (1 - loss), 0), 100)
    }
}

enum CenterHitMotion {
    /// Folds unbounded travel into a triangular wave, preserving overshoot across any number of
    /// boundary crossings. The returned direction is the velocity after all reflections.
    static func reflected(
        position: Double,
        direction: CenterHitDirection,
        distance: Double,
        left: Double,
        right: Double
    ) -> (position: Double, direction: CenterHitDirection) {
        let length = right - left
        guard length > 0 else { return (left, .right) }
        let period = 2 * length
        let offset = min(max(position, left), right) - left
        let startingPhase = direction == .right ? offset : period - offset
        var folded = (startingPhase + max(0, distance)).truncatingRemainder(dividingBy: period)
        if folded < 0 { folded += period }
        if folded < length {
            return (left + folded, .right)
        }
        return (left + period - folded, .left)
    }
}

/// Timestamp-driven, SpriteKit-independent Center Hit simulation and five-tap state machine.
final class CenterHitGameLogic {
    let config: CenterHitGameConfig
    let leftBoundary: Double
    let rightBoundary: Double

    private(set) var state: CenterHitGameState = .ready
    private(set) var position: Double
    private(set) var direction: CenterHitDirection
    private(set) var attempts: [CenterHitAttempt] = []
    private(set) var lastSimulationTimestamp: TimeInterval?

    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0

    init(config: CenterHitGameConfig, leftBoundary: Double, rightBoundary: Double) {
        self.config = config
        self.leftBoundary = min(leftBoundary, rightBoundary)
        self.rightBoundary = max(leftBoundary, rightBoundary)
        let ratio = min(max(Double(config.initialPositionRatio), 0), 1)
        position = self.leftBoundary + (self.rightBoundary - self.leftBoundary) * ratio
        direction = config.initialDirection
    }

    var travelWidth: Double { rightBoundary - leftBoundary }
    var centerX: Double { (leftBoundary + rightBoundary) / 2 }
    var halfWidth: Double { travelWidth / 2 }
    var currentAttemptNumber: Int { min(attempts.count + 1, max(config.attemptCount, 1)) }
    /// The rendering source for historical tap markers; never duplicates or estimates position.
    var attemptMarkerPositions: [Double] { attempts.map(\.indicatorX) }
    var isFinished: Bool { state == .finished }
    var currentSpeed: Double {
        Double(config.speedRatio(forAttemptIndex: attempts.count)) * travelWidth
    }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        state = .running
        sessionStartTime = time
        lastSimulationTimestamp = time
    }

    func update(at time: TimeInterval) {
        advance(to: time)
    }

    /// Advances analytically to the touch timestamp before reading position, avoiding a stale
    /// previous-frame score when input arrives between 60/120 Hz render updates.
    @discardableResult
    func handleTap(at time: TimeInterval) -> CenterHitTapOutcome {
        if state == .ready {
            start(at: time)
            return .started
        }
        guard state == .running, attempts.count < max(config.attemptCount, 1) else { return .ignored }
        advance(to: time)

        let error = abs(position - centerX)
        let normalizedError = halfWidth > 0 ? min(max(error / halfWidth, 0), 1) : 1
        let precision = CenterHitScoring.precision(
            indicatorX: position,
            centerX: centerX,
            halfWidth: halfWidth,
            perfectCenterHalfWidthRatio: Double(config.perfectCenterHalfWidthRatio),
            exponent: config.precisionExponent,
            coefficient: config.precisionCoefficient
        )
        let attempt = CenterHitAttempt(
            attemptNumber: attempts.count + 1,
            tapTimestamp: max(0, time - (sessionStartTime ?? time) - accumulatedPausedTime),
            indicatorX: position,
            centerX: centerX,
            absoluteError: error,
            normalizedError: normalizedError,
            precision: precision,
            direction: direction,
            speed: currentSpeed
        )
        attempts.append(attempt)

        if attempts.count >= max(config.attemptCount, 1) {
            state = .finished
            finishTime = time
            return .finished(attempt)
        }
        return .scored(attempt)
    }

    func pause(at time: TimeInterval) {
        guard state == .running else { return }
        advance(to: time)
        state = .paused
        pauseStartTime = time
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pauseStartTime { accumulatedPausedTime += max(0, time - pauseStartTime) }
        self.pauseStartTime = nil
        lastSimulationTimestamp = time
        state = .running
    }

    func reset() {
        state = .ready
        let ratio = min(max(Double(config.initialPositionRatio), 0), 1)
        position = leftBoundary + travelWidth * ratio
        direction = config.initialDirection
        attempts = []
        lastSimulationTimestamp = nil
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        accumulatedPausedTime = 0
    }

    func makeSummary(at time: TimeInterval) -> CenterHitSessionSummary {
        let end = finishTime ?? time
        let duration = max(0, end - (sessionStartTime ?? end) - accumulatedPausedTime)
        return CenterHitSessionSummary(attempts: attempts, duration: duration)
    }

    private func advance(to time: TimeInterval) {
        guard state == .running, let previous = lastSimulationTimestamp else { return }
        let elapsed = min(max(0, time - previous), max(0, config.maximumSimulationDelta))
        let result = CenterHitMotion.reflected(
            position: position,
            direction: direction,
            distance: currentSpeed * elapsed,
            left: leftBoundary,
            right: rightBoundary
        )
        position = result.position
        direction = result.direction
        lastSimulationTimestamp = time
    }
}
