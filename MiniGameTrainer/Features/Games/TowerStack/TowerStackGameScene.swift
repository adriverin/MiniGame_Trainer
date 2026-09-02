import SpriteKit
import UIKit

@MainActor
protocol TowerStackGameSceneDelegate: AnyObject {
    func towerStackSceneDidPlace(_ scene: TowerStackGameScene, placement: TowerStackPlacement)
    func towerStackSceneDidFail(_ scene: TowerStackGameScene)
    func towerStackScene(_ scene: TowerStackGameScene, didEndWith summary: TowerStackSessionSummary)
}

/// Renders `TowerStackGameLogic` with a pinhole pseudo-3D projection. All gameplay decisions are
/// made by the logic; this class only handles input timing, node bookkeeping and decoration.
final class TowerStackGameScene: SKScene {
    let logic: TowerStackGameLogic
    let config: TowerStackGameConfig
    let projection: TowerStackProjection
    weak var gameDelegate: TowerStackGameSceneDelegate?

    var debugOptions: TowerStackDebugOptions {
        didSet { applyDebugOptions() }
    }

    private let worldLayer = SKNode()
    private let debrisLayer = SKNode()
    private let hudLayer = SKNode()
    private let debugLayer = SKNode()
    private let pedestalNode = TowerStackBlockNode()
    private let movingNode = TowerStackBlockNode()
    private var blockNodes: [Int: TowerStackBlockNode] = [:]
    private var debrisPool: [TowerStackBlockNode] = []
    private let scoreLabel = SKLabelNode()
    private let scoreShadow = SKLabelNode()
    private let hintScrim = SKSpriteNode()
    private let hintLabel = SKLabelNode()
    private let debugLabel = SKLabelNode()
    private let incomingOutline = SKShapeNode()
    private let targetOutline = SKShapeNode()
    private let intersectionShape = SKShapeNode()
    private let axesShape = SKShapeNode()

    private var lastUpdateTime: TimeInterval = 0
    private var needsTimeReset = true
    private var smoothedFPS: Double = 0
    private var debugAccumulator: TimeInterval = 0
    private var renderedCamera: TowerStackWorldPoint?
    private var needsFullRender = true
    private var activeTouch: UITouch?
    private var hasReportedEnd = false

    init(size: CGSize, config: TowerStackGameConfig, debugOptions: TowerStackDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = TowerStackGameLogic(config: config)
        projection = TowerStackProjection(sceneSize: size, config: config)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = TowerStackPalette.backgroundStops[0].color
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        if children.isEmpty {
            buildScene()
            startSession()
        }
    }

    // MARK: Session

    func startSession() {
        isPaused = false
        removeAllActions()
        hasReportedEnd = false
        needsTimeReset = true
        activeTouch = nil
        recycleNodes()
        logic.reset()
        _ = logic.drainEvents()
        if debugOptions.skipHint || debugOptions.autoPlaceOffsetFraction != nil {
            logic.startPlaying()
            _ = logic.drainEvents()
        }
        updateScore(0)
        setHintVisible(logic.state == .ready)
        movingNode.alpha = 1
        needsFullRender = true
        syncNodes()
    }

    func pauseGame() {
        logic.pause()
        isPaused = true
    }

    func resumeGame() {
        needsTimeReset = true
        isPaused = false
        logic.resume()
        handle(logic.drainEvents())
    }

    // MARK: Scene graph

