import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol KeepUpGameSceneDelegate: AnyObject {
    func keepUpSceneDidBounce(_ scene: KeepUpGameScene)
    func keepUpSceneDidFail(_ scene: KeepUpGameScene)
    func keepUpScene(_ scene: KeepUpGameScene, didEndWith summary: KeepUpSessionSummary)
}

@MainActor
final class KeepUpGameScene: SKScene {
    let logic: KeepUpGameLogic
    let config: KeepUpGameConfig
    let geometry: KeepUpGeometry
    weak var gameDelegate: KeepUpGameSceneDelegate?

    var debugOptions: KeepUpDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let platformNode: SKShapeNode
    private let ballNode: SKShapeNode
    private let upperLineNode = SKShapeNode()
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var trailNodes: [SKShapeNode] = []
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugPlatformNode = SKShapeNode()
    private let debugCatchNode = SKShapeNode()
    private let debugFailureNode = SKShapeNode()
    private let debugVelocityNode = SKShapeNode()
    private let debugTrajectoryNode = SKShapeNode()
    private let debugPlatformBoundsNode = SKShapeNode()
    private let debugPlatformSweepNode = SKShapeNode()
    private let debugBallSweepNode = SKShapeNode()
    private let debugBallCollisionNode = SKShapeNode()
    private let debugRelativeSweepNode = SKShapeNode()
    private let debugBoundaryNode = SKShapeNode()
    private let debugCeilingLimitNode = SKShapeNode()

    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var measuredFPS = 0.0
    private var lastImpactOffset: CGFloat = 0
    private var lastContactNormal = CGVector.zero
    private var activeTouch: UITouch?

    init(size: CGSize, config: KeepUpGameConfig, debugOptions: KeepUpDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = KeepUpGeometry(sceneSize: size, config: config)
        logic = KeepUpGameLogic(config: config, sceneSize: size)
        platformNode = SKShapeNode(circleOfRadius: geometry.platformRadius)
        ballNode = SKShapeNode(circleOfRadius: geometry.ballRadius)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        logic.start()
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
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
            gameDelegate?.keepUpScene(self, didEndWith: logic.makeSummary())
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        logic.beginTouch(position: touch.location(in: self), at: CACurrentMediaTime())
        syncPresentation()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        logic.moveTouch(position: activeTouch.location(in: self), at: CACurrentMediaTime())
        syncPresentation()
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
        guard !isPaused else { return }
        logic.pause()
        activeTouch = nil
        isPaused = true
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        logic.resume()
    }

    func startSession() {
        isPaused = false
        activeTouch = nil
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        lastImpactOffset = 0
        lastContactNormal = .zero
        logic.reset()
        logic.start()
        syncPresentation()
    }

    private func setupNodes() {
        let upperPath = CGMutablePath()
        upperPath.move(to: CGPoint(x: geometry.upperLineHorizontalInset, y: geometry.upperLineY))
        upperPath.addLine(to: CGPoint(x: size.width - geometry.upperLineHorizontalInset, y: geometry.upperLineY))
        upperLineNode.path = upperPath
        upperLineNode.strokeColor = UIColor.white.withAlphaComponent(config.upperLineOpacity)
        upperLineNode.lineWidth = geometry.upperLineThickness
        upperLineNode.lineCap = .round
        upperLineNode.zPosition = 1
        addChild(upperLineNode)

        scoreLabel.fontSize = max(42, size.width * 0.145)
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

        platformNode.fillColor = .white
        platformNode.fillTexture = KeepUpDiscShading.texture(
            diameter: geometry.platformRadius * 2,
            inner: UIColor(red: 214 / 255, green: 214 / 255, blue: 218 / 255, alpha: 1),
            outer: UIColor(red: 176 / 255, green: 175 / 255, blue: 182 / 255, alpha: 1),
            highlight: UIColor(white: 1, alpha: 0.22),
            highlightOffset: CGVector(dx: -0.12, dy: -0.16)
        )
        platformNode.strokeColor = UIColor.white.withAlphaComponent(0.22)
        platformNode.lineWidth = max(1, size.width * 0.003)
        platformNode.zPosition = 4
        addChild(platformNode)

        ballNode.fillColor = .white
        ballNode.fillTexture = KeepUpDiscShading.texture(
            diameter: geometry.ballRadius * 2,
            inner: UIColor(white: 1, alpha: 1),
            outer: UIColor(red: 226 / 255, green: 227 / 255, blue: 232 / 255, alpha: 1),
            highlight: UIColor(white: 1, alpha: 0.28),
            highlightOffset: CGVector(dx: -0.10, dy: -0.14)
        )
        ballNode.strokeColor = UIColor.white.withAlphaComponent(0.55)
        ballNode.lineWidth = max(0.5, size.width * 0.0015)
        ballNode.zPosition = 6
        addChild(ballNode)

        setupDebugNodes()
        updateDebugVisibility()
    }

