import CoreGraphics
import Foundation

/// Framework-free simulation of the Piano game: state machine, scrolling column, spawning,
/// hit/miss evaluation, scoring and performance tracking. `PianoGameScene` renders it.
///
/// All positions are in points, screen-down coordinates (see `PianoGeometry`).
final class PianoGameLogic {
    let config: PianoGameConfig
    let geometry: PianoGeometry
    let difficulty: PianoDifficultyModel

    private(set) var state: PianoGameState = .ready
    private(set) var score: Int = 0
    /// Active play time in seconds; does not advance during countdown, waiting or pause.
    private(set) var elapsedTime: TimeInterval = 0
    /// Ordered top → bottom (index 0 is the newest, highest row).
    private(set) var rows: [PianoRow] = []
    private(set) var peakSpeed: CGFloat = 0
    private(set) var lastReactionTime: TimeInterval?
    private(set) var rowsSpawned: Int = 0

    private var spawner: PianoSpawner
    private var tracker = PianoPerformanceTracker()
    private var pendingEvents: [PianoGameEvent] = []
    private var stateBeforePause: PianoGameState?

    init(config: PianoGameConfig, geometry: PianoGeometry) {
        self.config = config
        self.geometry = geometry
        difficulty = PianoDifficultyModel(config: config)
        spawner = PianoSpawner(config: config)
        layoutInitialRows()
    }

    convenience init(config: PianoGameConfig, sceneSize: CGSize) {
        self.init(config: config, geometry: PianoGeometry(sceneSize: sceneSize, config: config))
    }

    // MARK: - Derived values

    /// Current scroll speed in points per second.
    var speed: CGFloat {
        difficulty.speed(forScore: score, geometry: geometry)
    }

    var spawnInterval: TimeInterval {
        difficulty.spawnInterval(forScore: score, geometry: geometry)
    }

    var activeTileCount: Int {
        rows.reduce(0) { $0 + $1.tiles.filter { $0.state == .active }.count }
    }

    var allTiles: [PianoTile] {
        rows.flatMap(\.tiles)
    }

    /// Lowest row that still has an active tile (the one the player should tap next).
    var lowestActiveRow: PianoRow? {
        rows.last { $0.hasActiveTiles }
    }

    var mistakesEndGame: Bool {
        if case .timer = config.endCondition { return false }
        return true
    }

    // MARK: - Session control

    func reset() {
        score = 0
        elapsedTime = 0
        rows.removeAll(keepingCapacity: true)
        rowsSpawned = 0
        peakSpeed = 0
        lastReactionTime = nil
        stateBeforePause = nil
        spawner = PianoSpawner(config: config)
        tracker.reset()
        pendingEvents.removeAll(keepingCapacity: true)
        layoutInitialRows()
        setState(.ready)
    }

    func beginCountdown() {
        guard state == .ready else { return }
        setState(.countdown)
    }

    /// Called by the scene when "GO" has been shown (or immediately when the countdown is skipped).
    func finishCountdown() {
        guard state == .countdown || state == .ready else { return }
        if config.requiresTapToStart {
            setState(.waitingForStart)
        } else {
            startPlaying()
        }
    }

    func startPlaying() {
        guard state == .waitingForStart || state == .countdown || state == .ready else { return }
        setState(.playing)
    }

    func pause() {
        switch state {
        case .playing, .waitingForStart, .countdown:
            stateBeforePause = state
            setState(.paused)
        default:
            break
        }
    }

    func resume() {
        guard state == .paused else { return }
        setState(stateBeforePause ?? .playing)
        stateBeforePause = nil
    }

    func abort() {
        end(reason: .aborted)
    }

    // MARK: - Frame update

