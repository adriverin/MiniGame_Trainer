import CoreGraphics
import Foundation

/// SpriteKit-independent TRACE state machine, scoring, generator, and hit tests.
final class TraceGameLogic {
    let config: TraceGameConfig
    let difficulty: TraceDifficultyModel
    private(set) var geometry: TraceGeometry
    private(set) var phase: TracePhase = .ready
    private(set) var score = 0
    private(set) var roundIndex = 0
    private(set) var grid = TraceGridSize.smallest
    private(set) var targetSequence: [TraceNode] = []
    private(set) var playerSequence: [TraceNode] = []
    private(set) var visibleReferenceCount = 0
    private(set) var lastTouch: CGPoint?
    private(set) var isTouching = false
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var patternElapsed: TimeInterval = 0
    private(set) var recallElapsed: TimeInterval = 0
    private(set) var recallDuration: TimeInterval = 0
    private(set) var lastFailure: TraceFailureReason?
    private(set) var patternsCompleted = 0
    private(set) var patternsFailed = 0
    private(set) var segmentsScored = 0
    private(set) var seed: UInt64
    var scoreOverride: Int?
    var forcedGrid: TraceGridSize?
    var forcedTargetCount: Int?
    var forcedPattern: [TraceNode]?
    var skipPresentation = false

    private var rng: AnyRandomNumberGenerator
    private var generator: TracePatternGenerator
    private var events: [TraceEvent] = []
    private var scoreAtPatternStart = 0
    private var storedPhaseBeforePause: TracePhase?
    private var transitionRemaining: TimeInterval = 0
    private var evaluationRemaining: TimeInterval = 0

    init(config: TraceGameConfig, sceneSize: CGSize, seed: UInt64? = nil) {
        self.config = config
        difficulty = TraceDifficultyModel(config: config)
        grid = difficulty.grid(forScore: 0)
        geometry = TraceGeometry(sceneSize: sceneSize, config: config, grid: grid)
        generator = TracePatternGenerator(config: config)
        self.seed = seed ?? 0x54_52_41_43_45
        rng = .seeded(seed)
    }

    var isFinished: Bool { phase == .gameOver }
    var acceptsInput: Bool { phase == .awaitingTrace || phase == .tracing }
    var segmentCount: Int { max(0, targetSequence.count - 1) }
    var recallRemaining: TimeInterval { max(0, recallDuration - recallElapsed) }
    var timerProgress: CGFloat {
        guard phase == .awaitingTrace || phase == .tracing, recallDuration > 0 else { return 0 }
        return CGFloat(min(max(recallRemaining / recallDuration, 0), 1))
    }
    var effectiveScoreForDifficulty: Int { scoreOverride ?? score }
    var currentDifficultyStage: Int { difficulty.stageIndex(forScore: effectiveScoreForDifficulty) }

    func resize(sceneSize: CGSize) {
        geometry = TraceGeometry(sceneSize: sceneSize, config: config, grid: grid)
    }

    func start() {
        guard phase == .ready || phase == .gameOver else { return }
        resetSession()
        if let scoreOverride { score = max(0, scoreOverride) }
        beginPattern()
    }

    func reset() {
        resetSession()
        phase = .ready
    }

    func update(deltaTime: TimeInterval) {
        let delta = min(max(0, deltaTime), max(0, config.maximumFrameDelta))
        guard delta > 0, phase != .paused, phase != .gameOver, phase != .ready else { return }
        elapsedTime += delta
        if config.sessionDuration > 0, elapsedTime >= config.sessionDuration {
            endSession()
            return
        }
        switch phase {
        case .showingPattern:
            patternElapsed += delta
            advanceReveal()
        case .awaitingTrace, .tracing:
            recallElapsed += delta
            if recallElapsed >= recallDuration {
                failPattern(.recallTimeout)
            }
        case .evaluating:
            evaluationRemaining -= delta
            if evaluationRemaining <= 0 { enterTransition() }
        case .transitioning:
            transitionRemaining -= delta
            if transitionRemaining <= 0 { beginPattern() }
        default:
            break
        }
    }

