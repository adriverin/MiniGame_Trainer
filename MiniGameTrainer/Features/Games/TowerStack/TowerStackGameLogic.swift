import CoreGraphics
import Foundation

/// Framework-free Tower Stack simulation. Owns the logical tower footprint, the sliding block, the
/// camera target and all scoring; SpriteKit only renders this state.
final class TowerStackGameLogic {
    let config: TowerStackGameConfig
    let difficulty: TowerStackDifficultyModel
    let cameraRig: TowerStackCameraRig

    private(set) var state: TowerStackGameState = .ready
    private(set) var score = 0
    /// Active play time (excludes the ready hint and pauses).
    private(set) var elapsedTime: TimeInterval = 0
    /// Footprint of the current tower top (the pedestal until the first placement).
    private(set) var towerTop: TowerStackFootprint
    /// Every block resting on the tower, oldest first. Lightweight value history only.
    private(set) var placedBlocks: [TowerStackBlock] = []
    private(set) var movingBlock: TowerStackMovingBlock?
    /// Point the camera frames right now (eases toward `cameraTarget`).
    private(set) var cameraPosition: TowerStackWorldPoint = .zero
    private(set) var cameraTarget: TowerStackWorldPoint = .zero
    private(set) var lastPlacement: TowerStackPlacement?

    private var cameraAnimationStart: TowerStackWorldPoint = .zero
    private var cameraAnimationElapsed: TimeInterval = 0
    private var cameraAnimationDuration: TimeInterval = 0
    private var nextAxis: TowerStackAxis
    private var tracker = TowerStackPerformanceTracker()
    private var pendingEvents: [TowerStackGameEvent] = []
    private var stateBeforePause: TowerStackGameState?

    init(config: TowerStackGameConfig) {
        self.config = config
        difficulty = TowerStackDifficultyModel(config: config)
        cameraRig = TowerStackCameraRig(config: config)
        towerTop = config.initialFootprint
        nextAxis = config.firstAxis
        reset()
    }

    // MARK: Derived state

    /// World Y of the surface the next block will rest on.
    var towerTopHeight: CGFloat { CGFloat(placedBlocks.count) * config.blockHeight }
    var topLayer: Int { placedBlocks.count - 1 }
    var currentSpeed: CGFloat { movingBlock?.speed ?? difficulty.speed(forScore: score) }
    var widthRatio: CGFloat { towerTop.width / config.initialWidth }
    var depthRatio: CGFloat { towerTop.depth / config.initialDepth }

    // MARK: Session control

    func reset() {
        score = 0
        elapsedTime = 0
        towerTop = config.initialFootprint
        placedBlocks.removeAll(keepingCapacity: true)
        nextAxis = config.firstAxis
        lastPlacement = nil
        tracker.reset()
        pendingEvents.removeAll(keepingCapacity: true)
        stateBeforePause = nil
        cameraPosition = TowerStackWorldPoint(x: towerTop.centerX, y: 0, z: towerTop.centerZ)
        cameraTarget = cameraPosition
        cameraAnimationStart = cameraPosition
        cameraAnimationDuration = 0
        cameraAnimationElapsed = 0
        movingBlock = nil
        spawnBlock()
        setState(.ready)
    }

    /// Dismisses the hint; the block is already sliding. Mirrors the reference's first tap.
    func startPlaying() {
        guard state == .ready else { return }
        setState(.playing)
    }

