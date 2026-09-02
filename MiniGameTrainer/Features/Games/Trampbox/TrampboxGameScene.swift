import SpriteKit
import UIKit

@MainActor
protocol TrampboxGameSceneDelegate: AnyObject {
    func trampboxSceneDidLand(_ scene: TrampboxGameScene)
    func trampboxSceneDidFail(_ scene: TrampboxGameScene)
    func trampboxSceneCountdownDidTick(_ scene: TrampboxGameScene)
    func trampboxScene(_ scene: TrampboxGameScene, didEndWith summary: TrampboxSessionSummary)
}

final class TrampboxGameScene: SKScene {
    let logic: TrampboxGameLogic
    let config: TrampboxGameConfig
    weak var gameDelegate: TrampboxGameSceneDelegate?

    var debugOptions: TrampboxDebugOptions {
        didSet { applyDebugOptions() }
    }

    private let worldLayer = SKNode()
    private let hudLayer = SKNode()
    private let ballNode: SKShapeNode
    private let ballHighlight: SKShapeNode
    private let scoreLabel = SKLabelNode()
    private let scoreShadow = SKLabelNode()
    private let countdownLabel = SKLabelNode()
    private let debugLabel = SKLabelNode()
    private let failureLine = SKShapeNode()
    private let reachableLine = SKShapeNode()
    private var platformNodes: [Int: TrampboxPlatformNode] = [:]
    private var lastUpdateTime: TimeInterval = 0
    private var needsTimeReset = true
    private var smoothedFPS: Double = 0
    private var debugAccumulator: TimeInterval = 0
    private var activeTouch: UITouch?
    private var lastTouchX: CGFloat?
    private var hasReportedEnd = false

    init(size: CGSize, config: TrampboxGameConfig, debugOptions: TrampboxDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = TrampboxGameLogic(config: config, sceneSize: size)
        let radius = logic.geometry.ballRadius
        ballNode = SKShapeNode(circleOfRadius: radius)
        ballHighlight = SKShapeNode(circleOfRadius: radius * 0.27)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.10, green: 0.07, blue: 0.20, alpha: 1)
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

    func startSession() {
        isPaused = false
        removeAllActions()
        countdownLabel.removeAllActions()
        countdownLabel.isHidden = true
        hasReportedEnd = false
        needsTimeReset = true
        activeTouch = nil
        lastTouchX = nil
        logic.reset()
        _ = logic.drainEvents()
        recyclePlatforms()
        updateScore(0)
        syncNodes()
        if debugOptions.skipCountdown {
            logic.startPlaying()
            handle(logic.drainEvents())
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
        handle(logic.drainEvents())
    }

    private func buildScene() {
        let background = SKSpriteNode(texture: makeGradientTexture(), size: size)
        background.anchorPoint = .zero
        background.position = .zero
        background.zPosition = -100
        addChild(background)

        worldLayer.zPosition = 10
        addChild(worldLayer)
        hudLayer.zPosition = 100
        addChild(hudLayer)

        ballNode.fillColor = UIColor(white: 0.025, alpha: 1)
        ballNode.strokeColor = UIColor(white: 0.18, alpha: 1)
        ballNode.lineWidth = 1.5
        ballNode.zPosition = 10_000
        worldLayer.addChild(ballNode)
        ballHighlight.fillColor = UIColor(white: 0.35, alpha: 0.38)
        ballHighlight.strokeColor = .clear
        ballHighlight.position = CGPoint(x: -logic.geometry.ballRadius * 0.28, y: logic.geometry.ballRadius * 0.30)
        ballNode.addChild(ballHighlight)

        for label in [scoreShadow, scoreLabel] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            hudLayer.addChild(label)
        }
        let scoreY = size.height * (1 - config.scoreYRatio)
        scoreShadow.position = CGPoint(x: size.width / 2 + 2, y: scoreY - 3)
        scoreLabel.position = CGPoint(x: size.width / 2, y: scoreY)
        scoreLabel.zPosition = 1

        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        countdownLabel.zPosition = 10
        countdownLabel.isHidden = true
        hudLayer.addChild(countdownLabel)

        debugLabel.fontName = "Menlo-Bold"
        debugLabel.fontSize = 10
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.position = CGPoint(x: 10, y: size.height - 58)
        debugLabel.zPosition = 300
        hudLayer.addChild(debugLabel)

        failureLine.strokeColor = AppTheme.UIColors.debugMissLine
        failureLine.lineWidth = 1
        failureLine.zPosition = 200
        worldLayer.addChild(failureLine)
        reachableLine.strokeColor = UIColor(red: 0.3, green: 0.8, blue: 1, alpha: 0.8)
        reachableLine.lineWidth = 2
        reachableLine.zPosition = 200
        worldLayer.addChild(reachableLine)
        applyDebugOptions()
    }

