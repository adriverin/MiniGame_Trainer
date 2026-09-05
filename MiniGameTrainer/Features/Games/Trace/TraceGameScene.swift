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
    private let startPulseNode = SKShapeNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var nodeShapes: [TraceNode: SKShapeNode] = [:]
    private var hitboxShapes: [TraceNode: SKShapeNode] = [:]
    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var measuredFPS = 0.0
    private var autoSolveAccumulator: TimeInterval = 0
    private var activeTouch: UITouch?

    private enum Z {
        static let dimDots: CGFloat = 1
        static let pathStroke: CGFloat = 2
        static let startPulse: CGFloat = 3
        static let pathNodes: CGFloat = 4
        static let hud: CGFloat = 20
        static let debug: CGFloat = 40
    }

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
        gridNode.zPosition = Z.dimDots
        addChild(gridNode)
        configureStroke(referencePathNode, color: config.referenceColor)
        configureStroke(playerPathNode, color: config.playerColor)
        configureStroke(livePathNode, color: config.playerColor)
        startPulseNode.fillColor = .clear
        startPulseNode.strokeColor = config.playerColor
        startPulseNode.lineWidth = 2
        startPulseNode.zPosition = Z.startPulse
        startPulseNode.isHidden = true
        addChild(startPulseNode)
        timerTrack.fillColor = config.timerTrackColor
        timerTrack.strokeColor = .clear
        timerTrack.zPosition = Z.hud
        addChild(timerTrack)
        timerFill.fillColor = config.timerFillColor
        timerFill.strokeColor = .clear
        timerFill.zPosition = Z.hud
        addChild(timerFill)
        scoreLabel.fontColor = config.scoreColor
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = Z.hud
        addChild(scoreLabel)
        debugLabel.fontSize = 11
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.zPosition = Z.debug
        debugLabel.isHidden = true
        addChild(debugLabel)
        layoutHUD()
    }

    private func configureStroke(_ node: SKShapeNode, color: UIColor) {
        node.lineCap = .round
        node.lineJoin = .round
        node.fillColor = .clear
        node.strokeColor = color
        node.zPosition = Z.pathStroke
        addChild(node)
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
        for node in geometry.field.allNodes {
            let shape = SKShapeNode(circleOfRadius: geometry.nodeVisualRadius)
            shape.fillColor = config.inactiveNodeColor
            shape.strokeColor = .clear
            shape.position = geometry.position(for: node)
            shape.zPosition = Z.dimDots
            gridNode.addChild(shape)
            nodeShapes[node] = shape
            let hit = SKShapeNode(circleOfRadius: geometry.nodeHitRadius)
            hit.fillColor = .clear
            hit.strokeColor = AppTheme.UIColors.debugHitbox
            hit.lineWidth = 1
            hit.position = shape.position
            hit.zPosition = Z.pathNodes
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
        if let radius = debugOptions.forcedRadius {
            logic.forcedField = TraceHexField(radius: radius)
        } else {
            logic.forcedField = nil
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
        if logic.geometry.field != renderedField {
            rebuildGrid()
        }
    }

    private var renderedField: TraceHexField {
        logic.geometry.field
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
        let failed = logic.lastFailure != nil
        playerPathNode.path = path(for: logic.playerSequence)
        playerPathNode.strokeColor = failed ? config.incorrectColor : config.playerColor
        if logic.phase == .tracing, let last = logic.playerSequence.last, let touch = logic.lastTouch {
            let live = CGMutablePath()
            live.move(to: geometry.position(for: last))
            live.addLine(to: touch)
            livePathNode.path = live
            livePathNode.strokeColor = failed ? config.incorrectColor : config.playerColor
            livePathNode.isHidden = false
        } else {
            livePathNode.path = nil
            livePathNode.isHidden = true
        }
        syncStartPulse(geometry: geometry)
        let referenceSet = Set(referenceVisible)
        let playerSet = Set(logic.playerSequence)
        let anchor = logic.recallAnchor
        for (node, shape) in nodeShapes {
            let isPathNode: Bool
            if failed, playerSet.contains(node) {
                shape.fillColor = config.incorrectColor
                isPathNode = true
            } else if playerSet.contains(node) {
                shape.fillColor = config.playerColor
                isPathNode = true
            } else if referenceSet.contains(node) {
                shape.fillColor = config.referenceColor
                isPathNode = true
            } else if node == anchor, logic.phase == .awaitingTrace || logic.phase == .tracing || failed {
                shape.fillColor = failed ? config.incorrectColor : config.playerColor
                isPathNode = true
            } else {
                shape.fillColor = config.inactiveNodeColor
                isPathNode = false
            }
            shape.zPosition = isPathNode ? Z.pathNodes : Z.dimDots
            shape.setScale(isPathNode ? 1.06 : 1)
        }
    }

    private func syncStartPulse(geometry: TraceGeometry) {
        let shouldShow = logic.phase == .awaitingTrace
            && logic.playerSequence.isEmpty
            && logic.recallAnchor != nil
            && logic.lastFailure == nil
        guard shouldShow, let anchor = logic.recallAnchor else {
            startPulseNode.isHidden = true
            startPulseNode.removeAllActions()
            return
        }
        let radius = geometry.nodeVisualRadius * 1.85
        startPulseNode.path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
        startPulseNode.position = geometry.position(for: anchor)
        startPulseNode.strokeColor = config.playerColor
        startPulseNode.lineWidth = max(1.5, geometry.lineWidth)
        startPulseNode.isHidden = false
        if startPulseNode.action(forKey: "pulse") == nil {
            startPulseNode.setScale(1)
            startPulseNode.alpha = 0.85
            let pulse = SKAction.repeatForever(.sequence([
                .group([
                    .scale(to: 1.55, duration: 0.65),
                    .fadeAlpha(to: 0.12, duration: 0.65),
                ]),
                .group([
                    .scale(to: 1.0, duration: 0.65),
                    .fadeAlpha(to: 0.85, duration: 0.65),
                ]),
            ]))
            startPulseNode.run(pulse, withKey: "pulse")
        }
    }

    private func path(for nodes: [TraceNode]) -> CGPath? {
        guard nodes.count >= 2, let first = nodes.first else { return nil }
        let path = CGMutablePath()
        path.move(to: logic.geometry.position(for: first))
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
        debugLabel.text = """
        TRACE DEBUG
        score \(logic.score)  round \(logic.roundIndex)
        hex r\(logic.field.radius)  nodes \(logic.field.nodeCount)
        target \(logic.targetSequence.count)  player \(logic.playerSequence.count)
        state \(logic.phase.rawValue)
        expose \(String(format: "%.2f", logic.patternElapsed))s
        recall \(String(format: "%.2f", logic.recallRemaining)) / \(String(format: "%.2f", logic.recallDuration))s
        seed \(logic.seed)
        fps \(String(format: "%.0f", measuredFPS))
        target \(target)
        """
    }
}