    private func setupDebugNodes() {
        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.023)
        debugLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        debugLabel.position = CGPoint(x: 10, y: size.height - 50)
        debugLabel.zPosition = 100
        addChild(debugLabel)

        for node in [debugPlatformNode, debugCatchNode, debugFailureNode, debugVelocityNode, debugTrajectoryNode, debugPlatformBoundsNode, debugPlatformSweepNode, debugBallSweepNode, debugBallCollisionNode, debugRelativeSweepNode, debugBoundaryNode, debugCeilingLimitNode] {
            node.fillColor = .clear
            node.lineWidth = 1
            node.zPosition = 80
            addChild(node)
        }
        debugPlatformNode.strokeColor = .systemGreen
        debugCatchNode.strokeColor = .systemYellow
        debugFailureNode.strokeColor = .systemRed
        debugVelocityNode.strokeColor = .cyan
        debugTrajectoryNode.strokeColor = UIColor.systemTeal.withAlphaComponent(0.55)
        debugPlatformBoundsNode.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
        debugPlatformSweepNode.strokeColor = .systemPink
        debugBallSweepNode.strokeColor = UIColor.systemBlue.withAlphaComponent(0.9)
        debugBallCollisionNode.strokeColor = .systemPurple
        debugRelativeSweepNode.strokeColor = UIColor.magenta.withAlphaComponent(0.75)
        debugBoundaryNode.strokeColor = UIColor.white.withAlphaComponent(0.85)
        debugCeilingLimitNode.strokeColor = UIColor.systemCyan.withAlphaComponent(0.95)
        debugCeilingLimitNode.lineWidth = 2
    }

    private func syncPresentation() {
        platformNode.position = logic.platformCenter
        ballNode.position = logic.ballPosition
        scoreLabel.text = "\(logic.score)"
        syncTrail()
        syncDebugGeometry()
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
            node.position = sample.position
            node.setScale(scale)
            node.alpha = config.trailMaximumOpacity + (config.trailMinimumOpacity - config.trailMaximumOpacity) * progress
            node.isHidden = false
        }
    }

    private func handleEvents(at time: TimeInterval) {
        for event in logic.drainEvents() {
            switch event {
            case .bounced(let bounce):
                lastImpactOffset = bounce.normalizedImpactOffset
                lastContactNormal = bounce.contactNormal
                gameDelegate?.keepUpSceneDidBounce(self)
            case .failed:
                gameDelegate?.keepUpSceneDidFail(self)
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
        guard debugOptions.autoCatch else { return }
        if let missAtScore = debugOptions.intentionalMissAtScore, logic.score >= missAtScore {
            let destination = logic.ballPosition.x < size.width / 2 ? geometry.maximumPlatformX : geometry.minimumPlatformX
            logic.setPlatformPosition(CGPoint(x: destination, y: geometry.minimumPlatformY))
        } else {
            let targetX = logic.ballPosition.x - debugOptions.autoCatchOffset * geometry.effectiveCatchRadius
            let verticalTravel = geometry.sceneSize.height * 0.020
            let targetY = geometry.sceneSize.height * config.startingPlatformYRatio
                + CGFloat(sin(logic.elapsedTime * 0.8)) * verticalTravel
            logic.setPlatformPosition(CGPoint(x: targetX, y: targetY))
        }
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        for node in [debugPlatformNode, debugCatchNode, debugFailureNode, debugVelocityNode, debugTrajectoryNode, debugPlatformBoundsNode, debugPlatformSweepNode, debugBallSweepNode, debugBallCollisionNode, debugRelativeSweepNode, debugBoundaryNode, debugCeilingLimitNode] {
            node.isHidden = !debugOptions.showGeometry
        }
        syncTrail()
    }

    private func syncDebugGeometry() {
        guard debugOptions.showGeometry else { return }
        debugPlatformNode.path = CGPath(
            ellipseIn: CGRect(
                x: logic.platformX - geometry.platformRadius,
                y: logic.platformY - geometry.platformRadius,
                width: geometry.platformRadius * 2,
                height: geometry.platformRadius * 2
            ),
            transform: nil
        )
        let catchPath = CGMutablePath()
        catchPath.move(to: CGPoint(x: logic.platformX - geometry.effectiveCatchRadius, y: logic.platformY + geometry.platformRadius + geometry.ballRadius))
        catchPath.addLine(to: CGPoint(x: logic.platformX + geometry.effectiveCatchRadius, y: logic.platformY + geometry.platformRadius + geometry.ballRadius))
        debugCatchNode.path = catchPath

        debugPlatformBoundsNode.path = CGPath(rect: geometry.platformCenterBounds, transform: nil)
        let platformSweepPath = CGMutablePath()
        platformSweepPath.move(to: logic.lastPlatformSweepStart)
        platformSweepPath.addLine(to: logic.platformPosition)
        debugPlatformSweepNode.path = platformSweepPath
        let ballSweepPath = CGMutablePath()
        ballSweepPath.move(to: logic.previousBallPosition)
        ballSweepPath.addLine(to: logic.ballPosition)
        debugBallSweepNode.path = ballSweepPath
        debugBallCollisionNode.path = CGPath(
            ellipseIn: CGRect(
                x: logic.ballPosition.x - geometry.ballRadius,
                y: logic.ballPosition.y - geometry.ballRadius,
                width: geometry.ballRadius * 2,
                height: geometry.ballRadius * 2
            ),
            transform: nil
        )
        let relativeSweepPath = CGMutablePath()
        relativeSweepPath.move(to: logic.previousBallPosition)
        relativeSweepPath.addLine(to: CGPoint(
            x: logic.lastPlatformSweepStart.x + logic.ballPosition.x - logic.platformPosition.x,
            y: logic.lastPlatformSweepStart.y + logic.ballPosition.y - logic.platformPosition.y
        ))
        debugRelativeSweepNode.path = relativeSweepPath

        let boundaryPath = CGMutablePath()
        boundaryPath.move(to: CGPoint(x: geometry.minimumBallX, y: 0))
        boundaryPath.addLine(to: CGPoint(x: geometry.minimumBallX, y: size.height))
        boundaryPath.move(to: CGPoint(x: geometry.maximumBallX, y: 0))
        boundaryPath.addLine(to: CGPoint(x: geometry.maximumBallX, y: size.height))
        boundaryPath.move(to: CGPoint(x: geometry.upperLineHorizontalInset, y: geometry.ceilingY))
        boundaryPath.addLine(to: CGPoint(x: size.width - geometry.upperLineHorizontalInset, y: geometry.ceilingY))
        debugBoundaryNode.path = boundaryPath
        let ceilingLimitPath = CGMutablePath()
        ceilingLimitPath.move(to: CGPoint(x: geometry.upperLineHorizontalInset, y: geometry.maximumBallY))
        ceilingLimitPath.addLine(to: CGPoint(x: size.width - geometry.upperLineHorizontalInset, y: geometry.maximumBallY))
        debugCeilingLimitNode.path = ceilingLimitPath

        let failurePath = CGMutablePath()
        failurePath.move(to: CGPoint(x: 0, y: geometry.failureY))
        failurePath.addLine(to: CGPoint(x: size.width, y: geometry.failureY))
        debugFailureNode.path = failurePath

        let velocityScale: CGFloat = 0.08
        let velocityPath = CGMutablePath()
        velocityPath.move(to: logic.ballPosition)
        velocityPath.addLine(to: CGPoint(
            x: logic.ballPosition.x + logic.ballVelocity.dx * velocityScale,
            y: logic.ballPosition.y + logic.ballVelocity.dy * velocityScale
        ))
        debugVelocityNode.path = velocityPath
        debugTrajectoryNode.path = predictedTrajectoryPath()
    }

    private func predictedTrajectoryPath() -> CGPath {
        let path = CGMutablePath()
        var position = logic.ballPosition
        var velocity = logic.ballVelocity
        path.move(to: position)
        for _ in 0..<45 {
            let horizontal = KeepUpPhysics.horizontalStep(
                position: position.x,
                velocity: velocity.dx,
                deltaTime: 0.05,
                lowerBound: geometry.minimumBallX,
                upperBound: geometry.maximumBallX,
                reflects: config.reflectsAtSideWalls
            )
            let vertical = KeepUpPhysics.verticalStep(
                position: position.y,
                velocity: velocity.dy,
                gravity: logic.gravity,
                deltaTime: 0.05,
                upperBound: config.reflectsAtCeiling ? geometry.maximumBallY : nil,
                restitution: config.ceilingRestitution
            )
            position = CGPoint(x: horizontal.position, y: vertical.position)
            velocity = CGVector(dx: horizontal.velocity, dy: vertical.velocity)
            path.addLine(to: position)
            if position.y < geometry.failureY { break }
        }
        return path
    }

    private func updateDebugOverlay() {
        guard debugOptions.showOverlay else { return }
        let expectedLandingX = predictedLandingX()
        let relativeVelocity = CGVector(
            dx: logic.ballVelocity.dx - logic.platformVelocity.dx,
            dy: logic.ballVelocity.dy - logic.platformVelocity.dy
        )
        let centerDistance = hypot(
            logic.ballPosition.x - logic.platformPosition.x,
            logic.ballPosition.y - logic.platformPosition.y
        )
        debugLabel.text = [
            "FPS: \(Int(measuredFPS.rounded()))",
            "Score: \(logic.score)",
            String(format: "Ball X/Y: %.1f, %.1f", logic.ballPosition.x, logic.ballPosition.y),
            String(format: "Ball VX/VY: %.1f, %.1f", logic.ballVelocity.dx, logic.ballVelocity.dy),
            String(format: "Platform X/Y: %.1f, %.1f", logic.platformX, logic.platformY),
            String(format: "Platform VX/VY: %.1f, %.1f", logic.platformVelocity.dx, logic.platformVelocity.dy),
            String(format: "Relative VX/VY: %.1f, %.1f", relativeVelocity.dx, relativeVelocity.dy),
            String(format: "Center distance: %.1f", centerDistance),
            String(format: "Last catch offset: %.3f", lastImpactOffset),
            String(format: "Contact normal: %.3f, %.3f", lastContactNormal.dx, lastContactNormal.dy),
            String(format: "Catch radius: %.1f", geometry.effectiveCatchRadius),
            String(format: "Ceiling Y: %.1f", geometry.ceilingY),
            String(format: "Ball top Y: %.1f", logic.ballTopY),
            String(format: "Distance to ceiling: %.1f", logic.distanceToCeiling),
            String(format: "Ball center max Y: %.1f", geometry.maximumBallY),
            String(format: "Incoming ceiling VY: %.1f", logic.lastCeilingIncomingVY),
            String(format: "Outgoing ceiling VY: %.1f", logic.lastCeilingOutgoingVY),
            String(format: "Ceiling restitution: %.3f", config.ceilingRestitution),
            "Ceiling contacts: \(logic.ceilingContactCount)",
            String(format: "Time since platform bounce: %.3f s", logic.timeSinceLastPlatformBounce),
            String(format: "Time platform→ceiling: %.3f s", logic.lastPlatformToCeilingTime),
            String(format: "Time ceiling→platform: %.3f s", logic.lastCeilingToPlatformTime),
            String(format: "Expected landing X: %.1f", expectedLandingX),
            "Trail samples: \(logic.trailSamples.count) / \(logic.trailCapacity)",
            String(format: "Game time: %.2f s", logic.elapsedTime),
        ].joined(separator: "\n")
    }

    private func predictedLandingX() -> CGFloat {
        var position = logic.ballPosition
        var velocity = logic.ballVelocity
        let targetY = logic.platformY + geometry.platformRadius + geometry.ballRadius
        for _ in 0..<600 {
            let oldY = position.y
            let horizontal = KeepUpPhysics.horizontalStep(
                position: position.x,
                velocity: velocity.dx,
                deltaTime: 1.0 / 120.0,
                lowerBound: geometry.minimumBallX,
                upperBound: geometry.maximumBallX,
                reflects: config.reflectsAtSideWalls
            )
            let vertical = KeepUpPhysics.verticalStep(
                position: position.y,
                velocity: velocity.dy,
                gravity: logic.gravity,
                deltaTime: 1.0 / 120.0,
                upperBound: config.reflectsAtCeiling ? geometry.maximumBallY : nil,
                restitution: config.ceilingRestitution
            )
            position = CGPoint(x: horizontal.position, y: vertical.position)
            velocity = CGVector(dx: horizontal.velocity, dy: vertical.velocity)
            if velocity.dy < 0, oldY >= targetY, position.y <= targetY { return position.x }
        }
        return position.x
    }
}

enum KeepUpDiscShading {
    static func texture(
        diameter: CGFloat,
        inner: UIColor,
        outer: UIColor,
        highlight: UIColor,
        highlightOffset: CGVector
    ) -> SKTexture {
        let size = max(16, ceil(diameter))
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { renderer in
            let bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let center = CGPoint(x: size / 2, y: size / 2)
            renderer.cgContext.addEllipse(in: bounds)
            renderer.cgContext.clip()

            let space = CGColorSpaceCreateDeviceRGB()
            var bodyLocations: [CGFloat] = [0, 1]
            if let body = CGGradient(colorsSpace: space, colors: [inner.cgColor, outer.cgColor] as CFArray, locations: &bodyLocations) {
                renderer.cgContext.drawRadialGradient(
                    body,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size / 2,
                    options: [.drawsAfterEndLocation]
                )
            }
            var highlightLocations: [CGFloat] = [0, 1]
            if let shine = CGGradient(
                colorsSpace: space,
                colors: [highlight.cgColor, highlight.withAlphaComponent(0).cgColor] as CFArray,
                locations: &highlightLocations
            ) {
                let shineCenter = CGPoint(
                    x: center.x + highlightOffset.dx * size,
                    y: center.y + highlightOffset.dy * size
                )
                renderer.cgContext.drawRadialGradient(
                    shine,
                    startCenter: shineCenter,
                    startRadius: 0,
                    endCenter: shineCenter,
                    endRadius: size * 0.42,
                    options: []
                )
            }
        }
        return SKTexture(image: image)
    }
}
