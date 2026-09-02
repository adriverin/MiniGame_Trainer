import SpriteKit
import UIKit

@MainActor
protocol PianoGameSceneDelegate: AnyObject {
    func pianoSceneDidRegisterHit(_ scene: PianoGameScene)
    func pianoSceneDidFail(_ scene: PianoGameScene)
    func pianoSceneCountdownDidTick(_ scene: PianoGameScene)
    func pianoScene(_ scene: PianoGameScene, didEndWith summary: PianoSessionSummary)
}

/// Renders `PianoGameLogic` and forwards touches to it. Contains no rules of its own.
final class PianoGameScene: SKScene {
    let logic: PianoGameLogic
    let config: PianoGameConfig
    weak var gameDelegate: PianoGameSceneDelegate?

    var debugOptions: PianoDebugOptions {
        didSet { applyDebugOptions() }
    }

    private var geometry: PianoGeometry { logic.geometry }

    // Layers
    private let playfieldCrop = SKCropNode()
    private let tileLayer = SKNode()
    private let hitboxLayer = SKNode()
    private let hudLayer = SKNode()

    // HUD
    private let scoreLabel = SKLabelNode()
    private let scoreShadowLabel = SKLabelNode()
    private let countdownLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()
    private let hintDot: SKShapeNode
    private let flashOverlay: SKSpriteNode
    private let debugLabel = SKLabelNode()
    private var missLineNode: SKShapeNode?

    // Node bookkeeping
    private var tileNodes: [UUID: PianoTileNode] = [:]
    private var nodePool: [PianoTileNode] = []
    private var hitboxNodes: [UUID: SKShapeNode] = [:]
    private var frameCounter: UInt64 = 0
    private var nodeLastSeenFrame: [UUID: UInt64] = [:]

    // Timing
    private var lastUpdateTime: TimeInterval = 0
    private var needsTimeReset = true
    private var smoothedFPS: Double = 0
    private var debugRefreshAccumulator: TimeInterval = 0
    private var hasReportedEnd = false
    private var safeAreaTop: CGFloat = 0

    init(size: CGSize, config: PianoGameConfig, debugOptions: PianoDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = PianoGameLogic(config: config, sceneSize: size)
        hintDot = SKShapeNode(circleOfRadius: max(6, size.height * 0.014))
        flashOverlay = SKSpriteNode(color: AppTheme.UIColors.failureFlash, size: size)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = AppTheme.UIColors.gameBackground
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not supported")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        safeAreaTop = view.safeAreaInsets.top
        if children.isEmpty {
            buildNodes()
            startSession()
        }
    }

    /// Fresh session: resets the simulation, re-syncs nodes and runs the countdown.
    func startSession() {
        hasReportedEnd = false
        needsTimeReset = true
        removeAllActions()
        countdownLabel.removeAllActions()
        countdownLabel.isHidden = true
        flashOverlay.alpha = 0
        hideHint()
        logic.reset()
        _ = logic.drainEvents()
        recycleAllTileNodes()
        syncTileNodes()
        updateScoreLabel(0)

        if debugOptions.skipCountdown {
            logic.finishCountdown()
            handleEvents(logic.drainEvents())
        } else {
            runCountdown()
        }
    }

    func pauseGame() {
        logic.pause()
        isPaused = true
    }

    func resumeGame() {
        needsTimeReset = true
        isPaused = false
        logic.resume()
        handleEvents(logic.drainEvents())
    }

    // MARK: - Node setup

