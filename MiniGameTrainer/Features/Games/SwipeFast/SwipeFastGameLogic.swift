import CoreGraphics
import Foundation

/// Timestamp-driven SWIPE FAST state machine. SpriteKit-free; tests drive it with monotonic time.
final class SwipeFastGameLogic {
    let config: SwipeFastGameConfig
    let difficulty: SwipeFastDifficultyModel
    let geometry: SwipeFastGeometry
    private(set) var classifier: SwipeFastGestureClassifier

    private(set) var state: SwipeFastGameState = .ready
    private(set) var score = 0
    private(set) var boxes: [SwipeFastBoxState] = []
    private(set) var activeGesture: SwipeFastActiveGesture?
    private(set) var lastSimulationTimestamp: TimeInterval?
    private(set) var endReason: SwipeFastEndReason?
    private(set) var expiredBox: SwipeFastBoxIndex?
    private(set) var correctSwipes = 0
    private(set) var ignoredGestures = 0
    private(set) var wrongSwipes = 0
    private(set) var reactionTimes: [TimeInterval] = []
    private(set) var hasTerminated = false

    var forcedDirections: [SwipeDirection]?
    var scoreOverride: Int?
    var allowedTimeOverride: TimeInterval?
    var wrongSwipeBehaviorOverride: SwipeFastWrongSwipeBehavior?

    private var rng: AnyRandomNumberGenerator
    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0

    init(
        config: SwipeFastGameConfig = .reference,
        sceneSize: CGSize,
        seed: UInt64? = nil
    ) {
        self.config = config
        difficulty = SwipeFastDifficultyModel(config: config)
        geometry = SwipeFastGeometry(sceneSize: sceneSize, config: config)
        classifier = SwipeFastGestureClassifier(
            minimumDistance: geometry.minimumSwipeDistance,
            maximumDuration: config.maximumGestureDuration
        )
        rng = .seeded(seed ?? config.generatorSeed)
        boxes = SwipeFastBoxIndex.allCases.map { _ in
            SwipeFastBoxState(direction: .up, spawnedAt: 0, allowedTime: difficulty.allowedTime(forScore: 0))
        }
    }

    var isFinished: Bool { state == .gameOver }
    var isPlaying: Bool { state == .playing }
    var wrongSwipeBehavior: SwipeFastWrongSwipeBehavior {
        wrongSwipeBehaviorOverride ?? config.wrongSwipeBehavior
    }

    var effectiveScore: Int { scoreOverride ?? score }

    func allowedTime(forScore score: Int) -> TimeInterval {
        allowedTimeOverride ?? difficulty.allowedTime(forScore: score)
    }

    func box(_ index: SwipeFastBoxIndex) -> SwipeFastBoxState {
        boxes[index.rawValue]
    }

    func remainingFraction(of index: SwipeFastBoxIndex, at time: TimeInterval) -> Double {
        box(index).remainingFraction(at: time)
    }

    func barStage(of index: SwipeFastBoxIndex, at time: TimeInterval) -> SwipeFastBarStage {
        config.barStage(remainingFraction: remainingFraction(of: index, at: time))
    }

    func start(at time: TimeInterval) {
        guard state == .ready || state == .paused else { return }
        if state == .paused {
            reset()
        }
        sessionStartTime = time
        lastSimulationTimestamp = time
        score = max(0, scoreOverride ?? 0)
        scoreOverride = nil
        hasTerminated = false
        endReason = nil
        expiredBox = nil
        spawnAll(at: time)
        state = .playing
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        guard state == .playing, !hasTerminated else { return }
        for index in SwipeFastBoxIndex.allCases {
            if boxes[index.rawValue].isExpired(at: time) {
                terminate(reason: .expired, box: index, at: time)
                return
            }
        }
    }

    @discardableResult
    func beginGesture(at location: CGPoint, time: TimeInterval) -> Bool {
        update(at: time)
        guard state == .playing else { return false }
        guard activeGesture == nil else { return false }
        guard let box = geometry.box(containing: location) else { return false }
        activeGesture = SwipeFastActiveGesture(box: box, start: location, startedAt: time, last: location)
        return true
    }

    func moveGesture(at location: CGPoint, time: TimeInterval) {
        guard var gesture = activeGesture else { return }
        gesture.last = location
        activeGesture = gesture
        lastSimulationTimestamp = time
    }

    @discardableResult
    func endGesture(at location: CGPoint, time: TimeInterval) -> SwipeFastInputOutcome {
        update(at: time)
        guard state == .playing else {
            activeGesture = nil
            return .ignored
        }
        guard let gesture = activeGesture else { return .ignored }
        activeGesture = nil
        let duration = max(0, time - gesture.startedAt)
        let classified = classifier.classify(from: gesture.start, to: location, duration: duration)
        guard let classified else {
            ignoredGestures += 1
            return .tooShort
        }
        return resolveSwipe(classified, on: gesture.box, at: time)
    }