    func beginTouch(position: CGPoint) {
        guard acceptsInput else { return }
        isTouching = true
        lastTouch = position
        if let node = geometry.node(at: position) {
            _ = accept(node)
        }
    }

    func moveTouch(position: CGPoint) {
        guard isTouching, acceptsInput else { return }
        lastTouch = position
        if let node = geometry.node(at: position) {
            _ = accept(node)
        }
    }

    func endTouch() {
        guard isTouching else { return }
        isTouching = false
        lastTouch = nil
        guard phase == .tracing, playerSequence != targetSequence else { return }
        failPattern(.incompleteLift)
    }

    @discardableResult
    func accept(_ node: TraceNode) -> TraceAcceptResult {
        guard acceptsInput, geometry.contains(node) else { return .ignored }
        if playerSequence.last == node { return .duplicate }
        if playerSequence.isEmpty {
            let expected = config.acceptReverseSequence ? [targetSequence.first, targetSequence.last] : [targetSequence.first]
            guard expected.contains(where: { $0 == node }) else {
                failPattern(.wrongNode)
                return .rejected
            }
            if config.acceptReverseSequence, node == targetSequence.last, node != targetSequence.first {
                targetSequence.reverse()
            }
            playerSequence = [node]
            phase = .tracing
            emit(.nodeAccepted(node, scoreDelta: 0))
            return .accepted(node: node, scoreDelta: 0, completed: false)
        }
        let expectedIndex = playerSequence.count
        guard expectedIndex < targetSequence.count else { return .ignored }
        let expected = targetSequence[expectedIndex]
        if config.requireAdjacentSteps, let last = playerSequence.last, !TraceHexNeighbors.isNeighbor(last, node) {
            failPattern(.wrongNode)
            return .rejected
        }
        guard node == expected else {
            failPattern(.wrongNode)
            return .rejected
        }
        playerSequence.append(node)
        let delta = max(0, config.pointsPerCorrectSegment)
        score += delta
        segmentsScored += delta
        emit(.nodeAccepted(node, scoreDelta: delta))
        if playerSequence == targetSequence {
            completePattern()
            return .accepted(node: node, scoreDelta: delta, completed: true)
        }
        return .accepted(node: node, scoreDelta: delta, completed: false)
    }

    func pause() {
        guard phase != .paused, phase != .gameOver, phase != .ready else { return }
        storedPhaseBeforePause = phase
        phase = .paused
        isTouching = false
        lastTouch = nil
    }

    func resume() {
        guard phase == .paused else { return }
        let restored = storedPhaseBeforePause ?? .awaitingTrace
        storedPhaseBeforePause = nil
        if config.restartPatternOnBackground, restored == .showingPattern || restored == .awaitingTrace || restored == .tracing || restored == .evaluating {
            restartCurrentPattern()
        } else {
            phase = restored
        }
    }

    func restartCurrentPattern() {
        score = scoreAtPatternStart
        playerSequence = []
        lastFailure = nil
        isTouching = false
        lastTouch = nil
        visibleReferenceCount = 0
        patternElapsed = 0
        recallElapsed = 0
        if skipPresentation {
            phase = .awaitingTrace
            emit(.patternStarted(sequence: targetSequence, grid: grid))
            emit(.patternHidden)
            return
        }
        phase = .showingPattern
        advanceReveal()
        emit(.patternStarted(sequence: targetSequence, grid: grid))
    }

    func applyDebugSolve(correct: Bool) {
        guard acceptsInput, !targetSequence.isEmpty else { return }
        if correct {
            for node in targetSequence {
                if phase == .gameOver { break }
                _ = accept(node)
            }
        } else if let start = targetSequence.first {
            _ = accept(start)
            let wrong = TraceHexNeighbors.neighbors(of: start)
                .first { geometry.contains($0) && $0 != targetSequence.dropFirst().first }
            if let wrong {
                _ = accept(wrong)
            }
        }
    }

    func drainEvents() -> [TraceEvent] {
        defer { events.removeAll() }
        return events
    }