    func update(deltaTime rawDelta: TimeInterval) {
        guard state == .playing else { return }
        let delta = min(max(0, rawDelta), config.maximumFrameDelta)
        elapsedTime += delta

        let currentSpeed = speed
        peakSpeed = max(peakSpeed, currentSpeed)
        let distance = currentSpeed * CGFloat(delta)
        for index in rows.indices {
            rows[index].top += distance
        }

        markNewlyVisibleTiles()
        fillRowsAbovePlayfield()
        recycleOffscreenRows()
        evaluateMissedTiles()
        evaluateTimer()
    }

    // MARK: - Input

    /// `point` is in screen-down coordinates. Returns the outcome synchronously.
    @discardableResult
    func handleTap(at point: CGPoint) -> PianoTapOutcome {
        switch state {
        case .waitingForStart:
            startPlaying()
            if config.startTapConsumesTile, let target = activeTile(at: point) {
                registerHit(rowIndex: target.rowIndex, tileIndex: target.tileIndex)
                return .hit(rows[target.rowIndex].tiles[target.tileIndex])
            }
            return .started
        case .playing:
            break
        default:
            return .ignored
        }

        let insidePlayfield = point.y >= geometry.playfieldTop
            && point.x >= 0 && point.x < geometry.sceneSize.width
        guard insidePlayfield else {
            return config.ignoreTapsOutsidePlayfield ? .ignored : registerWrongTap(at: point)
        }

        guard let lane = geometry.lane(forX: point.x),
              let rowIndex = rows.firstIndex(where: { point.y >= $0.top && point.y < $0.bottom(rowHeight: geometry.rowHeight) })
        else {
            return config.emptyTapEndsGame ? registerWrongTap(at: point) : .ignored
        }

        let row = rows[rowIndex]
        guard let tileIndex = row.tiles.firstIndex(where: { $0.lane == lane }) else {
            return config.emptyTapEndsGame ? registerWrongTap(at: point) : .ignored
        }

        switch row.tiles[tileIndex].state {
        case .active:
            if config.requireLowestRowFirst, let lowest = lowestActiveRow, lowest.id != row.id {
                return registerWrongTap(at: point)
            }
            registerHit(rowIndex: rowIndex, tileIndex: tileIndex)
            return .hit(rows[rowIndex].tiles[tileIndex])
        case .hit:
            return config.consumedTileTapEndsGame ? registerWrongTap(at: point) : .ignored
        case .missed:
            return .ignored
        }
    }

    // MARK: - Events / results

    func drainEvents() -> [PianoGameEvent] {
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        return events
    }

    func makeSummary() -> PianoSessionSummary {
        let reason: PianoGameOverReason
        if case .gameOver(let r) = state {
            reason = r
        } else {
            reason = .aborted
        }
        return tracker.summary(
            score: score,
            duration: elapsedTime,
            peakSpeed: peakSpeed / max(1, geometry.sceneSize.height),
            reason: reason
        )
    }

    // MARK: - Rows

    private func layoutInitialRows() {
        let lowestTop = geometry.playfieldTop + config.initialLowestRowTopOffset * geometry.rowHeight
        for index in 0..<max(1, config.initialRowCount) {
            insertRowOnTop(top: lowestTop - CGFloat(index) * geometry.rowHeight)
        }
        fillRowsAbovePlayfield()
        markNewlyVisibleTiles()
    }

    /// Keeps one fully hidden row above the playfield so the column never shows a gap.
    private func fillRowsAbovePlayfield() {
        let spawnThreshold = geometry.playfieldTop - geometry.rowHeight
        while let topRow = rows.first, topRow.top > spawnThreshold {
            insertRowOnTop(top: topRow.top - geometry.rowHeight)
        }
        if rows.isEmpty {
            insertRowOnTop(top: spawnThreshold)
        }
    }

    private func insertRowOnTop(top: CGFloat) {
        let plan = spawner.nextRow(score: score)
        let rowIndex = rowsSpawned
        rowsSpawned += 1
        let tiles = plan.lanes.map { PianoTile(lane: $0, rowIndex: rowIndex) }
        let row = PianoRow(id: rowIndex, primaryLane: plan.primaryLane, top: top, tiles: tiles)
        rows.insert(row, at: 0)
        for tile in tiles {
            emit(.tileSpawned(tile))
        }
    }