    private func buildScene() {
        let background = SKSpriteNode(texture: makeGradientTexture(), size: size)
        background.anchorPoint = .zero
        background.zPosition = -100
        addChild(background)

        worldLayer.zPosition = 10
        addChild(worldLayer)
        // Debris shares the world layer so pieces can sort behind or in front of the tower.
        debrisLayer.zPosition = 0
        worldLayer.addChild(debrisLayer)
        debugLayer.zPosition = 50
        addChild(debugLayer)
        hudLayer.zPosition = 100
        addChild(hudLayer)

        pedestalNode.zPosition = 0
        worldLayer.addChild(pedestalNode)
        movingNode.zPosition = 10_000
        worldLayer.addChild(movingNode)

        for label in [scoreShadow, scoreLabel] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            hudLayer.addChild(label)
        }
        let scoreY = size.height * (1 - config.scoreYRatio)
        scoreShadow.position = CGPoint(x: size.width / 2 + 2, y: scoreY - 3)
        scoreLabel.position = CGPoint(x: size.width / 2, y: scoreY)
        scoreLabel.zPosition = 1

        hintScrim.color = UIColor(white: 0, alpha: 0.42)
        hintScrim.size = size
        hintScrim.anchorPoint = .zero
        hintScrim.zPosition = 40
        addChild(hintScrim)
        hintLabel.attributedText = attributed("Tap to place the block", size: size.height * 0.03, weight: .bold, color: AppTheme.UIColors.hintText)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
        hintLabel.zPosition = 41
        addChild(hintLabel)

        debugLabel.fontName = "Menlo-Bold"
        debugLabel.fontSize = 10
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.position = CGPoint(x: 10, y: size.height - 58)
        hudLayer.addChild(debugLabel)