    func cancelGesture() {
        activeGesture = nil
    }

    @discardableResult
    func applySwipe(_ direction: SwipeDirection, on box: SwipeFastBoxIndex, at time: TimeInterval) -> SwipeFastInputOutcome {
        update(at: time)
        guard state == .playing else { return .ignored }
        return resolveSwipe(direction, on: box, at: time)
    }

    @discardableResult
    func expire(_ box: SwipeFastBoxIndex, at time: TimeInterval) -> SwipeFastInputOutcome {
        update(at: time)
        guard state == .playing else { return .ignored }
        boxes[box.rawValue].allowedTime = 0
        boxes[box.rawValue].spawnedAt = time
        terminate(reason: .expired, box: box, at: time)
        return .expired(box: box)
    }

    func pause(at time: TimeInterval) {
        guard state == .playing else { return }
        update(at: time)
        pauseStartTime = time
        activeGesture = nil
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

    func makeSummary(at time: TimeInterval? = nil) -> SwipeFastSessionSummary {
        let end = time ?? finishTime ?? lastSimulationTimestamp ?? 0
        let start = sessionStartTime ?? end
        let duration = max(0, end - start - accumulatedPausedTime)
        return SwipeFastSessionSummary(
            score: score,
            duration: duration,
            correctSwipes: correctSwipes,
            ignoredGestures: ignoredGestures,
            wrongSwipes: wrongSwipes,
            expiredBox: expiredBox,
            endReason: endReason,
            averageReactionTime: reactionTimes.isEmpty ? nil : reactionTimes.reduce(0, +) / Double(reactionTimes.count),
            bestReactionTime: reactionTimes.min()
        )
    }

    private func resolveSwipe(
        _ direction: SwipeDirection,
        on box: SwipeFastBoxIndex,
        at time: TimeInterval
    ) -> SwipeFastInputOutcome {
        let current = boxes[box.rawValue]
        guard direction == current.direction else {
            wrongSwipes += 1
            if wrongSwipeBehavior == .gameOver {
                terminate(reason: .wrongSwipe, box: box, at: time)
            }
            return .wrong(box: box, expected: current.direction, actual: direction)
        }
        reactionTimes.append(current.elapsed(at: time))
        score += 1
        correctSwipes += 1
        let newDirection = nextDirection(for: box, excluding: config.avoidImmediateRepeat ? current.direction : nil)
        refill(box, direction: newDirection, at: time)
        return .correct(box: box, score: score, newDirection: newDirection)
    }

    private func spawnAll(at time: TimeInterval) {
        let allowed = allowedTime(forScore: score)
        if let forced = forcedDirections, forced.count == 4 {
            boxes = forced.map { SwipeFastBoxState(direction: $0, spawnedAt: time, allowedTime: allowed) }
        } else {
            boxes = SwipeFastBoxIndex.allCases.map { _ in
                SwipeFastBoxState(direction: randomDirection(excluding: nil), spawnedAt: time, allowedTime: allowed)
            }
        }
    }

    private func refill(_ box: SwipeFastBoxIndex, direction: SwipeDirection, at time: TimeInterval) {
        boxes[box.rawValue] = SwipeFastBoxState(
            direction: direction,
            spawnedAt: time,
            allowedTime: allowedTime(forScore: score)
        )
    }

    private func nextDirection(for box: SwipeFastBoxIndex, excluding: SwipeDirection?) -> SwipeDirection {
        randomDirection(excluding: excluding)
    }

    private func randomDirection(excluding: SwipeDirection?) -> SwipeDirection {
        var choices = SwipeDirection.allCases
        if let excluding {
            choices.removeAll { $0 == excluding }
        }
        if choices.isEmpty { choices = SwipeDirection.allCases }
        let index = Int(rng.next() % UInt64(choices.count))
        return choices[index]
    }

    private func terminate(reason: SwipeFastEndReason, box: SwipeFastBoxIndex, at time: TimeInterval) {
        guard !hasTerminated else { return }
        hasTerminated = true
        endReason = reason
        expiredBox = box
        finishTime = time
        activeGesture = nil
        state = .gameOver
    }

    private func resetPreservingSeed() {
        state = .ready
        score = 0
        activeGesture = nil
        lastSimulationTimestamp = nil
        endReason = nil
        expiredBox = nil
        correctSwipes = 0
        ignoredGestures = 0
        wrongSwipes = 0
        reactionTimes = []
        hasTerminated = false
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        accumulatedPausedTime = 0
        boxes = SwipeFastBoxIndex.allCases.map { _ in
            SwipeFastBoxState(direction: .up, spawnedAt: 0, allowedTime: difficulty.allowedTime(forScore: 0))
        }
    }
}
