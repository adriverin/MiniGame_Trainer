import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol TraceGameSceneDelegate: AnyObject {
    func traceSceneDidAcceptNode(_ scene: TraceGameScene)
    func traceSceneDidFail(_ scene: TraceGameScene)
    func traceSceneDidCompletePattern(_ scene: TraceGameScene)
    func traceScene(_ scene: TraceGameScene, didEndWith summary: TraceSessionSummary)
}

@MainActor
final class TraceGameScene: SKScene {
    let logic: TraceGameLogic
    let config: TraceGameConfig
    weak var gameDelegate: TraceGameSceneDelegate?

    var debugOptions: TraceDebugOptions {
        didSet { applyDebugOptions() }
    }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let timerTrack = SKShapeNode()
    private let timerFill = SKShapeNode()
    private let gridNode = SKNode()
    private let referencePathNode = SKShapeNode()
    private let playerPathNode = SKShapeNode()
    private let livePathNode = SKShapeNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var nodeShapes: [TraceNode: SKShapeNode] = [:]
    private var hitboxShapes: [TraceNode: SKShapeNode] = [:]
    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var measuredFPS = 0.0
    private var autoSolveAccumulator: TimeInterval = 0
    private var activeTouch: UITouch?

    init(size: CGSize, config: TraceGameConfig, debugOptions: TraceDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = TraceGameLogic(config: config, sceneSize: size, seed: debugOptions.forcedSeed)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
        applyDebugOptions()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if logic.phase == .ready { logic.start() }
        rebuildGrid()
        syncPresentation()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard oldSize != size, size.width >= 50, size.height >= 50 else { return }
        logic.resize(sceneSize: size)
        rebuildGrid()
        layoutHUD()
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        applyDebugOptions()
        if let previousFrameTime {
            let delta = min(max(0, currentTime - previousFrameTime), config.maximumFrameDelta)
            if delta > 0 {
                let fps = 1 / delta
                measuredFPS = measuredFPS == 0 ? fps : measuredFPS * 0.9 + fps * 0.1
            }
            applyAutoSolve(deltaTime: delta)
            logic.update(deltaTime: delta)
            handleEvents()
        }
        previousFrameTime = currentTime
        syncPresentation()
        updateDebugOverlay()
        if logic.isFinished, let finishReportTime, currentTime >= finishReportTime, !didReportFinish {
            didReportFinish = true
            gameDelegate?.traceScene(self, didEndWith: logic.makeSummary())
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        logic.beginTouch(position: touch.location(in: self))
        handleEvents()
        syncPresentation()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        logic.moveTouch(position: activeTouch.location(in: self))
        handleEvents()
        syncPresentation()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.endTouch()
        handleEvents()
        syncPresentation()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause()
        activeTouch = nil
        isPaused = true
        syncPresentation()
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        logic.resume()
        rebuildGrid()
        syncPresentation()
    }

    func startSession() {
        isPaused = false
        activeTouch = nil
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        autoSolveAccumulator = 0
        applyDebugOptions()
        logic.reset()
        logic.start()
        rebuildGrid()
        syncPresentation()
    }

    private func setupNodes() {
        addChild(gridNode)
        referencePathNode.lineCap = .round
        referencePathNode.lineJoin = .round
        referencePathNode.fillColor = .clear
        referencePathNode.strokeColor = config.referenceColor
        addChild(referencePathNode)
        playerPathNode.lineCap = .round
        playerPathNode.lineJoin = .round
        playerPathNode.fillColor = .clear
        playerPathNode.strokeColor = config.playerColor
        addChild(playerPathNode)
        livePathNode.lineCap = .round
        livePathNode.lineJoin = .round
        livePathNode.fillColor = .clear
        livePathNode.strokeColor = config.playerColor
        addChild(livePathNode)
        timerTrack.fillColor = config.timerTrackColor
        timerTrack.strokeColor = .clear
        addChild(timerTrack)
        timerFill.fillColor = config.timerFillColor
        timerFill.strokeColor = .clear
        addChild(timerFill)
        scoreLabel.fontColor = config.scoreColor
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 20
        addChild(scoreLabel)
        debugLabel.fontSize = 11
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.zPosition = 40
        debugLabel.isHidden = true
        addChild(debugLabel)
        layoutHUD()
    }

    private func layoutHUD() {
        logic.resize(sceneSize: size)
        scoreLabel.position = logic.geometry.scorePosition
        scoreLabel.fontSize = max(36, size.width * 0.12)
        debugLabel.position = CGPoint(x: 16, y: size.height - 16)
    }

    private func rebuildGrid() {
        gridNode.removeAllChildren()
        nodeShapes.removeAll()
        hitboxShapes.removeAll()
        let geometry = logic.geometry
        for node in geometry.grid.allNodes {
            let shape = SKShapeNode(circleOfRadius: geometry.nodeVisualRadius)
            shape.fillColor = config.inactiveNodeColor
            shape.strokeColor = .clear
            shape.position = geometry.position(for: node)
            shape.zPosition = 2
            gridNode.addChild(shape)
            nodeShapes[node] = shape
            let hit = SKShapeNode(circleOfRadius: geometry.nodeHitRadius)
            hit.fillColor = .clear
            hit.strokeColor = AppTheme.UIColors.debugHitbox
            hit.lineWidth = 1
            hit.position = shape.position
            hit.zPosition = 3
            hit.isHidden = !debugOptions.showHitboxes
            gridNode.addChild(hit)
            hitboxShapes[node] = hit
        }
    }

    private func applyDebugOptions() {
        logic.skipPresentation = debugOptions.skipPresentation
        logic.scoreOverride = debugOptions.forcedScore
        logic.forcedTargetCount = debugOptions.forcedTargetCount
        logic.forcedPattern = debugOptions.forcedPattern
        if let rows = debugOptions.forcedRows, let columns = debugOptions.forcedColumns {
            logic.forcedGrid = TraceGridSize(rows: rows, columns: columns)
        } else {
            logic.forcedGrid = nil
        }
        hitboxShapes.values.forEach { $0.isHidden = !debugOptions.showHitboxes }
        debugLabel.isHidden = !debugOptions.showOverlay
    }

    private func applyAutoSolve(deltaTime: TimeInterval) {
        guard debugOptions.autoSolve, logic.acceptsInput else { return }
        autoSolveAccumulator += deltaTime
        guard autoSolveAccumulator >= 0.08 else { return }
        autoSolveAccumulator = 0
        logic.applyDebugSolve(correct: !debugOptions.autoSolveWrong)
    }

    private func handleEvents() {
        let events = logic.drainEvents()
        for event in events {
            switch event {
            case .patternStarted:
                rebuildGrid()
            case .nodeAccepted:
                gameDelegate?.traceSceneDidAcceptNode(self)
            case .patternCompleted:
                gameDelegate?.traceSceneDidCompletePattern(self)
            case .patternFailed:
                gameDelegate?.traceSceneDidFail(self)
            case .sessionEnded:
                finishReportTime = CACurrentMediaTime() + config.evaluationDuration
            default:
                break
            }
        }
        if logic.geometry.grid != gridFromShapes {
            rebuildGrid()
        }
    }

    private var gridFromShapes: TraceGridSize {
        logic.geometry.grid
    }

    private func syncPresentation() {
        let geometry = logic.geometry
        scoreLabel.text = "\(logic.score)"
        let frame = geometry.timerFrame
        timerTrack.path = CGPath(roundedRect: frame, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2, transform: nil)
        let progress = logic.timerProgress
        let fillWidth = max(frame.height, frame.width * progress)
        let fillRect = CGRect(x: frame.minX, y: frame.minY, width: fillWidth, height: frame.height)
        timerFill.path = progress > 0.001
            ? CGPath(roundedRect: fillRect, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2, transform: nil)
            : nil
        timerFill.isHidden = progress <= 0.001
        referencePathNode.lineWidth = geometry.lineWidth
        playerPathNode.lineWidth = geometry.lineWidth
        livePathNode.lineWidth = geometry.lineWidth
        let referenceVisible = Array(logic.targetSequence.prefix(logic.visibleReferenceCount))
        referencePathNode.path = path(for: referenceVisible)
        referencePathNode.strokeColor = config.referenceColor
        let failed = logic.lastFailure != nil && (logic.phase == .evaluating || logic.phase == .transitioning)
        playerPathNode.path = path(for: logic.playerSequence)
        playerPathNode.strokeColor = failed ? config.incorrectColor : config.playerColor
        if logic.phase == .tracing, let last = logic.playerSequence.last, let touch = logic.lastTouch {
            let live = CGMutablePath()
            live.move(to: geometry.position(for: last))
            live.addLine(to: touch)
            livePathNode.path = live
            livePathNode.isHidden = false
        } else {
            livePathNode.path = nil
            livePathNode.isHidden = true
        }
        let referenceSet = Set(referenceVisible)
        let playerSet = Set(logic.playerSequence)
        for (node, shape) in nodeShapes {
            if failed, playerSet.contains(node) {
                shape.fillColor = config.incorrectColor
            } else if playerSet.contains(node) {
                shape.fillColor = config.playerColor
            } else if referenceSet.contains(node) {
                shape.fillColor = config.referenceColor
            } else {
                shape.fillColor = config.inactiveNodeColor
            }
            shape.setScale(playerSet.contains(node) || referenceSet.contains(node) ? 1.08 : 1)
        }
    }

    private func path(for nodes: [TraceNode]) -> CGPath? {
        guard let first = nodes.first else { return nil }
        let path = CGMutablePath()
        path.move(to: logic.geometry.position(for: first))
        if nodes.count == 1 {
            let radius = logic.geometry.lineWidth / 2
            path.addEllipse(in: CGRect(x: path.currentPoint.x - radius, y: path.currentPoint.y - radius, width: radius * 2, height: radius * 2))
            return path
        }
        for node in nodes.dropFirst() {
            path.addLine(to: logic.geometry.position(for: node))
        }
        return path
    }

    private func updateDebugOverlay() {
        guard debugOptions.showOverlay else { return }
        let target = logic.phase == .showingPattern || debugOptions.showOverlay
            ? logic.targetSequence.map(\.description).joined(separator: "→")
            : "(hidden during recall)"
        // Overlay is DEBUG-only. Target is listed here for QA; the gameplay path is never shown in recall.
        debugLabel.text = """
        TRACE DEBUG
        score \(logic.score)  round \(logic.roundIndex)
        grid \(logic.grid.rows)×\(logic.grid.columns)
        target \(logic.targetSequence.count)  player \(logic.playerSequence.count)
        state \(logic.phase.rawValue)
        expose \(String(format: "%.2f", logic.patternElapsed))s
        recall \(String(format: "%.2f", logic.recallRemaining)) / \(String(format: "%.2f", logic.recallDuration))s
        stage \(logic.currentDifficultyStage)  seed \(logic.seed)
        fps \(String(format: "%.0f", measuredFPS))
        target \(target)
        """
    }
}
