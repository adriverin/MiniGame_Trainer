import Foundation

enum GridGameState: Equatable {
    case ready
    case presentingPattern
    case recalling
    case evaluating
    case feedback
    case nextRound
    case timedOut
    case gameOver
}

enum GridRoundOutcome: Equatable {
    case correct
    case incorrect
    case timedOut
}

enum GridInputResult: Equatable {
    case ignored
    case toggled(GridCell, selected: Bool)
    case submitted(correct: Bool)
    case timedOut
}

enum GridGameEvent: Equatable {
    case startedPresenting
    case startedRecalling
    case cellToggled(GridCell, selected: Bool)
    case submitted(correct: Bool)
    case timedOut
    case advancedToLevel(Int)
    case finished(GridRoundOutcome)
}

struct GridRoundRecord: Equatable {
    let level: Int
    let rows: Int
    let columns: Int
    let targetCount: Int
    let outcome: GridRoundOutcome
    let scoreBefore: Int
    let scoreAfter: Int
    let presentationDuration: TimeInterval
    let recallDuration: TimeInterval
}

struct GridSessionSummary: Equatable {
    let score: Int
    let levelReached: Int
    let roundsCompleted: Int
    let duration: TimeInterval
    let rounds: [GridRoundRecord]
}

/// SpriteKit-independent GRID state machine: pattern generation, toggling, set evaluation,
/// scoring and level progression.
final class GridGameLogic {
    let config: GridGameConfig
    private(set) var stage: GridStage
    private var generator: AnyRandomNumberGenerator
    private let seed: UInt64?

    private(set) var state: GridGameState = .ready
    private(set) var level = 1
    private(set) var score = 0
    private(set) var targetCells: Set<GridCell> = []
    private(set) var selectedCells: Set<GridCell> = []
    private(set) var rounds: [GridRoundRecord] = []
    private(set) var lastOutcome: GridRoundOutcome?
    private(set) var elapsedTime: TimeInterval = 0

    var forcedPattern: Set<GridCell>?
    var forcedRows: Int?
    var forcedColumns: Int?
    var forcedTargetCount: Int?
    var forcedLevel: Int?

    private var sessionStart: TimeInterval?
    private var phaseStart: TimeInterval?
    private var recallStart: TimeInterval?
    private var finishTime: TimeInterval?
    private var pauseStart: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0
    private var events: [GridGameEvent] = []
    private var presentationDurationOverride: TimeInterval?
    private var recallTimeoutOverride: TimeInterval?

    init(config: GridGameConfig, seed: UInt64? = nil) {
        self.config = config
        self.seed = seed
        generator = .seeded(seed)
        stage = GridDifficultyModel.stage(forLevel: 1, config: config)
    }

    var isFinished: Bool { state == .gameOver }
    var canSelectCells: Bool { state == .recalling }
    var canSubmit: Bool { state == .recalling }
    var highlightedCells: Set<GridCell> {
        switch state {
        case .presentingPattern: return targetCells
        case .recalling, .evaluating, .feedback: return selectedCells
        default: return []
        }
    }

    var recallElapsed: TimeInterval {
        guard state == .recalling, let recallStart else { return 0 }
        return max(0, elapsedTime - recallStart)
    }

    var recallRemaining: TimeInterval {
        max(0, currentRecallTimeout - recallElapsed)
    }

    var presentationElapsed: TimeInterval {
        guard state == .presentingPattern, let phaseStart else { return 0 }
        return max(0, elapsedTime - phaseStart)
    }

    var currentPresentationDuration: TimeInterval {
        presentationDurationOverride ?? stage.presentationDuration
    }

