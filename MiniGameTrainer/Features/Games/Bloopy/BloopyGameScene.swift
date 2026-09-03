import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol BloopyGameSceneDelegate: AnyObject {
    func bloopySceneDidBounce(_ scene: BloopyGameScene)
    func bloopySceneDidFail(_ scene: BloopyGameScene)
    func bloopyScene(_ scene: BloopyGameScene, didEndWith summary: BloopySessionSummary)
}

@MainActor
final class BloopyGameScene: SKScene {
    let logic: BloopyGameLogic
    let config: BloopyGameConfig
    let geometry: BloopyGeometry
    weak var gameDelegate: BloopyGameSceneDelegate?

    var debugOptions: BloopyDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let ballNode: SKShapeNode
    private let wrapBallNode: SKShapeNode
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var trailNodes: [SKShapeNode] = []
    private var platformNodes: [Int: SKShapeNode] = [:]
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugBallNode = SKShapeNode()
    private let debugWrapNode = SKShapeNode()
    private let debugFollowNode = SKShapeNode()
    private let debugFailureNode = SKShapeNode()
    private let debugBoundsNode = SKShapeNode()

    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var measuredFPS = 0.0
    private var activeTouch: UITouch?

    init(size: CGSize, config: BloopyGameConfig, debugOptions: BloopyDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = BloopyGeometry(sceneSize: size, config: config)
        logic = BloopyGameLogic(config: config, sceneSize: size)
        ballNode = SKShapeNode(circleOfRadius: geometry.ballRadius)
        wrapBallNode = SKShapeNode(circleOfRadius: geometry.ballRadius)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        logic.scoreOverride = debugOptions.forcedScore
        logic.start()
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        logic.scoreOverride = debugOptions.forcedScore
        if let previousFrameTime {
            let delta = min(max(0, currentTime - previousFrameTime), config.maximumFrameDelta)
            if delta > 0 {
                let fps = 1 / delta
                measuredFPS = measuredFPS == 0 ? fps : measuredFPS * 0.9 + fps * 0.1
            }
            applyDebugAutomation()
            logic.update(deltaTime: delta)
            handleEvents(at: currentTime)
        }
        previousFrameTime = currentTime
        syncPresentation()
        updateDebugOverlay()

        if logic.isFinished,
           let finishReportTime,
           currentTime >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.bloopyScene(self, didEndWith: logic.makeSummary())
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.max(by: { $0.timestamp < $1.timestamp }) else { return }
        activeTouch = touch
        logic.beginTouch(at: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        logic.moveTouch(to: activeTouch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    func pauseGame() {
        logic.pause()
        activeTouch = nil
        previousFrameTime = nil
    }

    func resumeGame() {
        previousFrameTime = nil
        logic.resume()
    }

    func startSession() {
        activeTouch = nil
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        logic.reset()
        logic.scoreOverride = debugOptions.forcedScore
        logic.start()
        syncPresentation()
    }

    private func setupNodes() {
        scoreLabel.fontSize = max(42, size.width * config.scoreFontSizeRatio)
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * config.scoreYRatio)
        scoreLabel.zPosition = 2
        addChild(scoreLabel)

        for _ in 0..<logic.trailCapacity {
            let node = SKShapeNode(circleOfRadius: geometry.ballRadius)
            node.fillColor = config.trailColor
            node.strokeColor = .clear
            node.zPosition = 3
            node.isHidden = true
            addChild(node)
            trailNodes.append(node)
        }

        for node in [ballNode, wrapBallNode] {
            node.fillColor = config.ballColor
            node.strokeColor = .clear
            node.zPosition = 6
            addChild(node)
        }
        wrapBallNode.isHidden = true

        setupDebugNodes()
        updateDebugVisibility()
    }

    private func setupDebugNodes() {
        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.022)
        debugLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        debugLabel.position = CGPoint(x: 10, y: size.height - 50)
        debugLabel.zPosition = 100
        addChild(debugLabel)

        for node in [debugBallNode, debugWrapNode, debugFollowNode, debugFailureNode, debugBoundsNode] {
            node.fillColor = .clear
            node.lineWidth = 1
            node.zPosition = 80
            addChild(node)
        }
        debugBallNode.strokeColor = .systemPurple
        debugWrapNode.strokeColor = UIColor.systemCyan.withAlphaComponent(0.8)
        debugFollowNode.strokeColor = .systemYellow
        debugFailureNode.strokeColor = .systemRed
        debugBoundsNode.strokeColor = UIColor.white.withAlphaComponent(0.7)
    }

    private func syncPresentation() {
        let screen = logic.ballScreenPosition
        ballNode.position = screen
        let radius = geometry.ballRadius
        if screen.x < radius {
            wrapBallNode.position = CGPoint(x: screen.x + size.width, y: screen.y)
            wrapBallNode.isHidden = false
        } else if screen.x > size.width - radius {
            wrapBallNode.position = CGPoint(x: screen.x - size.width, y: screen.y)
            wrapBallNode.isHidden = false
        } else {
            wrapBallNode.isHidden = true
        }
        scoreLabel.text = "\(logic.score)"
        syncPlatforms()
        syncTrail()
        syncDebugGeometry()
    }

    private func syncPlatforms() {
        let liveIDs = Set(logic.platforms.map(\.id))
        for (id, node) in platformNodes where !liveIDs.contains(id) {
            node.removeFromParent()
            platformNodes.removeValue(forKey: id)
        }
        for platform in logic.platforms {
            let node = platformNodes[platform.id] ?? makePlatformNode(platform)
            let height = geometry.platformHeight
            let rect = CGRect(x: -platform.width / 2, y: -height / 2, width: platform.width, height: height)
            let corner = height * config.platformCornerRadiusRatio
            node.path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
            node.position = CGPoint(
                x: platform.worldX,
                y: geometry.screenY(worldY: platform.worldY, cameraY: logic.cameraY)
            )
            node.fillColor = platform.kind == .used ? config.usedPlatformColor : config.platformColor
            if platformNodes[platform.id] == nil {
                addChild(node)
                platformNodes[platform.id] = node
            }
        }
    }

    private func makePlatformNode(_ platform: BloopyPlatform) -> SKShapeNode {
        let node = SKShapeNode()
        node.strokeColor = .clear
        node.zPosition = 4
        node.name = "platform-\(platform.id)"
        return node
    }

    private func syncTrail() {
        let samples = debugOptions.showTrail ? logic.trailSamples : []
        for (index, node) in trailNodes.enumerated() {
            guard index < samples.count else {
                node.isHidden = true
                continue
            }
            let sample = samples[index]
            let progress = CGFloat(min(max(sample.age / max(0.001, config.trailLifetime), 0), 1))
            let scale = config.trailMaximumScale + (config.trailMinimumScale - config.trailMaximumScale) * progress
            node.position = CGPoint(
                x: sample.position.x,
                y: geometry.screenY(worldY: sample.position.y, cameraY: logic.cameraY)
            )
            node.setScale(scale)
            node.alpha = config.trailMaximumOpacity + (config.trailMinimumOpacity - config.trailMaximumOpacity) * progress
            node.isHidden = false
        }
    }

    private func handleEvents(at time: TimeInterval) {
        for event in logic.drainEvents() {
            switch event {
            case .bounced:
                gameDelegate?.bloopySceneDidBounce(self)
            case .scoreChanged:
                break
            case .failed:
                gameDelegate?.bloopySceneDidFail(self)
                finishReportTime = time + max(0, config.resultHoldDuration)
                run(.sequence([
                    .colorize(with: .systemRed, colorBlendFactor: 0.28, duration: 0.06),
                    .colorize(withColorBlendFactor: 0, duration: 0.22),
                ]))
            }
        }
    }

    private func applyDebugAutomation() {
        #if DEBUG
        if debugOptions.autoSteer {
            logic.applyAutoSteer()
        }
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        for node in [debugBallNode, debugWrapNode, debugFollowNode, debugFailureNode, debugBoundsNode] {
            node.isHidden = !debugOptions.showGeometry
        }
        syncTrail()
    }

    private func syncDebugGeometry() {
        guard debugOptions.showGeometry else { return }
        let screen = logic.ballScreenPosition
        let r = geometry.ballRadius
        debugBallNode.path = CGPath(ellipseIn: CGRect(x: screen.x - r, y: screen.y - r, width: r * 2, height: r * 2), transform: nil)
        if !wrapBallNode.isHidden {
            debugWrapNode.path = CGPath(
                ellipseIn: CGRect(x: wrapBallNode.position.x - r, y: wrapBallNode.position.y - r, width: r * 2, height: r * 2),
                transform: nil
            )
        } else {
            debugWrapNode.path = nil
        }
        let follow = UIBezierPath()
        follow.move(to: CGPoint(x: 0, y: geometry.cameraFollowY))
        follow.addLine(to: CGPoint(x: size.width, y: geometry.cameraFollowY))
        debugFollowNode.path = follow.cgPath
        let fail = UIBezierPath()
        fail.move(to: CGPoint(x: 0, y: -geometry.failureMargin))
        fail.addLine(to: CGPoint(x: size.width, y: -geometry.failureMargin))
        debugFailureNode.path = fail.cgPath
        debugBoundsNode.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    }

    private func updateDebugOverlay() {
        guard debugOptions.showOverlay else { return }
        let next = logic.nextPlatformAboveBall()
        let reachable: String
        if let next, let current = logic.platforms.first(where: { $0.id == logic.lastLanding?.platformID }) {
            reachable = BloopyPlatformGenerator(config: config).isReachable(from: current, to: next, geometry: geometry)
                ? "yes" : "no"
        } else {
            reachable = "–"
        }
        debugLabel.text = """
        score \(logic.score)  fps \(String(format: "%.0f", measuredFPS))
        ball \(Int(logic.ballPosition.x)),\(Int(logic.ballPosition.y))
        v \(Int(logic.ballVelocity.dx)),\(Int(logic.ballVelocity.dy))
        g \(Int(logic.gravity))  impulse \(Int(logic.bounceImpulse))
        input \(logic.horizontalInput)  accel \(Int(logic.horizontalAcceleration))  maxVX \(Int(logic.maximumHorizontalSpeed))
        cameraY \(Int(logic.cameraY))  wraps \(logic.wrapCount)
        next \(next.map { "\($0.id) x=\(Int($0.worldX)) y=\(Int($0.worldY)) w=\(Int($0.width)) \($0.kind.rawValue)" } ?? "–")
        reachable \(reachable)
        platforms \(logic.platforms.count)
        """
    }
}
