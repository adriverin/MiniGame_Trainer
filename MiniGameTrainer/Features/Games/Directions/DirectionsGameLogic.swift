import Foundation

enum DirectionsGameState: String, Equatable {
    case ready
    case presenting
    case transitionToRecall
    case recalling
    case roundSuccess
    case gameOver
    case paused
}

enum DirectionsInputOutcome: Equatable {
    case ignored
    case started
    case accepted(Direction, index: Int, score: Int)
    case completedRound(score: Int, level: Int)
    case failed(expected: Direction, actual: Direction, index: Int)
}

struct DirectionsSessionSummary: Equatable {
    let score: Int
    let levelReached: Int
    let roundsCompleted: Int
    let correctInputs: Int
    let duration: TimeInterval
    let lastTarget: [Direction]
}

/// Timestamp-driven DIRECTIONS state machine. SpriteKit-free; tests drive it with monotonic time.
final class DirectionsGameLogic {
    let config: DirectionsGameConfig
    let difficulty: DirectionsDifficultyModel
    let generator: DirectionsSequenceGenerator

    private(set) var state: DirectionsGameState = .ready
    private(set) var level = 1
    private(set) var score = 0
    private(set) var target: [Direction] = []
    private(set) var playerInput: [Direction] = []
    private(set) var presentationIndex = 0
    private(set) var isArrowVisible = false
    private(set) var roundsCompleted = 0
    private(set) var correctInputs = 0
    private(set) var lastSimulationTimestamp: TimeInterval?
    private(set) var hasActivePress = false

    var forcedSequence: [Direction]?
    var skipPresentation = false
    var forcedLevel: Int?

    private var rng: AnyRandomNumberGenerator
    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var stateBeforePause: DirectionsGameState?
    private var restartRoundOnResume = false
    private var accumulatedPausedTime: TimeInterval = 0
    private var arrowVisibleUntil: TimeInterval = 0
    private var gapUntil: TimeInterval = 0
    private var recallReadyTime: TimeInterval = 0
    private var nextRoundTime: TimeInterval = 0
    private var gameOverTime: TimeInterval?
    private var scoreAtRoundStart = 0
    private var correctInputsAtRoundStart = 0

    init(config: DirectionsGameConfig = .reference, seed: UInt64? = nil) {
        self.config = config
        difficulty = DirectionsDifficultyModel(config: config)
        generator = DirectionsSequenceGenerator(config: config)
        rng = .seeded(seed ?? config.generatorSeed)
    }

    var sequenceLength: Int { target.count }
    var inputIndex: Int { playerInput.count }
    var isFinished: Bool { state == .gameOver }
    var acceptsInput: Bool { state == .recalling }
    var visibleDirection: Direction? {
        guard state == .presenting, isArrowVisible, target.indices.contains(presentationIndex) else { return nil }
        return target[presentationIndex]
    }

