import SpriteKit
import UIKit

@MainActor
protocol ZigGameSceneDelegate: AnyObject {
    func zigSceneDidTurn(_ scene: ZigGameScene)
    func zigSceneDidFall(_ scene: ZigGameScene)
    func zigScene(_ scene: ZigGameScene, didEndWith summary: ZigSessionSummary)
}

@MainActor
final class ZigGameScene: SKScene {
    let logic: ZigGameLogic
    let config: ZigGameConfig
    weak var gameDelegate: ZigGameSceneDelegate?
    var debugOptions: ZigDebugOptions { didSet { debugLabel.isHidden = !debugOptions.showOverlay } }

    private let worldLayer = SKNode()
    private let ballNode: SKShapeNode
    private let highlightNode: SKShapeNode
    private let shadowNode: SKShapeNode
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var renderedCells: Set<ZigCell> = []
    private var previousFrameTime: TimeInterval?
    private var didReportFinish = false
    private var cameraLateral: CGFloat = 0

    init(size: CGSize, config: ZigGameConfig, debugOptions: ZigDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = ZigGameLogic(config: config)
        let radius = size.width * config.ballRadiusRatio
        ballNode = SKShapeNode(circleOfRadius: radius)
        highlightNode = SKShapeNode(circleOfRadius: radius * 0.25)
        shadowNode = SKShapeNode(ellipseOf: CGSize(width: radius * 2.1, height: radius * 0.75))
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func update(_ currentTime: TimeInterval) {
        if let previousFrameTime {
            let delta = min(max(0, currentTime - previousFrameTime), config.maximumFrameDelta)
            if debugOptions.autoPlay { _ = logic.performPerfectTurnIfNeeded() }
            if !(debugOptions.holdFailure && logic.state == .falling) {
                logic.update(deltaTime: delta)
            }
            handleEvents()
            updateCamera(deltaTime: delta)
        }
        previousFrameTime = currentTime
        syncPresentation()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for _ in touches where logic.toggleDirection() { gameDelegate?.zigSceneDidTurn(self) }
    }

    func pauseGame() { logic.pause(); previousFrameTime = nil }
    func resumeGame() { logic.resume(); previousFrameTime = nil }

    func startSession() {
        previousFrameTime = nil
        didReportFinish = false
        cameraLateral = 0
        logic.reset()
        renderedCells.removeAll()
        syncPresentation()
    }

    private func setupNodes() {
        backgroundColor = config.backgroundBottomColor
        let background = SKSpriteNode(texture: gradientTexture())
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
        background.zPosition = -10_000
        addChild(background)
        worldLayer.zPosition = 0
        addChild(worldLayer)

        shadowNode.fillColor = UIColor.black.withAlphaComponent(0.28)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = 900
        addChild(shadowNode)
        ballNode.fillColor = config.ballColor
        ballNode.strokeColor = UIColor.white.withAlphaComponent(0.12)
        ballNode.lineWidth = 1
        ballNode.zPosition = 902
        addChild(ballNode)
        highlightNode.fillColor = UIColor.white.withAlphaComponent(0.34)
        highlightNode.strokeColor = .clear
        highlightNode.zPosition = 903
        addChild(highlightNode)

        scoreLabel.fontSize = max(44, size.width * 0.145)
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        scoreLabel.zPosition = 2_000
        addChild(scoreLabel)

        debugLabel.fontSize = 11
        debugLabel.fontColor = .green
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.position = CGPoint(x: 12, y: size.height - 55)
        debugLabel.zPosition = 3_000
        debugLabel.isHidden = !debugOptions.showOverlay
        addChild(debugLabel)
    }

    private func syncPresentation() {
        let render = logic.renderState
        if render.cells != renderedCells { rebuildTrack(cells: render.cells); renderedCells = render.cells }
        let projection = ZigProjection(size: size, config: config, cameraProgress: render.cameraProgress, cameraLateral: cameraLateral)
        var ballPosition = projection.point(x: render.ballPosition.x, y: render.ballPosition.y)
        let fall = render.fallProgress
        ballPosition.x += render.direction.vector.dx * fall * size.width * 0.06
        ballPosition.y -= fall * fall * size.height * 0.18
        ballNode.position = ballPosition
        ballNode.setScale(1 - fall * 0.35)
        ballNode.alpha = 1 - fall * 0.55
        let radius = size.width * config.ballRadiusRatio
        highlightNode.position = CGPoint(x: ballPosition.x - radius * 0.28, y: ballPosition.y + radius * 0.32)
        highlightNode.setScale(1 - fall * 0.35)
        highlightNode.alpha = ballNode.alpha
        let ground = projection.point(x: render.ballPosition.x, y: render.ballPosition.y)
        shadowNode.position = CGPoint(x: ground.x, y: ground.y - radius * 0.42)
        shadowNode.alpha = 0.28 * (1 - fall)
        scoreLabel.text = "\(render.score)"
        worldLayer.position = CGPoint(
            x: -cameraLateral * projection.horizontalScale,
            y: -render.cameraProgress * projection.verticalScale
        )
        debugLabel.text = "score \(render.score)  speed \(String(format: "%.2f", logic.currentSpeed))\nposition \(String(format: "%.2f", render.ballPosition.x)), \(String(format: "%.2f", render.ballPosition.y))\ncells \(render.cells.count)  state \(String(describing: render.state))"
    }

    private func updateCamera(deltaTime: TimeInterval) {
        guard logic.state == .running || logic.state == .falling else { return }
        let target = logic.ballPosition.x - logic.ballPosition.y
        let response = max(0.001, config.horizontalFollowResponse)
        let blend = CGFloat(1 - exp(-deltaTime / response))
        cameraLateral += (target - cameraLateral) * blend
    }

    private func handleEvents() {
        for event in logic.drainEvents() {
            switch event {
            case .turned:
                if debugOptions.autoPlay { gameDelegate?.zigSceneDidTurn(self) }
            case .fell:
                gameDelegate?.zigSceneDidFall(self)
            case .finished:
                guard !didReportFinish, !debugOptions.holdFailure else { continue }
                didReportFinish = true
                gameDelegate?.zigScene(self, didEndWith: logic.makeSummary())
            }
        }
    }

    private func rebuildTrack(cells: Set<ZigCell>) {
        worldLayer.removeAllChildren()
        let projection = ZigProjection(size: size, config: config, cameraProgress: 0, cameraLateral: 0)
        addSlab(polygon: projection.topPolygon(centerX: 0, centerY: 0, width: config.startingPadHalfWidth * 2),
                z: 500, projection: projection, leftColor: config.leftSideColor, rightColor: config.rightSideColor)
        for cell in cells.sorted(by: { $0.progress < $1.progress }) {
            let polygon = projection.topPolygon(centerX: CGFloat(cell.x), centerY: CGFloat(cell.y), width: config.trackWidth)
            let z = CGFloat(400 - cell.progress)
            addTop(polygon, z: z)
            let minusX = ZigCell(x: cell.x - 1, y: cell.y)
            let minusY = ZigCell(x: cell.x, y: cell.y - 1)
            if !cells.contains(minusX), !(cell.x <= 0 && cell.y == 3) {
                addFace(from: polygon[0], to: polygon[3], color: config.leftSideColor, z: z - 0.2, depth: projection.slabDepth)
            }
            if !cells.contains(minusY), !(cell.x == 0 && cell.y <= 3) {
                addFace(from: polygon[0], to: polygon[1], color: config.rightSideColor, z: z - 0.1, depth: projection.slabDepth)
            }
        }
    }

    private func addSlab(polygon: [CGPoint], z: CGFloat, projection: ZigProjection, leftColor: UIColor, rightColor: UIColor) {
        addFace(from: polygon[0], to: polygon[3], color: leftColor, z: z - 0.2, depth: projection.slabDepth)
        addFace(from: polygon[0], to: polygon[1], color: rightColor, z: z - 0.1, depth: projection.slabDepth)
        addTop(polygon, z: z)
    }

    private func addTop(_ points: [CGPoint], z: CGFloat) {
        let node = SKShapeNode(path: path(points))
        node.fillColor = config.topColor
        node.strokeColor = debugOptions.showSupport ? UIColor.systemRed.withAlphaComponent(0.75) : .clear
        node.lineWidth = debugOptions.showSupport ? 1 : 0
        node.zPosition = z
        worldLayer.addChild(node)
    }

    private func addFace(from first: CGPoint, to second: CGPoint, color: UIColor, z: CGFloat, depth: CGFloat) {
        let points = [first, second, CGPoint(x: second.x, y: second.y - depth), CGPoint(x: first.x, y: first.y - depth)]
        let node = SKShapeNode(path: path(points))
        node.fillColor = color
        node.strokeColor = .clear
        node.zPosition = z
        worldLayer.addChild(node)
    }

    private func path(_ points: [CGPoint]) -> CGPath {
        let result = CGMutablePath()
        guard let first = points.first else { return result }
        result.move(to: first)
        points.dropFirst().forEach { result.addLine(to: $0) }
        result.closeSubpath()
        return result
    }

    private func gradientTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [config.backgroundBottomColor.cgColor, config.backgroundTopColor.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: image)
    }
}
