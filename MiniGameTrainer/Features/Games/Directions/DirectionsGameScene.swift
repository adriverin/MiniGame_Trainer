import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol DirectionsGameSceneDelegate: AnyObject {
    func directionsSceneDidAcceptInput(_ scene: DirectionsGameScene)
    func directionsSceneDidCompleteRound(_ scene: DirectionsGameScene)
    func directionsSceneDidFail(_ scene: DirectionsGameScene)
    func directionsScene(_ scene: DirectionsGameScene, didEndWith summary: DirectionsSessionSummary)
}

@MainActor
final class DirectionsGameScene: SKScene {
    let logic: DirectionsGameLogic
    let config: DirectionsGameConfig
    let geometry: DirectionsGeometry
    weak var gameDelegate: DirectionsGameSceneDelegate?

    var debugOptions: DirectionsDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let phaseLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let observeArrow = SKShapeNode()
    private var buttonNodes: [Direction: SKShapeNode] = [:]
    private var buttonArrowNodes: [Direction: SKShapeNode] = [:]
    private var sequenceNodes: [SKShapeNode] = []
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var geometryNodes: [SKShapeNode] = []

    private var activeTouch: UITouch?
    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var measuredFPS = 0.0
    private var nextAutoInputTime: TimeInterval = 0
    private var autoInputCount = 0

    init(size: CGSize, config: DirectionsGameConfig, debugOptions: DirectionsDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = DirectionsGeometry(sceneSize: size, config: config)
        logic = DirectionsGameLogic(config: config, seed: debugOptions.seed ?? config.generatorSeed)
        logic.forcedSequence = debugOptions.forcedSequence
        logic.forcedLevel = debugOptions.forcedLevel
        logic.skipPresentation = debugOptions.skipPresentation
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        let timestamp = CACurrentMediaTime()
        if let previousFrameTime {
            let delta = timestamp - previousFrameTime
            if delta > 0 {
                let fps = 1 / delta
                measuredFPS = measuredFPS == 0 ? fps : measuredFPS * 0.9 + fps * 0.1
            }
        }
        previousFrameTime = timestamp
        logic.update(at: timestamp)
        performDebugAutoInputIfNeeded(at: timestamp)
        syncPresentation()
        updateDebugOverlay()

        if logic.isFinished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.directionsScene(self, didEndWith: logic.makeSummary(at: timestamp))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        guard logic.beginPress() else { return }
        activeTouch = touch
        let location = touch.location(in: self)
        let now = CACurrentMediaTime()
        if logic.state == .ready {
            _ = logic.handleInput(.up, at: now)
            syncPresentation()
            return
        }
        guard logic.acceptsInput, let direction = geometry.direction(at: location) else { return }
        applyInput(direction, at: now)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.endPress()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause(at: CACurrentMediaTime())
        activeTouch = nil
        logic.endPress()
        isPaused = true
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        logic.resume(at: CACurrentMediaTime())
        syncPresentation()
    }

    func startSession() {
        isPaused = false
        activeTouch = nil
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        nextAutoInputTime = 0
        autoInputCount = 0
        logic.reset()
        logic.forcedSequence = debugOptions.forcedSequence
        logic.forcedLevel = debugOptions.forcedLevel
        logic.skipPresentation = debugOptions.skipPresentation
        if !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation()
    }

    private func applyInput(_ direction: Direction, at time: TimeInterval) {
        let outcome = logic.handleInput(direction, at: time)
        switch outcome {
        case .accepted:
            gameDelegate?.directionsSceneDidAcceptInput(self)
        case .completedRound:
            gameDelegate?.directionsSceneDidCompleteRound(self)
        case .failed:
            gameDelegate?.directionsSceneDidFail(self)
            finishReportTime = time + config.gameOverHoldDuration
        default:
            break
        }
        syncPresentation()
    }

    private func setupNodes() {
        scoreLabel.fontSize = max(36, size.width * config.scoreFontWidthRatio)
        scoreLabel.fontColor = config.hudTextColor
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = geometry.scorePosition
        scoreLabel.zPosition = 8
        addChild(scoreLabel)

        levelLabel.fontSize = max(16, size.width * config.levelFontWidthRatio)
        levelLabel.fontColor = config.hudTextColor
        levelLabel.horizontalAlignmentMode = .right
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = geometry.levelPosition
        levelLabel.zPosition = 8
        addChild(levelLabel)

        phaseLabel.fontSize = max(18, size.width * config.phaseFontWidthRatio)
        phaseLabel.fontColor = config.hudTextColor
        phaseLabel.horizontalAlignmentMode = .left
        phaseLabel.verticalAlignmentMode = .center
        phaseLabel.position = geometry.phasePosition
        phaseLabel.zPosition = 8
        addChild(phaseLabel)

        observeArrow.fillColor = config.observeArrowColor
        observeArrow.strokeColor = .clear
        observeArrow.zPosition = 4
        observeArrow.position = geometry.observeArrowCenter
        observeArrow.path = DirectionsArrowPath.make(size: geometry.observeArrowSize)
        addChild(observeArrow)

        for direction in Direction.allCases {
            let button = SKShapeNode(
                rectOf: CGSize(width: geometry.buttonSize, height: geometry.buttonSize),
                cornerRadius: geometry.buttonCornerRadius
            )
            button.fillColor = config.buttonFillColor
            button.strokeColor = .clear
            button.position = geometry.buttonCenter(for: direction)
            button.zPosition = 5
            button.name = direction.rawValue
            button.isAccessibilityElement = true
            button.accessibilityLabel = direction.accessibilityName
            addChild(button)
            buttonNodes[direction] = button

            let arrow = SKShapeNode(path: DirectionsArrowPath.make(
                size: CGSize(width: geometry.buttonArrowSize, height: geometry.buttonArrowSize)
            ))
            arrow.fillColor = config.buttonArrowColor
            arrow.strokeColor = .clear
            arrow.zRotation = direction.zRotation
            arrow.zPosition = 6
            arrow.position = button.position
            arrow.isAccessibilityElement = false
            addChild(arrow)
            buttonArrowNodes[direction] = arrow
        }

        debugLabel.fontSize = 11
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.preferredMaxLayoutWidth = size.width - 24
        debugLabel.position = CGPoint(x: 12, y: size.height - 56)
        debugLabel.zPosition = 20
        debugLabel.isHidden = true
        addChild(debugLabel)

        updateDebugVisibility()
    }