    func pause() {
        switch state {
        case .ready, .playing:
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
        guard state != .gameOver else { return }
        endGame(.aborted)
    }

    // MARK: Simulation

    func update(deltaTime: TimeInterval) {
        guard state == .ready || state == .playing else { return }
        let delta = min(max(0, deltaTime), config.maximumDeltaTime)
        guard delta > 0 else { return }
        movingBlock?.advance(by: delta)
        if state == .playing {
            elapsedTime += delta
        }
        advanceCamera(by: delta)
    }

    /// Evaluates the tap. `extraTime` is the interval between the last simulated frame and the touch
    /// timestamp; the block is advanced analytically by it before the overlap is computed so the
    /// placement never uses a stale position.
    /// - Returns: the recorded placement, or `nil` when the tap was ignored (hint dismissal, wrong state).
    @discardableResult
    func placeBlock(advancingBy extraTime: TimeInterval = 0) -> TowerStackPlacement? {
        switch state {
        case .ready:
            startPlaying()
            if extraTime > 0 { update(deltaTime: extraTime) }
            return nil
        case .playing:
            if extraTime > 0 { update(deltaTime: extraTime) }
            return evaluatePlacement()
        case .paused, .gameOver:
            return nil
        }
    }

    /// Deterministic placement at a known offset from the tower centre (test mode / long-run tests).
    @discardableResult
    func placeBlock(atOffset offset: CGFloat) -> TowerStackPlacement? {
        guard state == .ready || state == .playing, var block = movingBlock else { return nil }
        if state == .ready { startPlaying() }
        block.position = towerTop.center(along: block.axis) + offset
        movingBlock = block
        return evaluatePlacement()
    }

    func drainEvents() -> [TowerStackGameEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    func makeSummary(reason: TowerStackGameOverReason = .missedTower) -> TowerStackSessionSummary {
        TowerStackSessionSummary(
            score: score,
            duration: elapsedTime,
            reason: reason,
            placements: tracker.successfulPlacements,
            averageOverlapRatio: tracker.averageOverlapRatio,
            bestOverlapRatio: tracker.bestOverlapRatio,
            worstOverlapRatio: tracker.worstOverlapRatio,
            averageNormalizedOffset: tracker.averageNormalizedOffset,
            nearPerfectPlacements: tracker.nearPerfectPlacements,
            finalWidthRatio: Double(widthRatio),
            finalDepthRatio: Double(depthRatio),
            highestSpeed: tracker.highestSpeed
        )
    }

    // MARK: Internals

    private func evaluatePlacement() -> TowerStackPlacement? {
        guard state == .playing, let block = movingBlock else { return nil }
        let resolution = TowerStackPlacementResolver.resolve(
            incoming: block.footprint,
            target: towerTop,
            axis: block.axis,
            overlapTolerance: config.overlapTolerance,
            minimumViableDimension: config.minimumViableDimension
        )
        let placement = TowerStackPlacement(
            score: score,
            axis: block.axis,
            incomingCenter: block.position,
            targetCenter: towerTop.center(along: block.axis),
            offset: resolution.offset,
            normalizedOffset: resolution.normalizedOffset,
            overlapRatio: resolution.overlapRatio,
            resultingWidth: resolution.surviving?.width ?? towerTop.width,
            resultingDepth: resolution.surviving?.depth ?? towerTop.depth,
            movementSpeed: block.speed,
            direction: block.direction,
            isMiss: resolution.isMiss
        )
        lastPlacement = placement
        tracker.record(placement, perfectTolerance: config.perfectPlacementTolerance)

        guard let surviving = resolution.surviving, surviving.isNumericallyValid else {
            let side: CGFloat = resolution.offset >= 0 ? 1 : -1
            pendingEvents.append(.pieceCut(TowerStackCutPiece(
                footprint: block.footprint, layer: block.layer, colorIndex: block.layer, axis: block.axis, side: side
            )))
            movingBlock = nil
            endGame(.missedTower)
            return placement
        }

        for piece in resolution.cutPieces {
            let side: CGFloat = piece.center(along: block.axis) >= surviving.center(along: block.axis) ? 1 : -1
            pendingEvents.append(.pieceCut(TowerStackCutPiece(
                footprint: piece, layer: block.layer, colorIndex: block.layer, axis: block.axis, side: side
            )))
        }

        let placed = TowerStackBlock(layer: block.layer, footprint: surviving)
        placedBlocks.append(placed)
        towerTop = surviving
        score += config.pointsPerPlacement
        pendingEvents.append(.blockPlaced(placed))
        pendingEvents.append(.scoreChanged(score))
        retargetCamera()
        spawnBlock()
        return placement
    }

    private func spawnBlock() {
        let axis = nextAxis
        nextAxis = axis.next
        let center = towerTop.center(along: axis)
        let farSign = cameraRig.farSign(along: axis)
        let spawnSign = config.spawnFromFarEnd ? farSign : -farSign
        movingBlock = TowerStackMovingBlock(
            axis: axis,
            position: center + spawnSign * config.movementRange,
            direction: -spawnSign,
            speed: difficulty.speed(forScore: score),
            minimum: center - config.movementRange,
            maximum: center + config.movementRange,
            footprint: towerTop,
            layer: placedBlocks.count
        )
        pendingEvents.append(.blockSpawned)
    }

    private func retargetCamera() {
        cameraAnimationStart = cameraPosition
        cameraTarget = TowerStackWorldPoint(x: towerTop.centerX, y: towerTopHeight, z: towerTop.centerZ)
        cameraAnimationDuration = difficulty.cameraStepDuration(forScore: score)
        cameraAnimationElapsed = 0
    }

    private func advanceCamera(by delta: TimeInterval) {
        guard cameraPosition != cameraTarget else { return }
        cameraAnimationElapsed += delta
        guard cameraAnimationDuration > 0, cameraAnimationElapsed < cameraAnimationDuration else {
            cameraPosition = cameraTarget
            return
        }
        let t = CGFloat(cameraAnimationElapsed / cameraAnimationDuration)
        let eased = t * t * (3 - 2 * t)
        cameraPosition = cameraAnimationStart.interpolated(to: cameraTarget, progress: eased)
    }

    private func endGame(_ reason: TowerStackGameOverReason) {
        setState(.gameOver)
        pendingEvents.append(.gameEnded(reason))
    }

    private func setState(_ newState: TowerStackGameState) {
        guard state != newState else { return }
        state = newState
        pendingEvents.append(.stateChanged(newState))
    }
}
