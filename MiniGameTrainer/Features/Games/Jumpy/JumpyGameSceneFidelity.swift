import SpriteKit
import UIKit

@MainActor
protocol JumpyGameSceneDelegate: AnyObject {
    func jumpySceneDidHop(_ scene: JumpyGameScene)
    func jumpySceneDidCollide(_ scene: JumpyGameScene)
    func jumpyScene(_ scene: JumpyGameScene, didEndWith summary: JumpySessionSummary)
}

@MainActor
final class JumpyGameScene: SKScene {
    let config: JumpyGameConfig
    let logic: JumpyGameLogic
    weak var gameDelegate: JumpyGameSceneDelegate?

    var debugOptions: JumpyDebugOptions {
        didSet {
            logic.difficultyScoreOverride = debugOptions.forcedDifficultyScore
            logic.collisionDetectionEnabled = !debugOptions.disableCollisions
            debugLabel.isHidden = !debugOptions.showOverlay
            hitboxLayer.isHidden = !debugOptions.showHitboxes
        }
    }

    private let worldLayer = SKNode()
    private let vehicleLayer = SKNode()
    private let hitboxLayer = SKNode()
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let playerNode = SKNode()
    private let playerBody = SKShapeNode()
    private let playerTop = SKShapeNode()
    private let facingMarker = SKShapeNode()
    private let playerShadow = SKShapeNode()
    private let collisionEffectNode = SKNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var rowNodes: [Int: SKNode] = [:]
    private var vehicleNodes: [String: SKNode] = [:]
    private var activeTouch: UITouch?
    private var touchStart: CGPoint?
    private var previousFrameTime: TimeInterval?
    private var finishDelayRemaining: TimeInterval?
    private var didReportFinish = false
    private var autoAdvanceCooldown: TimeInterval = 0
    private var controlQAIndex = 0
    private var visualCameraProgress: CGFloat = 0
    private var smoothedFramesPerSecond: CGFloat = 60

    var visualCameraProgressForTesting: CGFloat { visualCameraProgress }

    private var baseRowHeight: CGFloat { size.height * config.rowHeightRatio }
    private var playerSize: CGSize {
        CGSize(width: size.width * config.playerWidthRatio, height: baseRowHeight * config.playerHeightInRows)
    }
    private var projection: JumpyWorldProjection {
        JumpyWorldProjection(size: size, config: config, cameraProgress: visualCameraProgress)
    }

    init(size: CGSize, config: JumpyGameConfig, debugOptions: JumpyDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = JumpyGameLogic(config: config)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        startSession()
    }