        incomingOutline.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.95)
        targetOutline.strokeColor = UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 0.95)
        intersectionShape.strokeColor = UIColor(red: 0.3, green: 1, blue: 0.4, alpha: 0.95)
        intersectionShape.fillColor = UIColor(red: 0.3, green: 1, blue: 0.4, alpha: 0.25)
        axesShape.strokeColor = UIColor(white: 1, alpha: 0.5)
        for shape in [incomingOutline, targetOutline, intersectionShape, axesShape] {
            shape.lineWidth = 1.5
            shape.isAntialiased = true
            debugLayer.addChild(shape)
        }
        applyDebugOptions()
    }

    private func makeGradientTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 512))
        let image = renderer.image { context in
            let stops = TowerStackPalette.backgroundStops
            let colors = stops.map(\.color.cgColor) as CFArray
            let locations = stops.map(\.location)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 512), options: [])
        }
        return SKTexture(image: image)
    }

    private func recycleNodes() {
        for node in blockNodes.values { node.removeFromParent() }
        blockNodes.removeAll(keepingCapacity: true)
        debrisLayer.removeAllChildren()
        debrisPool.removeAll(keepingCapacity: true)
        movingNode.removeAllActions()
        movingNode.isHidden = false
        pedestalNode.isHidden = false
        renderedCamera = nil
    }

    // MARK: Frame update

    override func update(_ currentTime: TimeInterval) {
        var delta: TimeInterval
        if needsTimeReset {
            delta = 0
            needsTimeReset = false
        } else {
            delta = min(max(0, currentTime - lastUpdateTime), config.maximumDeltaTime)
        }
        lastUpdateTime = currentTime
        if delta > 0 {
            let instant = 1 / delta
            smoothedFPS = smoothedFPS == 0 ? instant : smoothedFPS * 0.9 + instant * 0.1
        }
        delta = runAutoPlaceIfNeeded(within: delta)
        logic.update(deltaTime: delta)
        handle(logic.drainEvents())
        syncNodes()
        if debugOptions.showPerformanceOverlay {
            debugAccumulator += delta
            if debugAccumulator >= 0.2 {
                debugAccumulator = 0
                refreshDebugOverlay()
            }
        }
    }

    /// Deterministic DEBUG placements: advances analytically to the exact instant the block centre
    /// reaches the desired offset and places there. Returns the remaining frame time.
    private func runAutoPlaceIfNeeded(within delta: TimeInterval) -> TimeInterval {
        guard let fraction = debugOptions.autoPlaceOffsetFraction,
              logic.state == .ready || logic.state == .playing,
              let block = logic.movingBlock else { return delta }
        if logic.state == .ready {
            logic.startPlaying()
            setHintVisible(false)
        }
        let center = logic.towerTop.center(along: block.axis)
        let dimension = logic.towerTop.dimension(along: block.axis)
        let shouldMiss = debugOptions.autoMissAtScore.map { logic.score >= $0 } ?? false
        let desired: CGFloat
        if shouldMiss {
            let farSign = logic.cameraRig.farSign(along: block.axis)
            desired = center + farSign * min(config.movementRange, dimension + 0.05)
        } else {
            desired = center + fraction * dimension
        }
        guard let time = block.timeToReach(desired), time <= delta else { return delta }
        let placement = logic.placeBlock(advancingBy: time)
        handle(logic.drainEvents())
        if let placement { report(placement) }
        return delta - time
    }

    private func handle(_ events: [TowerStackGameEvent]) {
        for event in events {
            switch event {
            case .stateChanged(let state):
                setHintVisible(state == .ready)
            case .scoreChanged(let score):
                updateScore(score)
                scheduleDebugCapturePause(after: score)
            case .blockPlaced(let block):
                addPlacedBlock(block)
            case .pieceCut(let piece):
                spawnDebris(for: piece)
            case .blockSpawned:
                movingNode.removeAllActions()
                movingNode.alpha = 0
                movingNode.run(.fadeIn(withDuration: config.spawnFadeDuration))
            case .gameEnded(let reason):
                handleGameOver(reason)
            }
        }
    }

    private func addPlacedBlock(_ block: TowerStackBlock) {
        let node = TowerStackBlockNode()
        node.zPosition = CGFloat(1 + block.layer)
        worldLayer.addChild(node)
        blockNodes[block.layer] = node
        needsFullRender = true
        renderPlacedBlock(block, node: node, camera: logic.cameraPosition)
        node.playLanding(duration: config.squashDuration)

        let lowestVisible = block.layer - config.visibleLayersBelowTop
        for (layer, old) in blockNodes where layer < lowestVisible {
            old.removeFromParent()
            blockNodes[layer] = nil
        }
        pedestalNode.isHidden = lowestVisible > 0
    }

    private func handleGameOver(_ reason: TowerStackGameOverReason) {
        guard !hasReportedEnd else { return }
        hasReportedEnd = true
        movingNode.removeAllActions()
        movingNode.isHidden = true
        if reason == .missedTower { gameDelegate?.towerStackSceneDidFail(self) }
        let summary = logic.makeSummary(reason: reason)
        let hold = reason == .aborted ? 0 : config.gameOverHoldDuration
        run(.sequence([
            .wait(forDuration: hold),
            .run { [weak self] in
                guard let self else { return }
                self.gameDelegate?.towerStackScene(self, didEndWith: summary)
            },
        ]), withKey: "gameOver")
    }

    private func scheduleDebugCapturePause(after score: Int) {
        guard let captureScore = debugOptions.pauseAtScore,
              score >= captureScore,
              action(forKey: "debugCapturePause") == nil else { return }
        run(.sequence([
            .wait(forDuration: 0.3),
            .run { [weak self] in self?.isPaused = true },
        ]), withKey: "debugCapturePause")
    }

    // MARK: Rendering

    private func syncNodes() {
        let camera = logic.cameraPosition
        if needsFullRender || renderedCamera != camera {
            renderedCamera = camera
            needsFullRender = false
            if !pedestalNode.isHidden {
                let pedestal = projection.projectBlock(
                    config.initialFootprint, bottomY: -config.pedestalHeight, topY: 0, camera: camera
                )
                pedestalNode.render(pedestal, colors: TowerStackPalette.pedestal)
            }
            for block in logic.placedBlocks.suffix(config.visibleLayersBelowTop + 1) {
                if let node = blockNodes[block.layer] {
                    renderPlacedBlock(block, node: node, camera: camera)
                }
            }
        }

        if let block = logic.movingBlock, logic.state != .gameOver {
            movingNode.isHidden = false
            let bottom = CGFloat(block.layer) * config.blockHeight
            let projected = projection.projectBlock(block.footprint, bottomY: bottom, topY: bottom + config.blockHeight, camera: camera)
            movingNode.render(projected, colors: TowerStackPalette.colors(forBlockIndex: block.layer, config: config))
        } else {
            movingNode.isHidden = true
        }
        updateDebugGeometry(camera: camera)
    }

    private func renderPlacedBlock(_ block: TowerStackBlock, node: TowerStackBlockNode, camera: TowerStackWorldPoint) {
        let bottom = CGFloat(block.layer) * config.blockHeight
        let projected = projection.projectBlock(block.footprint, bottomY: bottom, topY: bottom + config.blockHeight, camera: camera)
        node.render(projected, colors: TowerStackPalette.colors(forBlockIndex: block.colorIndex, config: config))
    }

    private func spawnDebris(for piece: TowerStackCutPiece) {
        guard config.debrisEnabled, piece.footprint.isNumericallyValid else { return }
        let active = debrisLayer.children.count
        guard active < config.maximumDebrisNodes else { return }

        let node = debrisPool.popLast() ?? TowerStackBlockNode()
        node.removeAllActions()
        node.alpha = 1
        node.zRotation = 0
        node.setScale(1)
        let camera = logic.cameraPosition
        let bottom = CGFloat(piece.layer) * config.blockHeight
        let projected = projection.projectBlock(piece.footprint, bottomY: bottom, topY: bottom + config.blockHeight, camera: camera)
        node.render(projected, colors: TowerStackPalette.colors(forBlockIndex: piece.colorIndex, config: config))
        // Pieces hanging over the far side fall behind the tower, near-side pieces in front of it.
        node.zPosition = piece.side == logic.cameraRig.farSign(along: piece.axis) ? 0.5 : 9_000
        if node.parent == nil { debrisLayer.addChild(node) }

        // Screen-space fall: gravity in world units converted through the target-depth scale, plus a
        // slight drift away from the tower along the cut axis.
        let gravity = config.debrisGravity * projection.unitScale
        let centerWorld = TowerStackWorldPoint(x: piece.footprint.centerX, y: bottom, z: piece.footprint.centerZ)
        let offsetWorld = piece.axis == .x
            ? TowerStackWorldPoint(x: piece.side, y: 0, z: 0)
            : TowerStackWorldPoint(x: 0, y: 0, z: piece.side)
        let origin = projection.project(centerWorld, camera: camera)
        let shifted = projection.project(centerWorld + offsetWorld, camera: camera)
        let driftX = (shifted.x - origin.x) * 0.35
        let rotation = config.debrisRotationDegreesPerSecond * .pi / 180 * piece.side * (piece.axis == .x ? -1 : 1)
        let startPosition = node.position
        let lifetime = config.debrisLifetime
        let fall = SKAction.customAction(withDuration: lifetime) { node, elapsed in
            let t = CGFloat(elapsed)
            node.position = CGPoint(
                x: startPosition.x + driftX * t,
                y: startPosition.y - 0.5 * gravity * t * t
            )
            node.zRotation = rotation * t
            node.alpha = max(0, 1 - CGFloat(elapsed / lifetime) * CGFloat(elapsed / lifetime))
        }
        node.run(.sequence([
            fall,
            .run { [weak self, weak node] in
                guard let self, let node else { return }
                node.removeFromParent()
                self.debrisPool.append(node)
            },
        ]))
    }

    private func setHintVisible(_ visible: Bool) {
        hintScrim.isHidden = !visible
        hintLabel.isHidden = !visible
    }

    private func updateScore(_ score: Int) {
        let fontSize = config.scoreFontSizeRatio * size.height
        scoreLabel.attributedText = attributed("\(score)", size: fontSize, weight: .heavy, color: AppTheme.UIColors.scoreText)
        scoreShadow.attributedText = attributed("\(score)", size: fontSize, weight: .heavy, color: UIColor(white: 0, alpha: 0.4))
    }

    private func attributed(_ text: String, size fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> NSAttributedString {
        let base = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: fontSize) } ?? base
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }

    // MARK: Debug

    private func applyDebugOptions() {
        debugLabel.isHidden = !debugOptions.showPerformanceOverlay
        debugLayer.isHidden = !debugOptions.showGeometry
    }

    private func updateDebugGeometry(camera: TowerStackWorldPoint) {
        guard debugOptions.showGeometry else { return }
        let surface = logic.towerTopHeight
        targetOutline.path = closedPath(projection.projectFootprintOutline(logic.towerTop, y: surface, camera: camera))
        if let block = logic.movingBlock {
            incomingOutline.path = closedPath(projection.projectFootprintOutline(block.footprint, y: surface, camera: camera))
            let overlap = block.footprint.interval(along: block.axis).intersection(logic.towerTop.interval(along: block.axis))
            if overlap.length > 0 {
                let footprint = logic.towerTop.replacing(overlap, along: block.axis)
                intersectionShape.path = closedPath(projection.projectFootprintOutline(footprint, y: surface, camera: camera))
                intersectionShape.isHidden = false
            } else {
                intersectionShape.isHidden = true
            }
        } else {
            incomingOutline.path = nil
            intersectionShape.isHidden = true
        }

        let center = TowerStackWorldPoint(x: logic.towerTop.centerX, y: surface, z: logic.towerTop.centerZ)
        let axes = CGMutablePath()
        for (dx, dz) in [(CGFloat(1), CGFloat(0)), (0, 1)] {
            let from = projection.project(center - TowerStackWorldPoint(x: dx, y: 0, z: dz) * config.movementRange, camera: camera)
            let to = projection.project(center + TowerStackWorldPoint(x: dx, y: 0, z: dz) * config.movementRange, camera: camera)
            axes.move(to: from)
            axes.addLine(to: to)
        }
        axesShape.path = axes
    }

    private func closedPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func refreshDebugOverlay() {
        let block = logic.movingBlock
        let axis = block?.axis ?? logic.config.firstAxis
        let targetCenter = logic.towerTop.center(along: axis)
        let position = block?.position ?? targetCenter
        let overlap = block.map {
            $0.footprint.interval(along: axis).intersection(logic.towerTop.interval(along: axis)).length
        } ?? 0
        debugLabel.text = String(
            format: "FPS %.0f  score %d  t %.1f s\naxis %@  dir %+.0f  speed %.2f w/s\nmoving %.3f  target %.3f  offset %+.3f\noverlap %.3f  width %.3f (%.0f%%)  depth %.3f (%.0f%%)\ntower h %.2f  cam y %.2f  nodes %d  debris %d",
            smoothedFPS,
            logic.score,
            logic.elapsedTime,
            axis.displayName,
            block?.direction ?? 0,
            logic.currentSpeed,
            position,
            targetCenter,
            position - targetCenter,
            max(0, overlap),
            logic.towerTop.width,
            logic.widthRatio * 100,
            logic.towerTop.depth,
            logic.depthRatio * 100,
            logic.towerTopHeight,
            logic.cameraPosition.y,
            blockNodes.count,
            debrisLayer.children.count
        )
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        guard logic.state == .ready || logic.state == .playing else { return }
        // Advance the simulation to the touch timestamp so the overlap uses the block's position
        // at the moment of the tap rather than at the last rendered frame.
        let extra = needsTimeReset ? 0 : max(0, min(touch.timestamp - lastUpdateTime, config.maximumDeltaTime))
        let placement = logic.placeBlock(advancingBy: extra)
        lastUpdateTime += extra
        handle(logic.drainEvents())
        if let placement { report(placement) }
        syncNodes()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func report(_ placement: TowerStackPlacement) {
        gameDelegate?.towerStackSceneDidPlace(self, placement: placement)
    }
}