    var phaseLabel: String {
        switch state {
        case .presenting, .transitionToRecall: return "OBSERVE"
        case .recalling: return "YOUR TURN"
        case .roundSuccess: return "CORRECT"
        case .gameOver: return "GAME OVER"
        case .ready: return "TAP TO START"
        case .paused: return "PAUSED"
        }
    }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        sessionStartTime = time
        if let forcedLevel {
            level = max(1, forcedLevel)
            self.forcedLevel = nil
        }
        beginRound(at: time, regenerate: true)
    }

    func update(at time: TimeInterval) {
        lastSimulationTimestamp = time
        switch state {
        case .presenting:
            advancePresentation(at: time)
            if state == .transitionToRecall, time >= recallReadyTime {
                state = .recalling
            }
        case .transitionToRecall:
            if time >= recallReadyTime {
                state = .recalling
            }
        case .roundSuccess:
            if time >= nextRoundTime {
                level += 1
                beginRound(at: time, regenerate: true)
            }
        default:
            break
        }
    }

    @discardableResult
    func handleInput(_ direction: Direction, at time: TimeInterval) -> DirectionsInputOutcome {
        switch state {
        case .ready:
            start(at: time)
            return .started
        case .recalling:
            return acceptRecallInput(direction, at: time)
        case .presenting, .transitionToRecall, .roundSuccess, .gameOver, .paused:
            return .ignored
        }
    }

    func beginPress() -> Bool {
        guard !hasActivePress else { return false }
        hasActivePress = true
        return true
    }

    func endPress() {
        hasActivePress = false
    }

    func pause(at time: TimeInterval) {
        guard state != .paused, state != .gameOver else { return }
        update(at: time)
        restartRoundOnResume = state == .presenting || state == .transitionToRecall || state == .recalling
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
        isArrowVisible = false
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        let pausedAt = pauseStartTime
        if let pausedAt { accumulatedPausedTime += max(0, time - pausedAt) }
        pauseStartTime = nil
        lastSimulationTimestamp = time
        hasActivePress = false
        let previous = stateBeforePause
        stateBeforePause = nil
        if restartRoundOnResume {
            restartRoundOnResume = false
            beginRound(at: time, regenerate: false)
            return
        }
        switch previous {
        case .ready:
            state = .ready
        case .roundSuccess:
            state = .roundSuccess
            if let pausedAt {
                nextRoundTime = time + max(0, nextRoundTime - pausedAt)
            }
        case .gameOver:
            state = .gameOver
        default:
            state = .ready
        }
    }

    func reset() {
        state = .ready
        level = 1
        score = 0
        target = []
        playerInput = []
        presentationIndex = 0
        isArrowVisible = false
        roundsCompleted = 0
        correctInputs = 0
        lastSimulationTimestamp = nil
        hasActivePress = false
        sessionStartTime = nil
        finishTime = nil
        pauseStartTime = nil
        stateBeforePause = nil
        restartRoundOnResume = false
        accumulatedPausedTime = 0
        arrowVisibleUntil = 0
        gapUntil = 0
        recallReadyTime = 0
        nextRoundTime = 0
        gameOverTime = nil
        rng = .seeded(config.generatorSeed)
    }

    func makeSummary(at time: TimeInterval) -> DirectionsSessionSummary {
        let end = finishTime ?? time
        let duration = max(0, end - (sessionStartTime ?? end) - accumulatedPausedTime)
        return DirectionsSessionSummary(
            score: score,
            levelReached: level,
            roundsCompleted: roundsCompleted,
            correctInputs: correctInputs,
            duration: duration,
            lastTarget: target
        )
    }

    func presentationEndTime(from start: TimeInterval) -> TimeInterval {
        start + difficulty.presentationDuration(forSequenceLength: sequenceLength)
    }

    private func beginRound(at time: TimeInterval, regenerate: Bool) {
        playerInput = []
        presentationIndex = 0
        hasActivePress = false
        lastSimulationTimestamp = time
        if sessionStartTime == nil { sessionStartTime = time }
        if regenerate {
            scoreAtRoundStart = score
            correctInputsAtRoundStart = correctInputs
            let length = difficulty.sequenceLength(forLevel: level)
            if let forcedSequence, !forcedSequence.isEmpty {
                target = forcedSequence
            } else {
                target = generator.generate(length: length, rng: &rng)
            }
        } else {
            score = scoreAtRoundStart
            correctInputs = correctInputsAtRoundStart
        }
        let skipThisPresentation = skipPresentation && regenerate
        if skipThisPresentation || target.isEmpty {
            isArrowVisible = false
            state = .recalling
            return
        }
        isArrowVisible = true
        arrowVisibleUntil = time + difficulty.arrowOnDuration(forLevel: level)
        state = .presenting
    }

    private func advancePresentation(at time: TimeInterval) {
        let onDuration = difficulty.arrowOnDuration(forLevel: level)
        let gap = difficulty.interArrowGap(forLevel: level)
        var steps = 0
        while state == .presenting, steps < 64 {
            steps += 1
            if isArrowVisible {
                guard time >= arrowVisibleUntil else { return }
                isArrowVisible = false
                if presentationIndex >= target.count - 1 {
                    state = .transitionToRecall
                    recallReadyTime = arrowVisibleUntil + max(0, config.transitionToRecallDuration)
                    return
                }
                gapUntil = arrowVisibleUntil + gap
                continue
            }
            guard time >= gapUntil else { return }
            presentationIndex += 1
            isArrowVisible = true
            arrowVisibleUntil = gapUntil + onDuration
        }
    }

    private func acceptRecallInput(_ direction: Direction, at time: TimeInterval) -> DirectionsInputOutcome {
        guard target.indices.contains(playerInput.count) else { return .ignored }
        let index = playerInput.count
        let expected = target[index]
        if direction != expected {
            if config.failsOnFirstWrongInput {
                state = .gameOver
                finishTime = time
                gameOverTime = time
                isArrowVisible = false
            }
            return .failed(expected: expected, actual: direction, index: index)
        }
        playerInput.append(direction)
        score += config.pointsPerCorrectInput
        correctInputs += 1
        if playerInput.count == target.count {
            roundsCompleted += 1
            state = .roundSuccess
            nextRoundTime = time + max(0, config.roundSuccessHoldDuration)
            return .completedRound(score: score, level: level)
        }
        return .accepted(direction, index: index, score: score)
    }
}