    override func update(_ currentTime: TimeInterval) {
        if let previousFrameTime {
            let delta = min(max(currentTime - previousFrameTime, 0), config.maximumFrameDelta)
            if delta > 1e-5 {
                smoothedFramesPerSecond = smoothedFramesPerSecond * 0.92 + CGFloat(1 / delta) * 0.08
            }
            autoAdvanceCooldown = max(0, autoAdvanceCooldown - delta)
            if let remaining = finishDelayRemaining {
                finishDelayRemaining = max(0, remaining - delta)
            }
            #if DEBUG
            if logic.acceptsInput, autoAdvanceCooldown == 0,
               debugOptions.autoAdvance || (debugOptions.controlQAScript && controlQAIndex < Self.controlQAMoves.count) {
                let move = debugOptions.controlQAScript ? Self.controlQAMoves[controlQAIndex] : .up
                if debugOptions.controlQAScript { controlQAIndex += 1 }
                _ = logic.requestMove(move)
                autoAdvanceCooldown = config.hopDuration + 0.05
            }
            #endif
            logic.update(deltaTime: delta)
            updateVisualCamera(deltaTime: delta)
            handleEvents()
        }
        previousFrameTime = currentTime
        syncPresentation()

        if logic.isFinished, finishDelayRemaining == 0, !didReportFinish {
            didReportFinish = true
            gameDelegate?.jumpyScene(self, didEndWith: logic.makeSummary())
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard logic.acceptsInput, activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        touchStart = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let start = touchStart else { return }
        activeTouch = nil
        touchStart = nil
        _ = logic.requestMove(JumpyGestureInterpreter.move(from: start, to: touch.location(in: self), threshold: config.gestureThreshold))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        touchStart = nil
    }

    func pauseGame() {
        logic.pause()
        activeTouch = nil
        touchStart = nil
        previousFrameTime = nil
    }

    func resumeGame() {
        logic.resume()
        previousFrameTime = nil
    }

    func startSession() {
        previousFrameTime = nil
        finishDelayRemaining = nil
        didReportFinish = false
        activeTouch = nil
        touchStart = nil
        autoAdvanceCooldown = 0
        controlQAIndex = 0
        visualCameraProgress = 0
        smoothedFramesPerSecond = 60
        collisionEffectNode.removeAllChildren()
        playerNode.removeAllActions()
        playerBody.fillColor = config.playerColor
        playerTop.fillColor = config.playerColor
        logic.difficultyScoreOverride = debugOptions.forcedDifficultyScore
        logic.collisionDetectionEnabled = !debugOptions.disableCollisions
        logic.reset()
        syncPresentation()
    }

    private func setupNodes() {
        worldLayer.zPosition = 0
        vehicleLayer.zPosition = 3
        hitboxLayer.zPosition = 30
        hitboxLayer.isHidden = !debugOptions.showHitboxes
        addChild(worldLayer)
        addChild(vehicleLayer)
        addChild(hitboxLayer)

        scoreLabel.fontSize = max(56, size.width * 0.18)
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 20
        addChild(scoreLabel)
        configurePlayer()

        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = 10
        debugLabel.fontColor = .white
        debugLabel.position = CGPoint(x: 10, y: size.height - 54)
        debugLabel.zPosition = 50
        debugLabel.isHidden = !debugOptions.showOverlay
        debugLabel.numberOfLines = 0
        addChild(debugLabel)
    }

    private func configurePlayer() {
        let width = playerSize.width
        let height = playerSize.height
        playerShadow.path = CGPath(ellipseIn: CGRect(x: -width * 0.55, y: -height * 0.24, width: width * 1.10, height: height * 0.48), transform: nil)
        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.24)
        playerShadow.strokeColor = .clear
        playerShadow.zPosition = 4
        addChild(playerShadow)

        let depth = SKShapeNode(rectOf: CGSize(width: width * 0.88, height: height * 0.25), cornerRadius: 3)
        depth.fillColor = UIColor(red: 0.19, green: 0.62, blue: 0.12, alpha: 1)
        depth.strokeColor = .clear
        depth.position = CGPoint(x: width * 0.06, y: -height * 0.34)
        depth.zPosition = 0
        playerNode.addChild(depth)

        playerBody.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height * 0.42, width: width, height: height * 0.72), cornerWidth: 4, cornerHeight: 4, transform: nil)
        playerBody.fillColor = config.playerColor
        playerBody.strokeColor = .clear
        playerBody.zPosition = 1
        playerNode.addChild(playerBody)

        playerTop.path = CGPath(roundedRect: CGRect(x: -width * 0.39, y: -height * 0.02, width: width * 0.78, height: height * 0.58), cornerWidth: 4, cornerHeight: 4, transform: nil)
        playerTop.fillColor = config.playerColor
        playerTop.strokeColor = UIColor.white.withAlphaComponent(0.16)
        playerTop.lineWidth = 1
        playerTop.zPosition = 2
        playerNode.addChild(playerTop)

        facingMarker.path = CGPath(roundedRect: CGRect(x: -width * 0.19, y: -height * 0.035, width: width * 0.38, height: height * 0.10), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
        facingMarker.fillColor = .white
        facingMarker.strokeColor = .clear
        facingMarker.zPosition = 3
        playerNode.addChild(facingMarker)
        playerNode.zPosition = 6
        addChild(playerNode)
        collisionEffectNode.zPosition = 7
        addChild(collisionEffectNode)
    }

    private func updateVisualCamera(deltaTime: TimeInterval) {
        guard !logic.isFinished else { return }
        var target = logic.cameraProgress
        if let hop = logic.hop, hop.move == .up { target = max(target, logic.playerWorldPoint.y) }
        let response = CGFloat(1 - exp(-18 * deltaTime))
        visualCameraProgress = max(visualCameraProgress, visualCameraProgress + (target - visualCameraProgress) * response)
    }

    private func syncPresentation() {
        scoreLabel.text = "\(logic.score)"
        syncRows()
        syncVehicles()
        let worldPoint = logic.impactPosition ?? logic.playerWorldPoint
        let projected = projection.project(worldPoint)
        let lift = sin(.pi * logic.hopProgress) * projected.rowPitch * 0.55
        playerShadow.position = projected.point
        playerShadow.setScale(projected.depthScale)
        playerShadow.alpha = 0.24 - logic.hopProgress * (1 - logic.hopProgress) * 0.40
        playerNode.position = CGPoint(x: projected.point.x, y: projected.point.y + lift)
        playerNode.setScale(projected.depthScale)
        updateFacingMarker()
        debugLabel.text = "score \(logic.score) row \(logic.playerPosition.row) col \(logic.playerPosition.column)\ncamera \(String(format: "%.2f", visualCameraProgress)) min \(logic.minimumRetreatRow)\njumps \(logic.totalJumps) F\(logic.forwardJumps) S\(logic.sidewaysJumps) B\(logic.backwardJumps)\nvehicles \(vehicleNodes.count) rows \(rowNodes.count)\nfps \(Int(smoothedFramesPerSecond.rounded()))"
        syncHitboxes()
    }

    private func updateFacingMarker() {
        let width = playerSize.width
        let height = playerSize.height
        facingMarker.zRotation = (logic.facing == .left || logic.facing == .right) ? .pi / 2 : 0
        switch logic.facing {
        case .up: facingMarker.position = CGPoint(x: 0, y: height * 0.43)
        case .down: facingMarker.position = CGPoint(x: 0, y: -height * 0.26)
        case .left: facingMarker.position = CGPoint(x: -width * 0.34, y: height * 0.08)
        case .right: facingMarker.position = CGPoint(x: width * 0.34, y: height * 0.08)
        }
    }

    private func syncRows() {
        let live = Set(logic.rows.keys)
        for key in rowNodes.keys where !live.contains(key) { rowNodes.removeValue(forKey: key)?.removeFromParent() }
        for row in logic.rows.values {
            let node = rowNodes[row.worldRow] ?? makeRow(for: row)
            let projected = projection.project(CGPoint(x: 0.5, y: CGFloat(row.worldRow)))
            node.position = projected.point
            node.xScale = projected.horizontalScale
            node.yScale = projected.rowPitch / baseRowHeight * 1.025
            node.isHidden = projected.point.y < -projected.rowPitch * 2 || projected.point.y > size.height + projected.rowPitch * 2
            if rowNodes[row.worldRow] == nil { worldLayer.addChild(node); rowNodes[row.worldRow] = node }
        }
    }

    private func makeRow(for row: JumpyWorldRow) -> SKNode {
        let container = SKNode()
        let background = SKShapeNode(rectOf: CGSize(width: size.width, height: baseRowHeight * 1.04))
        background.strokeColor = .clear
        background.fillColor = row.isSafe ? config.safeColor : config.roadColor
        container.addChild(background)
        guard row.isSafe else { return container }
        let depth = SKShapeNode(rectOf: CGSize(width: size.width, height: baseRowHeight * 0.16))
        depth.fillColor = config.safeDepthColor
        depth.strokeColor = .clear
        depth.position.y = -baseRowHeight * 0.48
        depth.zPosition = 1
        container.addChild(depth)
        for column in 1..<config.columnCount {
            let x = -size.width / 2 + size.width * CGFloat(column) / CGFloat(config.columnCount)
            let divider = SKShapeNode(rectOf: CGSize(width: 1.5, height: baseRowHeight * 0.88))
            divider.fillColor = UIColor(red: 0.05, green: 0.42, blue: 0.47, alpha: 0.28)
            divider.strokeColor = .clear
            divider.position = CGPoint(x: x, y: baseRowHeight * 0.03)
            divider.zPosition = 2
            container.addChild(divider)
        }
        return container
    }

    private func syncVehicles() {
        var live = Set<String>()
        let colors: [UIColor] = [.systemCyan, .systemYellow, .systemOrange, .systemRed, .systemPink, .systemBlue, .systemGreen, .white, UIColor(white: 0.18, alpha: 1)]
        for row in logic.rows.values {
            guard case .road(let lane) = row.kind else { continue }
            for (index, center) in lane.vehicleCenters(margin: config.trafficMargin).enumerated() {
                let key = "\(lane.id)-\(index)"
                live.insert(key)
                let node = vehicleNodes[key] ?? makeVehicle(width: lane.vehicleWidth * size.width, height: baseRowHeight * config.vehicleHeightInRows, color: colors[(lane.id + index) % colors.count])
                let projected = projection.project(CGPoint(x: center, y: CGFloat(lane.worldRow)))
                node.position = projected.point
                node.xScale = (lane.direction == .right ? 1 : -1) * projected.depthScale
                node.yScale = projected.depthScale
                node.isHidden = projected.point.y < -projected.rowPitch * 2 || projected.point.y > size.height + projected.rowPitch * 2
                if vehicleNodes[key] == nil { vehicleLayer.addChild(node); vehicleNodes[key] = node }
            }
        }
        for key in vehicleNodes.keys where !live.contains(key) { vehicleNodes.removeValue(forKey: key)?.removeFromParent() }
    }

    private func makeVehicle(width: CGFloat, height: CGFloat, color: UIColor) -> SKNode {
        let node = SKNode()
        addShape(to: node, ellipse: CGSize(width: width * 1.10, height: height * 0.62), color: UIColor.black.withAlphaComponent(0.20), position: CGPoint(x: -width * 0.04, y: -height * 0.34), z: 0)
        addShape(to: node, rect: CGSize(width: width * 0.94, height: height * 0.72), radius: 4, color: color.jumpyMixed(with: .black, fraction: 0.34), position: CGPoint(x: -width * 0.015, y: -height * 0.12), z: 1)
        addShape(to: node, rect: CGSize(width: width, height: height * 0.72), radius: 5, color: color, position: CGPoint(x: 0, y: height * 0.02), z: 2)
        for x in [-width * 0.30, width * 0.30] {
            for y in [-height * 0.37, height * 0.37] {
                addShape(to: node, rect: CGSize(width: width * 0.16, height: height * 0.20), radius: 2, color: UIColor(red: 0.06, green: 0.08, blue: 0.10, alpha: 1), position: CGPoint(x: x, y: y), z: 3)
            }
        }
        addShape(to: node, rect: CGSize(width: width * 0.44, height: height * 0.70), radius: 4, color: color.jumpyMixed(with: .white, fraction: 0.10), position: CGPoint(x: width * 0.04, y: height * 0.16), z: 4)
        let glass = UIColor(red: 0.025, green: 0.08, blue: 0.11, alpha: 0.92)
        addShape(to: node, rect: CGSize(width: width * 0.12, height: height * 0.52), radius: 1.5, color: glass, position: CGPoint(x: width * 0.20, y: height * 0.17), z: 5)
        addShape(to: node, rect: CGSize(width: width * 0.09, height: height * 0.48), radius: 1.5, color: glass, position: CGPoint(x: -width * 0.13, y: height * 0.17), z: 5)
        return node
    }

    private func addShape(to node: SKNode, rect: CGSize, radius: CGFloat, color: UIColor, position: CGPoint, z: CGFloat) {
        let shape = SKShapeNode(rectOf: rect, cornerRadius: radius)
        shape.fillColor = color; shape.strokeColor = .clear; shape.position = position; shape.zPosition = z
        node.addChild(shape)
    }

    private func addShape(to node: SKNode, ellipse: CGSize, color: UIColor, position: CGPoint, z: CGFloat) {
        let shape = SKShapeNode(ellipseOf: ellipse)
        shape.fillColor = color; shape.strokeColor = .clear; shape.position = position; shape.zPosition = z
        node.addChild(shape)
    }

    private func syncHitboxes() {
        hitboxLayer.removeAllChildren()
        guard debugOptions.showHitboxes else { return }
        let playerWorld = logic.impactPosition ?? logic.playerWorldPoint
        let playerProjected = projection.project(playerWorld)
        addHitbox(at: playerProjected.point, size: CGSize(width: size.width * config.playerWidthRatio * config.playerHitboxScale * playerProjected.depthScale, height: playerProjected.rowPitch * config.playerHeightInRows * config.playerHitboxScale), color: .white)
        for row in logic.rows.values {
            guard case .road(let lane) = row.kind else { continue }
            for center in lane.vehicleCenters(margin: config.trafficMargin) {
                let projected = projection.project(CGPoint(x: center, y: CGFloat(lane.worldRow)))
                addHitbox(at: projected.point, size: CGSize(width: lane.vehicleWidth * size.width * config.vehicleHitboxScale * projected.depthScale, height: projected.rowPitch * config.vehicleHeightInRows * config.vehicleHitboxScale), color: .systemRed)
            }
        }
    }

    private func addHitbox(at point: CGPoint, size: CGSize, color: UIColor) {
        let node = SKShapeNode(rectOf: size)
        node.position = point; node.fillColor = .clear; node.strokeColor = color
        hitboxLayer.addChild(node)
    }

    private func handleEvents() {
        for event in logic.drainEvents() {
            switch event {
            case .hopped: gameDelegate?.jumpySceneDidHop(self)
            case .collided:
                gameDelegate?.jumpySceneDidCollide(self)
                finishDelayRemaining = debugOptions.holdCollision ? nil : config.resultHoldDuration
                playerBody.fillColor = .systemRed
                playerTop.fillColor = .systemRed
                addCollisionBurst()
            }
        }
    }

    private func addCollisionBurst() {
        collisionEffectNode.removeAllChildren()
        collisionEffectNode.position = playerNode.position
        for index in 0..<8 {
            let shard = SKShapeNode(rectOf: CGSize(width: 7, height: 7), cornerRadius: 1)
            shard.fillColor = index.isMultiple(of: 2) ? .systemRed : .white
            shard.strokeColor = .clear
            let angle = CGFloat(index) * .pi / 4
            let distance = playerSize.width * 0.85
            collisionEffectNode.addChild(shard)
            shard.run(.group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.18), .fadeOut(withDuration: 0.30), .rotate(byAngle: .pi, duration: 0.18)]))
        }
    }

    private static let controlQAMoves: [JumpyMove] = [.left, .up, .right, .up, .down, .up, .up]
}

private extension JumpyWorldRow {
    var isSafe: Bool {
        if case .safe = kind { return true }
        return false
    }
}

private extension UIColor {
    func jumpyMixed(with other: UIColor, fraction: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              other.getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha) else { return self }
        let amount = min(1, max(0, fraction))
        return UIColor(
            red: red + (otherRed - red) * amount,
            green: green + (otherGreen - green) * amount,
            blue: blue + (otherBlue - blue) * amount,
            alpha: alpha + (otherAlpha - alpha) * amount
        )
    }
}