    private func buildNodes() {
        // Everything below the playfield top is visible; tiles above it are clipped.
        let visibleHeight = size.height - geometry.playfieldTop
        let mask = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: visibleHeight))
        mask.anchorPoint = .zero
        mask.position = .zero
        playfieldCrop.maskNode = mask
        playfieldCrop.zPosition = 10
        playfieldCrop.addChild(tileLayer)
        playfieldCrop.addChild(hitboxLayer)
        hitboxLayer.zPosition = 20
        addChild(playfieldCrop)

        hudLayer.zPosition = 100
        addChild(hudLayer)

        let scoreY = size.height - config.scoreCenterYRatio * size.height
        for label in [scoreShadowLabel, scoreLabel] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            hudLayer.addChild(label)
        }
        scoreShadowLabel.position = CGPoint(x: size.width / 2 + 2, y: scoreY - 3)
        scoreShadowLabel.zPosition = 0
        scoreLabel.position = CGPoint(x: size.width / 2, y: scoreY)
        scoreLabel.zPosition = 1

        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        countdownLabel.zPosition = 5
        countdownLabel.isHidden = true
        hudLayer.addChild(countdownLabel)

        hintLabel.attributedText = attributed("Tap the tiles", size: size.height * 0.026, color: AppTheme.UIColors.hintText)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        hintLabel.zPosition = 5
        hintLabel.isHidden = true
        hudLayer.addChild(hintLabel)

        hintDot.fillColor = .white
        hintDot.strokeColor = .clear
        hintDot.zPosition = 6
        hintDot.isHidden = true
        hudLayer.addChild(hintDot)

        flashOverlay.anchorPoint = .zero
        flashOverlay.position = .zero
        flashOverlay.zPosition = 200
        flashOverlay.alpha = 0
        addChild(flashOverlay)

        debugLabel.fontName = "Menlo-Bold"
        debugLabel.fontSize = 11
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.position = CGPoint(x: 10, y: size.height - safeAreaTop - 6)
        debugLabel.zPosition = 300
        debugLabel.isHidden = true
        addChild(debugLabel)

        applyDebugOptions()
    }

    private func attributed(_ text: String, size fontSize: CGFloat, color: UIColor, weight: UIFont.Weight = .heavy) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
        ])
    }

    private func updateScoreLabel(_ score: Int) {
        let fontSize = config.scoreFontSizeRatio * size.height
        scoreLabel.attributedText = attributed("\(score)", size: fontSize, color: AppTheme.UIColors.scoreText)
        scoreShadowLabel.attributedText = attributed("\(score)", size: fontSize, color: AppTheme.UIColors.scoreShadow)
    }

    // MARK: - Countdown / ready hint

    private func runCountdown() {
        logic.beginCountdown()
        handleEvents(logic.drainEvents())

        let fontSize = size.height * 0.16
        var steps: [SKAction] = []
        for value in stride(from: config.countdownSteps, through: 1, by: -1) {
            steps.append(countdownStep(text: "\(value)", fontSize: fontSize, duration: config.countdownStepDuration))
        }
        steps.append(countdownStep(text: "GO", fontSize: fontSize * 0.7, duration: config.countdownStepDuration / 2))
        steps.append(SKAction.run { [weak self] in
            guard let self else { return }
            self.countdownLabel.isHidden = true
            self.logic.finishCountdown()
            self.handleEvents(self.logic.drainEvents())
        })
        countdownLabel.isHidden = false
        countdownLabel.run(SKAction.sequence(steps), withKey: "countdown")
    }

    private func countdownStep(text: String, fontSize: CGFloat, duration: TimeInterval) -> SKAction {
        let show = SKAction.run { [weak self] in
            guard let self else { return }
            self.countdownLabel.attributedText = self.attributed(text, size: fontSize, color: .white)
            self.countdownLabel.setScale(1.25)
            self.countdownLabel.alpha = 1
            self.gameDelegate?.pianoSceneCountdownDidTick(self)
        }
        let pop = SKAction.scale(to: 1.0, duration: min(0.15, duration * 0.4))
        pop.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: max(0, duration - pop.duration))
        return SKAction.sequence([show, pop, hold])
    }

    private func showHint() {
        hintLabel.isHidden = false
        guard let row = logic.lowestActiveRow, let tile = row.tiles.first else { return }
        let frame = geometry.tileFrame(lane: tile.lane, rowTop: row.top)
        hintDot.position = geometry.toScene(CGPoint(x: frame.midX, y: frame.midY + frame.height * 0.2))
        hintDot.isHidden = false
        hintDot.alpha = 0.9
        let pulse = SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.35, duration: 0.45), SKAction.fadeAlpha(to: 0.35, duration: 0.45)]),
            SKAction.group([SKAction.scale(to: 1.0, duration: 0.45), SKAction.fadeAlpha(to: 0.9, duration: 0.45)]),
        ])
        hintDot.run(SKAction.repeatForever(pulse), withKey: "pulse")
    }

    private func hideHint() {
        hintLabel.isHidden = true
        hintDot.isHidden = true
        hintDot.removeAllActions()
        hintDot.setScale(1)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if needsTimeReset {
            delta = 0
            needsTimeReset = false
        } else {
            delta = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        frameCounter &+= 1

        if delta > 0 {
            let instantFPS = 1 / delta
            smoothedFPS = smoothedFPS == 0 ? instantFPS : smoothedFPS * 0.9 + instantFPS * 0.1
        }

        logic.update(deltaTime: delta)
        handleEvents(logic.drainEvents())
        syncTileNodes()

        if debugOptions.showPerformanceOverlay {
            debugRefreshAccumulator += delta
            if debugRefreshAccumulator >= 0.25 {
                debugRefreshAccumulator = 0
                refreshDebugOverlay()
            }
        }
    }

    private func handleEvents(_ events: [PianoGameEvent]) {
        for event in events {
            switch event {
            case .tileHit(let tile):
                tileNodes[tile.id]?.applyHit(config: config)
                gameDelegate?.pianoSceneDidRegisterHit(self)
            case .tileMissed(let tile):
                tileNodes[tile.id]?.applyMissed()
            case .scoreChanged(let score):
                updateScoreLabel(score)
            case .stateChanged(let state):
                switch state {
                case .waitingForStart: showHint()
                case .playing: hideHint()
                default: break
                }
            case .gameEnded(let reason):
                handleGameOver(reason: reason)
            case .tileSpawned, .wrongTap:
                break
            }
        }
    }

    private func handleGameOver(reason: PianoGameOverReason) {
        guard !hasReportedEnd else { return }
        hasReportedEnd = true
        hideHint()
        countdownLabel.removeAllActions()
        countdownLabel.isHidden = true

        if reason.isFailure {
            gameDelegate?.pianoSceneDidFail(self)
            flashOverlay.alpha = config.gameOverFlashPeakOpacity
            let fade = SKAction.fadeAlpha(to: 0, duration: config.gameOverFlashDuration)
            fade.timingMode = .easeOut
            flashOverlay.run(fade)
        }

        let summary = logic.makeSummary()
        let hold = reason == .aborted ? 0 : config.gameOverHoldDuration
        run(SKAction.sequence([
            SKAction.wait(forDuration: hold),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.gameDelegate?.pianoScene(self, didEndWith: summary)
            },
        ]), withKey: "gameOverReport")
    }

    // MARK: - Tile nodes

    private func syncTileNodes() {
        for row in logic.rows {
            for tile in row.tiles {
                let node = tileNodes[tile.id] ?? makeNode(for: tile)
                let frame = geometry.tileFrame(lane: tile.lane, rowTop: row.top)
                node.position = geometry.toScene(CGPoint(x: frame.midX, y: frame.midY))
                nodeLastSeenFrame[tile.id] = frameCounter

                switch tile.state {
                case .active: break
                case .hit: node.applyHit(config: config)
                case .missed: node.applyMissed()
                }

                if debugOptions.showHitboxes {
                    syncHitbox(for: tile, row: row)
                }
            }
        }

        // Recycle nodes whose tiles were removed by the simulation.
        for (id, node) in tileNodes where nodeLastSeenFrame[id] != frameCounter {
            recycle(node)
            tileNodes[id] = nil
            nodeLastSeenFrame[id] = nil
            if let hitbox = hitboxNodes.removeValue(forKey: id) {
                hitbox.removeFromParent()
            }
        }
    }

    private func makeNode(for tile: PianoTile) -> PianoTileNode {
        let node: PianoTileNode
        if let pooled = nodePool.popLast() {
            node = pooled
            node.resetToActive()
        } else {
            node = PianoTileNode(tile: tile, size: geometry.tileSize)
        }
        node.size = geometry.tileSize
        node.isHidden = false
        node.rebind(to: tile.id)
        tileLayer.addChild(node)
        tileNodes[tile.id] = node
        return node
    }

    private func recycle(_ node: PianoTileNode) {
        node.removeAllActions()
        node.removeFromParent()
        node.isHidden = true
        nodePool.append(node)
    }

    private func recycleAllTileNodes() {
        for (_, node) in tileNodes {
            recycle(node)
        }
        tileNodes.removeAll(keepingCapacity: true)
        nodeLastSeenFrame.removeAll(keepingCapacity: true)
        for (_, hitbox) in hitboxNodes {
            hitbox.removeFromParent()
        }
        hitboxNodes.removeAll()
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle every touch so both tiles of a double row can be tapped simultaneously.
        for touch in touches {
            let scenePoint = touch.location(in: self)
            let outcome = logic.handleTap(at: geometry.fromScene(scenePoint))
            if case .hit(let tile) = outcome {
                tileNodes[tile.id]?.applyHit(config: config)
            }
        }
        // Apply score/state changes now instead of waiting for the next frame.
        handleEvents(logic.drainEvents())
    }

    // MARK: - Debug

    private func applyDebugOptions() {
        debugLabel.isHidden = !debugOptions.showPerformanceOverlay
        if !debugOptions.showHitboxes {
            for (_, hitbox) in hitboxNodes {
                hitbox.removeFromParent()
            }
            hitboxNodes.removeAll()
        }
        if debugOptions.showMissLine {
            if missLineNode == nil, hudLayer.parent != nil {
                let path = CGMutablePath()
                let y = size.height - geometry.missLineY
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                let line = SKShapeNode(path: path)
                line.strokeColor = AppTheme.UIColors.debugMissLine
                line.lineWidth = 2
                line.zPosition = 50
                addChild(line)
                missLineNode = line
            }
        } else {
            missLineNode?.removeFromParent()
            missLineNode = nil
        }
    }

    private func syncHitbox(for tile: PianoTile, row: PianoRow) {
        let cell = CGRect(
            x: geometry.laneWidth * CGFloat(tile.lane),
            y: row.top,
            width: geometry.laneWidth,
            height: geometry.rowHeight
        )
        let node: SKShapeNode
        if let existing = hitboxNodes[tile.id] {
            node = existing
        } else {
            node = SKShapeNode(rectOf: cell.size)
            node.strokeColor = AppTheme.UIColors.debugHitbox
            node.lineWidth = 2
            node.fillColor = .clear
            hitboxLayer.addChild(node)
            hitboxNodes[tile.id] = node
        }
        node.isHidden = tile.state != .active
        node.position = geometry.toScene(CGPoint(x: cell.midX, y: cell.midY))
    }

    private func refreshDebugOverlay() {
        let reaction = logic.lastReactionTime.map { "\(Int($0 * 1000)) ms" } ?? "–"
        let stateText: String = switch logic.state {
        case .ready: "ready"
        case .countdown: "countdown"
        case .waitingForStart: "waiting"
        case .playing: "playing"
        case .paused: "paused"
        case .gameOver(let reason): "over(\(reason))"
        }
        debugLabel.text = """
        FPS: \(Int(smoothedFPS.rounded()))
        State: \(stateText)
        Score: \(logic.score)
        Tiles Active: \(logic.activeTileCount)
        Speed: \(Int(logic.speed)) pt/s (\(String(format: "%.3f", logic.speed / size.height)) h/s)
        Spawn Interval: \(String(format: "%.3f", logic.spawnInterval))s
        Last Reaction: \(reaction)
        Game Time: \(String(format: "%.2f", logic.elapsedTime))s
        Rows: \(logic.rows.count)  Nodes: \(tileNodes.count)  Pool: \(nodePool.count)
        """
    }
}
