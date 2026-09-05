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
    private let facingMarker = SKShapeNode()
    private let playerShadow = SKShapeNode()
    private let collisionEffectNode = SKNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var rowNodes: [Int: SKShapeNode] = [:]
    private var gridNodes: [Int: SKNode] = [:]
    private var vehicleNodes: [String: SKNode] = [:]
    private var activeTouch: UITouch?
    private var touchStart: CGPoint?
    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var autoAdvanceCooldown: TimeInterval = 0
    private var controlQAIndex = 0

    private var rowHeight: CGFloat { size.height * config.rowHeightRatio }
    private var playerSize: CGSize { CGSize(width: size.width * config.playerWidthRatio, height: rowHeight * config.playerHeightInRows) }

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
            autoAdvanceCooldown = max(0, autoAdvanceCooldown - delta)
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
            handleEvents(at: currentTime)
        }
        previousFrameTime = currentTime
        syncPresentation()

        if logic.isFinished, let finishReportTime, currentTime >= finishReportTime, !didReportFinish {
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
        let end = touch.location(in: self)
        activeTouch = nil
        touchStart = nil
        _ = logic.requestMove(JumpyGestureInterpreter.move(from: start, to: end, threshold: config.gestureThreshold))
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
        finishReportTime = nil
        didReportFinish = false
        activeTouch = nil
        touchStart = nil
        autoAdvanceCooldown = 0
        controlQAIndex = 0
        collisionEffectNode.removeAllChildren()
        playerNode.removeAllActions()
        playerNode.setScale(1)
        playerBody.fillColor = config.playerColor
        logic.difficultyScoreOverride = debugOptions.forcedDifficultyScore
        logic.collisionDetectionEnabled = !debugOptions.disableCollisions
        logic.reset()
        syncPresentation()
    }

    private func setupNodes() {
        worldLayer.zPosition = 0
        vehicleLayer.zPosition = 2
        hitboxLayer.zPosition = 30
        hitboxLayer.isHidden = !debugOptions.showHitboxes
        addChild(worldLayer)
        addChild(vehicleLayer)
        addChild(hitboxLayer)

        scoreLabel.fontSize = max(48, size.width * 0.15)
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.79)
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 20
        addChild(scoreLabel)

        let shadowRect = CGRect(x: -playerSize.width * 0.42, y: -rowHeight * 0.10, width: playerSize.width * 0.84, height: rowHeight * 0.20)
        playerShadow.path = CGPath(ellipseIn: shadowRect, transform: nil)
        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.28)
        playerShadow.strokeColor = .clear
        playerShadow.zPosition = 4
        addChild(playerShadow)

        let bodyRect = CGRect(x: -playerSize.width / 2, y: -playerSize.height / 2, width: playerSize.width, height: playerSize.height)
        playerBody.path = CGPath(roundedRect: bodyRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        playerBody.fillColor = config.playerColor
        playerBody.strokeColor = UIColor.white.withAlphaComponent(0.28)
        playerBody.lineWidth = 1.5
        playerNode.addChild(playerBody)
        facingMarker.path = CGPath(roundedRect: CGRect(x: -playerSize.width * 0.20, y: playerSize.height * 0.12, width: playerSize.width * 0.40, height: playerSize.height * 0.13), cornerWidth: 2, cornerHeight: 2, transform: nil)
        facingMarker.fillColor = UIColor.white.withAlphaComponent(0.78)
        facingMarker.strokeColor = .clear
        playerNode.addChild(facingMarker)
        playerNode.zPosition = 6
        addChild(playerNode)
        collisionEffectNode.zPosition = 7
        addChild(collisionEffectNode)

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

    private func screenPoint(_ world: CGPoint) -> CGPoint {
        CGPoint(
            x: world.x * size.width,
            y: size.height * config.cameraAnchorYRatio + (world.y - logic.cameraProgress) * rowHeight
        )
    }

    private func syncPresentation() {
        scoreLabel.text = "\(logic.score)"
        syncRows()
        syncVehicles()

        let ground = screenPoint(logic.playerWorldPoint)
        let lift = sin(.pi * logic.hopProgress) * rowHeight * 0.42
        playerShadow.position = ground
        playerShadow.setScale(1 - logic.hopProgress * (1 - logic.hopProgress) * 0.55)
        playerShadow.alpha = 0.28 - logic.hopProgress * (1 - logic.hopProgress) * 0.35
        playerNode.position = CGPoint(x: ground.x, y: ground.y + lift)
        playerNode.zRotation = switch logic.facing {
        case .up: 0
        case .down: .pi
        case .left: .pi / 2
        case .right: -.pi / 2
        }

        debugLabel.text = "score \(logic.score)  row \(logic.playerPosition.row) col \(logic.playerPosition.column)\ncamera \(String(format: "%.1f", logic.cameraProgress)) min \(logic.minimumRetreatRow)\njumps \(logic.totalJumps) F\(logic.forwardJumps) S\(logic.sidewaysJumps) B\(logic.backwardJumps)"
        syncHitboxes()
    }

    private func syncRows() {
        let live = Set(logic.rows.keys)
        for key in rowNodes.keys where !live.contains(key) {
            rowNodes.removeValue(forKey: key)?.removeFromParent()
            gridNodes.removeValue(forKey: key)?.removeFromParent()
        }
        for row in logic.rows.values {
            let node = rowNodes[row.worldRow] ?? SKShapeNode()
            node.path = CGPath(rect: CGRect(x: 0, y: -rowHeight / 2, width: size.width, height: rowHeight - 1), transform: nil)
            switch row.kind {
            case .safe:
                node.fillColor = row.worldRow.isMultiple(of: 2) ? config.safeColor : config.safeAlternateColor
            case .road:
                node.fillColor = row.worldRow.isMultiple(of: 2) ? config.roadColor : config.roadAlternateColor
            }
            node.strokeColor = .clear
            node.position = screenPoint(CGPoint(x: 0, y: CGFloat(row.worldRow)))
            if rowNodes[row.worldRow] == nil {
                worldLayer.addChild(node)
                rowNodes[row.worldRow] = node
                let grid = makeGrid(for: row)
                worldLayer.addChild(grid)
                gridNodes[row.worldRow] = grid
            }
            gridNodes[row.worldRow]?.position.y = node.position.y
        }
    }

    private func makeGrid(for row: JumpyWorldRow) -> SKNode {
        let container = SKNode()
        let path = CGMutablePath()
        switch row.kind {
        case .safe:
            for column in 1..<config.columnCount {
                let x = size.width * CGFloat(column) / CGFloat(config.columnCount)
                path.move(to: CGPoint(x: x, y: -rowHeight / 2))
                path.addLine(to: CGPoint(x: x, y: rowHeight / 2))
            }
        case .road:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = UIColor.white.withAlphaComponent(0.09)
        shape.lineWidth = 1
        container.addChild(shape)
        return container
    }

    private func syncVehicles() {
        var live = Set<String>()
        let colors: [UIColor] = [.systemCyan, .systemYellow, .systemOrange, .systemRed, .systemPink, .systemBlue, .systemGreen, .white]
        for row in logic.rows.values {
            guard case .road(let lane) = row.kind else { continue }
            for (index, center) in lane.vehicleCenters(margin: config.trafficMargin).enumerated() {
                let key = "\(lane.id)-\(index)"
                live.insert(key)
                let node = vehicleNodes[key] ?? makeVehicle(width: lane.vehicleWidth * size.width, height: rowHeight * config.vehicleHeightInRows, color: colors[(lane.id + index) % colors.count])
                node.position = screenPoint(CGPoint(x: center, y: CGFloat(lane.worldRow)))
                node.xScale = lane.direction == .right ? 1 : -1
                if vehicleNodes[key] == nil {
                    vehicleLayer.addChild(node)
                    vehicleNodes[key] = node
                }
            }
        }
        for key in vehicleNodes.keys where !live.contains(key) {
            vehicleNodes.removeValue(forKey: key)?.removeFromParent()
        }
    }

    private func makeVehicle(width: CGFloat, height: CGFloat, color: UIColor) -> SKNode {
        let node = SKNode()
        let shadow = SKShapeNode(rectOf: CGSize(width: width, height: height * 0.8), cornerRadius: 5)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position.y = -3
        node.addChild(shadow)
        let body = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 5)
        body.fillColor = color
        body.strokeColor = UIColor.white.withAlphaComponent(0.22)
        body.lineWidth = 1
        node.addChild(body)
        let glass = SKShapeNode(rectOf: CGSize(width: width * 0.34, height: height * 0.68), cornerRadius: 2)
        glass.fillColor = UIColor(red: 0.03, green: 0.16, blue: 0.20, alpha: 0.72)
        glass.strokeColor = .clear
        glass.position.x = width * 0.12
        node.addChild(glass)
        return node
    }

    private func syncHitboxes() {
        hitboxLayer.removeAllChildren()
        guard debugOptions.showHitboxes else { return }
        let p = screenPoint(logic.playerWorldPoint)
        let player = SKShapeNode(rectOf: CGSize(width: size.width * config.playerWidthRatio * config.playerHitboxScale, height: rowHeight * config.playerHeightInRows * config.playerHitboxScale))
        player.position = p
        player.fillColor = .clear
        player.strokeColor = .white
        hitboxLayer.addChild(player)
    }

    private func handleEvents(at time: TimeInterval) {
        for event in logic.drainEvents() {
            switch event {
            case .hopped:
                gameDelegate?.jumpySceneDidHop(self)
            case .collided:
                gameDelegate?.jumpySceneDidCollide(self)
                finishReportTime = debugOptions.holdCollision ? nil : time + config.resultHoldDuration
                playerBody.fillColor = .systemRed
                playerNode.run(.sequence([.scale(to: 1.20, duration: 0.05), .scale(to: 0.75, duration: 0.10)]))
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
            shard.run(.group([
                .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.18),
                .fadeOut(withDuration: 0.30),
                .rotate(byAngle: .pi, duration: 0.18),
            ]))
        }
    }

    private static let controlQAMoves: [JumpyMove] = [.left, .up, .right, .up, .down, .up, .up]
}