    private func makeGradientTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 512))
        let image = renderer.image { context in
            let colors = [
                UIColor(red: 0.12, green: 0.09, blue: 0.22, alpha: 1).cgColor,
                UIColor(red: 0.26, green: 0.20, blue: 0.46, alpha: 1).cgColor,
                UIColor(red: 0.38, green: 0.25, blue: 0.72, alpha: 1).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1])!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: 512),
                options: []
            )
        }
        return SKTexture(image: image)
    }

    private func runCountdown() {
        logic.beginCountdown()
        let fontSize = size.height * 0.14
        var actions: [SKAction] = []
        for value in stride(from: config.countdownSteps, through: 1, by: -1) {
            actions.append(countdownStep("\(value)", fontSize: fontSize, duration: config.countdownStepDuration))
        }
        actions.append(countdownStep("GO", fontSize: fontSize * 0.68, duration: config.countdownStepDuration / 2))
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.countdownLabel.isHidden = true
            self.logic.startPlaying()
            self.handle(self.logic.drainEvents())
        })
        countdownLabel.isHidden = false
        countdownLabel.run(.sequence(actions), withKey: "countdown")
    }

    private func countdownStep(_ text: String, fontSize: CGFloat, duration: TimeInterval) -> SKAction {
        let show = SKAction.run { [weak self] in
            guard let self else { return }
            self.countdownLabel.attributedText = self.attributed(text, size: fontSize, color: .white)
            self.countdownLabel.setScale(1.2)
            self.countdownLabel.alpha = 1
            self.gameDelegate?.trampboxSceneCountdownDidTick(self)
        }
        let pop = SKAction.scale(to: 1, duration: min(0.14, duration * 0.4))
        pop.timingMode = .easeOut
        return .sequence([show, pop, .wait(forDuration: max(0, duration - pop.duration))])
    }

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if needsTimeReset {
            delta = 0
            needsTimeReset = false
        } else {
            delta = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        if delta > 0 {
            let instant = 1 / delta
            smoothedFPS = smoothedFPS == 0 ? instant : smoothedFPS * 0.9 + instant * 0.1
        }
        if debugOptions.autoSteer, let target = logic.targetPlatform {
            logic.applyDrag(deltaX: target.centerX - logic.desiredBallX)
        }
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

    private func handle(_ events: [TrampboxGameEvent]) {
        for event in events {
            switch event {
            case .landed:
                gameDelegate?.trampboxSceneDidLand(self)
            case .scoreChanged(let score):
                updateScore(score)
                scheduleDebugCapturePause(after: score)
            case .gameEnded(let reason):
                handleGameOver(reason)
            case .stateChanged:
                break
            }
        }
    }

    private func scheduleDebugCapturePause(after score: Int) {
        guard let captureScore = debugOptions.pauseAtScore,
              score >= captureScore,
              action(forKey: "debugCapturePause") == nil else { return }
        // Leave enough animation time to show the outgoing platform beginning its tumble.
        run(.sequence([
            .wait(forDuration: 0.14),
            .run { [weak self] in self?.isPaused = true },
        ]), withKey: "debugCapturePause")
    }

    private func handleGameOver(_ reason: TrampboxGameOverReason) {
        guard !hasReportedEnd else { return }
        hasReportedEnd = true
        if reason == .missedPlatform { gameDelegate?.trampboxSceneDidFail(self) }
        let summary = logic.makeSummary()
        let hold = reason == .aborted ? 0 : config.gameOverHoldDuration
        run(.sequence([
            .wait(forDuration: hold),
            .run { [weak self] in
                guard let self else { return }
                self.gameDelegate?.trampboxScene(self, didEndWith: summary)
            },
        ]), withKey: "gameOver")
    }

    private func syncNodes() {
        let ids = Set(logic.platforms.map(\.id))
        for (id, node) in platformNodes where !ids.contains(id) {
            platformNodes[id] = nil
            let direction: CGFloat = id.isMultiple(of: 2) ? -1 : 1
            let duration = max(0.32, logic.bounceDuration * Double(config.departureDurationMultiplier))
            node.depart(sceneSize: size, duration: duration, direction: direction, config: config)
        }

        for (slot, platform) in logic.platforms.enumerated() {
            let node: TrampboxPlatformNode
            if let existing = platformNodes[platform.id] {
                node = existing
            } else {
                node = TrampboxPlatformNode()
                platformNodes[platform.id] = node
                worldLayer.addChild(node)
            }
            let topY = logic.geometry.platformTopY(slot: slot, bouncePhase: logic.bouncePhase)
            let widthScale = logic.geometry.projectedWidthScale(atScreenY: topY)
            let projectedWidth = logic.geometry.projectedPlatformWidth(logicalWidth: platform.width, atScreenY: topY)
            let topDepth = logic.geometry.projectedTopDepth(projectedWidth: projectedWidth, atScreenY: topY)
            let sideDepth = logic.geometry.projectedSideDepth(projectedWidth: projectedWidth, atScreenY: topY)
            let convergedX = size.width / 2 + (platform.centerX - size.width / 2) * widthScale
            node.position = logic.geometry.scenePoint(screenPoint: CGPoint(x: convergedX, y: topY))
            node.zPosition = topY
            node.render(
                width: projectedWidth,
                topDepth: topDepth,
                sideDepth: sideDepth,
                rotation: logic.geometry.approachRotation(platformID: platform.id, atScreenY: topY),
                showGeometry: debugOptions.showGeometry
            )
        }

        ballNode.position = logic.geometry.scenePoint(screenPoint: CGPoint(x: logic.ballX, y: logic.ballScreenY))
        updateDebugGeometry()
    }

    private func recyclePlatforms() {
        worldLayer.enumerateChildNodes(withName: "trampboxPlatform") { node, _ in node.removeFromParent() }
        platformNodes.removeAll(keepingCapacity: true)
    }

    private func updateScore(_ score: Int) {
        let fontSize = config.scoreFontSizeRatio * size.height
        scoreLabel.attributedText = attributed("\(score)", size: fontSize, color: .white)
        scoreShadow.attributedText = attributed("\(score)", size: fontSize, color: UIColor(white: 0, alpha: 0.45))
    }

    private func attributed(_ text: String, size fontSize: CGFloat, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: color,
        ])
    }

    private func applyDebugOptions() {
        debugLabel.isHidden = !debugOptions.showPerformanceOverlay
        failureLine.isHidden = !debugOptions.showGeometry
        reachableLine.isHidden = !debugOptions.showGeometry
    }

    private func updateDebugGeometry() {
        guard debugOptions.showGeometry else { return }
        let failY = size.height - logic.geometry.failureY
        let failPath = CGMutablePath()
        failPath.move(to: CGPoint(x: 0, y: failY))
        failPath.addLine(to: CGPoint(x: size.width, y: failY))
        failureLine.path = failPath

        let range = logic.reachableRange
        let y = size.height - logic.geometry.landingY + 24
        let path = CGMutablePath()
        path.move(to: CGPoint(x: max(0, logic.ballX - range), y: y))
        path.addLine(to: CGPoint(x: min(size.width, logic.ballX + range), y: y))
        reachableLine.path = path
    }

    private func refreshDebugOverlay() {
        let targetX = logic.targetPlatform?.centerX ?? 0
        let lastError = logic.lastLanding?.horizontalError ?? 0
        debugLabel.text = String(
            format: "FPS %.0f\nscore %d  phase %.2f\nbounce %.3f s  width %.0f pt\nballX %.0f  targetX %.0f\nvelocity %.0f pt/s  reach ±%.0f\nlast error %.1f pt  platforms %d",
            smoothedFPS,
            logic.score,
            logic.bouncePhase,
            logic.bounceDuration,
            logic.platformWidth,
            logic.ballX,
            targetX,
            logic.horizontalVelocity,
            logic.reachableRange,
            lastError,
            logic.platforms.count
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        lastTouchX = touch.location(in: self).x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch), let previousX = lastTouchX else { return }
        let x = activeTouch.location(in: self).x
        logic.applyDrag(deltaX: x - previousX)
        lastTouchX = x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        lastTouchX = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