    func makeSummary() -> TraceSessionSummary {
        let attempts = patternsCompleted + patternsFailed
        return TraceSessionSummary(
            score: score,
            duration: elapsedTime,
            patternsCompleted: patternsCompleted,
            patternsFailed: patternsFailed,
            segmentsScored: segmentsScored,
            accuracy: attempts == 0 ? nil : Double(patternsCompleted) / Double(attempts)
        )
    }

    private func resetSession() {
        score = 0
        roundIndex = 0
        elapsedTime = 0
        patternsCompleted = 0
        patternsFailed = 0
        segmentsScored = 0
        lastFailure = nil
        playerSequence = []
        targetSequence = []
        isTouching = false
        lastTouch = nil
        events.removeAll()
        storedPhaseBeforePause = nil
    }

    private func beginPattern() {
        lastFailure = nil
        playerSequence = []
        isTouching = false
        lastTouch = nil
        let difficultyScore = effectiveScoreForDifficulty
        grid = forcedGrid ?? difficulty.grid(forScore: difficultyScore)
        geometry = TraceGeometry(sceneSize: geometry.sceneSize, config: config, grid: grid)
        let length = forcedTargetCount ?? difficulty.samplePathLength(forScore: difficultyScore, grid: grid, rng: &rng)
        if let forcedPattern, generator.isValid(forcedPattern, grid: grid, requireAdjacent: config.requireAdjacentSteps) {
            targetSequence = forcedPattern
        } else {
            targetSequence = generator.generate(grid: grid, length: length, rng: &rng)
        }
        recallDuration = difficulty.recallDuration(segmentCount: max(0, targetSequence.count - 1))
        recallElapsed = 0
        patternElapsed = 0
        visibleReferenceCount = 0
        scoreAtPatternStart = score
        if skipPresentation {
            visibleReferenceCount = 0
            phase = .awaitingTrace
            recallElapsed = 0
            emit(.patternStarted(sequence: targetSequence, grid: grid))
            emit(.patternHidden)
            return
        }
        phase = .showingPattern
        advanceReveal()
        emit(.patternStarted(sequence: targetSequence, grid: grid))
    }

    private func advanceReveal() {
        guard phase == .showingPattern, !targetSequence.isEmpty else { return }
        let reveal = max(0, config.segmentRevealDuration)
        let hold = max(0, config.patternHoldDuration)
        let segments = max(0, targetSequence.count - 1)
        let revealEnd = TimeInterval(segments) * reveal
        let desired: Int
        if reveal <= 0 {
            desired = targetSequence.count
        } else {
            desired = min(targetSequence.count, 1 + Int(patternElapsed / reveal))
        }
        if desired != visibleReferenceCount {
            visibleReferenceCount = desired
            emit(.revealAdvanced(visibleCount: visibleReferenceCount))
        }
        if patternElapsed >= revealEnd + hold {
            visibleReferenceCount = 0
            phase = .awaitingTrace
            recallElapsed = 0
            emit(.patternHidden)
        }
    }

    private func completePattern() {
        patternsCompleted += 1
        roundIndex += 1
        isTouching = false
        lastTouch = nil
        phase = .evaluating
        evaluationRemaining = max(0, config.evaluationDuration)
        emit(.patternCompleted)
    }

    private func failPattern(_ reason: TraceFailureReason) {
        guard phase == .awaitingTrace || phase == .tracing else { return }
        lastFailure = reason
        patternsFailed += 1
        roundIndex += 1
        isTouching = false
        lastTouch = nil
        emit(.patternFailed(reason))
        if (reason == .wrongNode && config.wrongNodeEndsSession)
            || (reason == .incompleteLift && config.incompleteLiftEndsSession)
            || (reason == .recallTimeout && config.timeoutEndsSession) {
            endSession()
            return
        }
        phase = .evaluating
        evaluationRemaining = max(0, config.evaluationDuration)
    }

    private func enterTransition() {
        phase = .transitioning
        transitionRemaining = max(0, config.transitionDuration)
        playerSequence = []
        visibleReferenceCount = 0
        lastTouch = nil
    }

    private func endSession() {
        phase = .gameOver
        isTouching = false
        lastTouch = nil
        emit(.sessionEnded)
    }

    private func emit(_ event: TraceEvent) { events.append(event) }
}