    private func syncPresentation() {
        scoreLabel.text = "\(logic.score)"
        levelLabel.text = "LEVEL \(logic.level)"
        phaseLabel.text = logic.phaseLabel
        phaseLabel.fontColor = logic.state == .roundSuccess ? config.successTextColor : config.hudTextColor

        if let direction = logic.visibleDirection {
            observeArrow.isHidden = false
            observeArrow.zRotation = direction.zRotation
        } else {
            observeArrow.isHidden = true
        }

        let showPad = logic.state == .recalling || logic.state == .roundSuccess
            || (logic.state == .gameOver && !logic.playerInput.isEmpty)
        for direction in Direction.allCases {
            buttonNodes[direction]?.isHidden = !showPad
            buttonArrowNodes[direction]?.isHidden = !showPad
        }

        syncSequenceRow()
    }

    private func syncSequenceRow() {
        let show = logic.state == .recalling || logic.state == .roundSuccess || logic.state == .gameOver
        let inputs = show ? logic.playerInput : []
        while sequenceNodes.count < inputs.count {
            let node = SKShapeNode()
            node.fillColor = .white
            node.strokeColor = .clear
            node.zPosition = 7
            addChild(node)
            sequenceNodes.append(node)
        }
        for (index, node) in sequenceNodes.enumerated() {
            guard index < inputs.count else {
                node.isHidden = true
                continue
            }
            let direction = inputs[index]
            node.isHidden = false
            node.path = DirectionsArrowPath.make(
                size: CGSize(width: geometry.sequenceIconSize, height: geometry.sequenceIconSize)
            )
            node.zRotation = direction.zRotation
            node.position = geometry.sequenceIconCenter(at: index)
        }
    }

    private func performDebugAutoInputIfNeeded(at time: TimeInterval) {
        guard debugOptions.autoInputCorrect, logic.state == .recalling else { return }
        guard time >= nextAutoInputTime else { return }
        let index = logic.inputIndex
        guard logic.target.indices.contains(index) else { return }
        var direction = logic.target[index]
        if let failAt = debugOptions.autoInputFailAt, index == failAt {
            direction = direction.opposite
        }
        nextAutoInputTime = time + config.autoInputInterval
        autoInputCount += 1
        if logic.beginPress() {
            applyInput(direction, at: time)
            logic.endPress()
        }
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        geometryNodes.forEach { $0.removeFromParent() }
        geometryNodes.removeAll()
        guard debugOptions.showGeometry else { return }
        for direction in Direction.allCases {
            let hit = SKShapeNode(rect: geometry.hitRect(for: direction))
            hit.strokeColor = AppTheme.UIColors.debugHitbox
            hit.fillColor = .clear
            hit.lineWidth = 1
            hit.zPosition = 18
            addChild(hit)
            geometryNodes.append(hit)
        }
    }

    private func updateDebugOverlay() {
        guard debugOptions.showOverlay else { return }
        let targetText = logic.target.map(\.rawValue).joined(separator: " ")
        let prefix = logic.playerInput.map(\.rawValue).joined(separator: " ")
        debugLabel.text = """
        L\(logic.level)  score \(logic.score)  \(logic.state.rawValue)
        target [\(targetText)]
        prefix [\(prefix)]  idx \(logic.inputIndex)/\(logic.sequenceLength)
        on \(String(format: "%.3f", config.arrowOnDuration))  gap \(String(format: "%.3f", config.interArrowGap))
        seed \(debugOptions.seed.map(String.init) ?? "live")  fps \(Int(measuredFPS.rounded()))
        """
    }
}

enum DirectionsArrowPath {
    static func make(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.addLine(to: CGPoint(x: halfWidth, y: -halfHeight))
        path.addQuadCurve(
            to: CGPoint(x: -halfWidth, y: -halfHeight),
            control: CGPoint(x: 0, y: -halfHeight * 0.35)
        )
        path.closeSubpath()
        return path
    }
}