    var currentRecallTimeout: TimeInterval {
        recallTimeoutOverride ?? stage.recallTimeout
    }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        sessionStart = time
        elapsedTime = 0
        beginRound(at: time, advancingLevel: false)
    }

    func update(at time: TimeInterval) {
        guard state != .gameOver, pauseStart == nil else { return }
        elapsedTime = activeElapsed(at: time)
        switch state {
        case .presentingPattern:
            if elapsedTime - (phaseStart ?? elapsedTime) >= currentPresentationDuration {
                beginRecall(at: time)
            }
        case .recalling:
            if elapsedTime - (recallStart ?? elapsedTime) >= currentRecallTimeout {
                registerTimeout(at: time)
            }
        case .feedback:
            if elapsedTime - (phaseStart ?? elapsedTime) >= config.feedbackDuration {
                if lastOutcome == .correct {
                    beginRound(at: time, advancingLevel: true)
                } else {
                    finish(at: time, reason: lastOutcome ?? .incorrect)
                }
            }
        default:
            break
        }
    }

    @discardableResult
    func tapCell(_ cell: GridCell) -> GridInputResult {
        guard state == .recalling else { return .ignored }
        guard (0..<stage.rows).contains(cell.row), (0..<stage.columns).contains(cell.column) else {
            return .ignored
        }
        if selectedCells.contains(cell) {
            guard config.allowsDeselection else { return .ignored }
            selectedCells.remove(cell)
            events.append(.cellToggled(cell, selected: false))
            return .toggled(cell, selected: false)
        }
        selectedCells.insert(cell)
        events.append(.cellToggled(cell, selected: true))
        return .toggled(cell, selected: true)
    }

    @discardableResult
    func submit() -> GridInputResult {
        guard state == .recalling else { return .ignored }
        state = .evaluating
        let correct = selectedCells == targetCells
        let outcome: GridRoundOutcome = correct ? .correct : .incorrect
        applyOutcome(outcome, recallDuration: recallElapsed)
        events.append(.submitted(correct: correct))
        if correct || !config.incorrectSubmitEndsRun {
            lastOutcome = correct ? .correct : .incorrect
            state = .feedback
            phaseStart = elapsedTime
        } else {
            lastOutcome = .incorrect
            state = .feedback
            phaseStart = elapsedTime
        }
        return .submitted(correct: correct)
    }

    func restartCurrentRound(at time: TimeInterval) {
        guard state != .gameOver else { return }
        selectedCells.removeAll()
        targetCells.removeAll()
        lastOutcome = nil
        elapsedTime = activeElapsed(at: time)
        beginRound(at: time, advancingLevel: false)
    }

    func pause(at time: TimeInterval) {
        guard pauseStart == nil, state != .gameOver else { return }
        elapsedTime = activeElapsed(at: time)
        pauseStart = time
    }

    func resume(at time: TimeInterval) {
        guard let pauseStart else { return }
        accumulatedPausedTime += max(0, time - pauseStart)
        self.pauseStart = nil
        restartCurrentRound(at: time)
    }

    func reset() {
        generator = .seeded(seed)
        state = .ready
        level = forcedLevel ?? 1
        score = 0
        targetCells.removeAll()
        selectedCells.removeAll()
        rounds.removeAll()
        lastOutcome = nil
        elapsedTime = 0
        sessionStart = nil
        phaseStart = nil
        recallStart = nil
        finishTime = nil
        pauseStart = nil
        accumulatedPausedTime = 0
        events.removeAll()
        refreshStage()
    }

    func drainEvents() -> [GridGameEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func makeSummary(at time: TimeInterval) -> GridSessionSummary {
        let end = finishTime ?? activeElapsed(at: time)
        return GridSessionSummary(
            score: score,
            levelReached: level,
            roundsCompleted: rounds.filter { $0.outcome == .correct }.count,
            duration: max(0, end),
            rounds: rounds
        )
    }

    func applyDebugOverrides(
        level: Int?,
        rows: Int?,
        columns: Int?,
        targetCount: Int?,
        presentationDuration: TimeInterval?,
        recallTimeout: TimeInterval?,
        forcedPattern: Set<GridCell>?
    ) {
        forcedLevel = level.map { max(1, $0) }
        forcedRows = rows
        forcedColumns = columns
        forcedTargetCount = targetCount
        presentationDurationOverride = presentationDuration
        recallTimeoutOverride = recallTimeout
        self.forcedPattern = forcedPattern
        if let level { self.level = max(1, level) }
        refreshStage()
    }

    func fillCorrectSelectionForDebug() {
        guard state == .recalling else { return }
        selectedCells = targetCells
    }

    private func beginRound(at time: TimeInterval, advancingLevel: Bool) {
        if advancingLevel {
            level += 1
            events.append(.advancedToLevel(level))
        }
        refreshStage()
        selectedCells.removeAll()
        targetCells = GridDifficultyModel.generatePattern(
            rows: stage.rows,
            columns: stage.columns,
            count: stage.targetCount,
            generator: &generator,
            forced: forcedPattern
        )
        state = .presentingPattern
        phaseStart = elapsedTime
        recallStart = nil
        lastOutcome = nil
        events.append(.startedPresenting)
        _ = time
    }

    private func beginRecall(at time: TimeInterval) {
        guard state == .presentingPattern else { return }
        selectedCells.removeAll()
        state = .recalling
        recallStart = elapsedTime
        events.append(.startedRecalling)
        _ = time
    }

    private func registerTimeout(at time: TimeInterval) {
        guard state == .recalling else { return }
        state = .timedOut
        applyOutcome(.timedOut, recallDuration: currentRecallTimeout)
        events.append(.timedOut)
        lastOutcome = .timedOut
        if config.timeoutEndsRun {
            state = .feedback
            phaseStart = elapsedTime
        } else {
            state = .feedback
            phaseStart = elapsedTime
        }
        _ = time
    }

    private func applyOutcome(_ outcome: GridRoundOutcome, recallDuration: TimeInterval) {
        let before = score
        if outcome == .correct {
            score += targetCells.count
        }
        rounds.append(
            GridRoundRecord(
                level: level,
                rows: stage.rows,
                columns: stage.columns,
                targetCount: targetCells.count,
                outcome: outcome,
                scoreBefore: before,
                scoreAfter: score,
                presentationDuration: currentPresentationDuration,
                recallDuration: recallDuration
            )
        )
    }

    private func finish(at time: TimeInterval, reason: GridRoundOutcome) {
        state = .gameOver
        finishTime = elapsedTime
        events.append(.finished(reason))
        _ = time
    }

    private func refreshStage() {
        var resolved = GridDifficultyModel.stage(forLevel: forcedLevel ?? level, config: config)
        let rows = max(1, forcedRows ?? resolved.rows)
        let columns = max(1, forcedColumns ?? resolved.columns)
        let targets = forcedPattern.map(\.count) ?? forcedTargetCount ?? resolved.targetCount
        resolved = GridStage(
            level: forcedLevel ?? level,
            rows: rows,
            columns: columns,
            targetCount: min(max(1, targets), rows * columns),
            presentationDuration: presentationDurationOverride ?? resolved.presentationDuration,
            recallTimeout: recallTimeoutOverride ?? resolved.recallTimeout
        )
        stage = resolved
    }

    private func activeElapsed(at time: TimeInterval) -> TimeInterval {
        max(0, time - (sessionStart ?? time) - accumulatedPausedTime)
    }
}