    private func recycleOffscreenRows() {
        while let last = rows.last, last.top >= geometry.recycleY {
            rows.removeLast()
        }
    }

    private func markNewlyVisibleTiles() {
        for rowIndex in rows.indices {
            let row = rows[rowIndex]
            guard row.bottom(rowHeight: geometry.rowHeight) > geometry.playfieldTop else { continue }
            for tileIndex in row.tiles.indices where row.tiles[tileIndex].visibleTime == nil {
                rows[rowIndex].tiles[tileIndex].visibleTime = elapsedTime
            }
        }
    }

    // MARK: - Rules

    private struct TileLocation {
        let rowIndex: Int
        let tileIndex: Int
    }

    private func activeTile(at point: CGPoint) -> TileLocation? {
        guard let lane = geometry.lane(forX: point.x),
              let rowIndex = rows.firstIndex(where: { point.y >= $0.top && point.y < $0.bottom(rowHeight: geometry.rowHeight) }),
              let tileIndex = rows[rowIndex].tiles.firstIndex(where: { $0.lane == lane && $0.state == .active })
        else { return nil }
        return TileLocation(rowIndex: rowIndex, tileIndex: tileIndex)
    }

    private func registerHit(rowIndex: Int, tileIndex: Int) {
        var tile = rows[rowIndex].tiles[tileIndex]
        let bottom = rows[rowIndex].bottom(rowHeight: geometry.rowHeight)
        tile.state = .hit
        tile.hitTime = elapsedTime
        if tile.visibleTime == nil {
            tile.visibleTime = elapsedTime
        }
        tile.tapDepth = max(0, (bottom - geometry.playfieldTop) / geometry.reactionDistance)
        rows[rowIndex].tiles[tileIndex] = tile

        score += config.pointsPerTile
        lastReactionTime = tile.reactionTime
        tracker.recordHit(tile)
        emit(.tileHit(tile))
        emit(.scoreChanged(score))

        if case .targetScore(let target) = config.endCondition, score >= target {
            end(reason: .targetReached)
        }
    }

    private func registerWrongTap(at point: CGPoint) -> PianoTapOutcome {
        tracker.recordWrongTap()
        emit(.wrongTap(point))
        if mistakesEndGame {
            end(reason: .wrongTap)
        }
        return .wrongTap
    }

    /// Marks active tiles that crossed the miss line. Isolated so the failure rule can change.
    func evaluateMissedTiles() {
        for rowIndex in rows.indices {
            let row = rows[rowIndex]
            let edge: CGFloat = switch config.missRule {
            case .bottomEdgeCrossesMissLine: row.bottom(rowHeight: geometry.rowHeight)
            case .topEdgeCrossesMissLine: row.top
            }
            guard edge >= geometry.missLineY else { continue }
            for tileIndex in row.tiles.indices where row.tiles[tileIndex].state == .active {
                rows[rowIndex].tiles[tileIndex].state = .missed
                let tile = rows[rowIndex].tiles[tileIndex]
                tracker.recordMiss(tile)
                emit(.tileMissed(tile))
                if mistakesEndGame {
                    end(reason: .missedTile)
                    return
                }
            }
        }
    }

    private func evaluateTimer() {
        if case .timer(let duration) = config.endCondition, elapsedTime >= duration {
            end(reason: .timerExpired)
        }
    }

    private func end(reason: PianoGameOverReason) {
        guard !state.isGameOver else { return }
        setState(.gameOver(reason))
        emit(.gameEnded(reason))
    }

    private func setState(_ newState: PianoGameState) {
        guard newState != state else { return }
        state = newState
        emit(.stateChanged(newState))
    }

    private func emit(_ event: PianoGameEvent) {
        pendingEvents.append(event)
    }
}
