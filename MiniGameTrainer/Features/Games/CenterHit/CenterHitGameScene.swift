import QuartzCore
import SpriteKit

@MainActor
protocol CenterHitGameSceneDelegate: AnyObject {
    func centerHitSceneDidRecordTap(_ scene: CenterHitGameScene)
    func centerHitScene(_ scene: CenterHitGameScene, didEndWith summary: CenterHitSessionSummary)
}

@MainActor
final class CenterHitGameScene: SKScene {
    let logic: CenterHitGameLogic
    let config: CenterHitGameConfig
    let geometry: CenterHitGeometry
    weak var gameDelegate: CenterHitGameSceneDelegate?

    var debugOptions: CenterHitDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let attemptLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let precisionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let readyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let indicatorNode: SKShapeNode
    private var attemptMarkerNodes: [SKShapeNode] = []
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugBoundsNode = SKShapeNode()
    private let debugCenterNode = SKShapeNode()
    private let debugTouchNode = SKShapeNode()
    private let debugErrorNode = SKShapeNode()

    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0

    var renderedAttemptMarkerCount: Int { attemptMarkerNodes.count }
    var renderedAttemptMarkerPositions: [CGFloat] { attemptMarkerNodes.map(\.position.x) }

    init(size: CGSize, config: CenterHitGameConfig, debugOptions: CenterHitDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = CenterHitGeometry(sceneSize: size, config: config)
        logic = CenterHitGameLogic(
            config: config,
            leftBoundary: Double(geometry.leftBoundary),
            rightBoundary: Double(geometry.rightBoundary)
        )
        indicatorNode = SKShapeNode(
            rectOf: geometry.indicatorSize,
            cornerRadius: geometry.indicatorSize.width / 2
        )
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        let timestamp = CACurrentMediaTime()
        if let previousFrameTime {
            let delta = timestamp - previousFrameTime
            if delta > 0 {
                measuredFPS = measuredFPS == 0 ? 1 / delta : measuredFPS * 0.9 + (1 / delta) * 0.1
            }
        }
        previousFrameTime = timestamp

        logic.update(at: timestamp)
        performDebugAutoTapIfNeeded(at: timestamp)
        syncPresentation()
        updateDebugOverlay(at: timestamp)

        if logic.isFinished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.centerHitScene(self, didEndWith: logic.makeSummary(at: timestamp))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Use one monotonic clock for render updates and touches, and resolve position before work.
        let timestamp = CACurrentMediaTime()
        guard touches.count == 1 else { return }
        handle(logic.handleTap(at: timestamp), at: timestamp)
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause(at: CACurrentMediaTime())
        syncPresentation()
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
        logic.reset()
        finishReportTime = nil
        didReportFinish = false
        previousFrameTime = nil
        debugTouchNode.isHidden = true
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation()
    }

    private func setupNodes() {
        let crop = SKCropNode()
        let mask = SKShapeNode(rect: geometry.barFrame, cornerRadius: geometry.barFrame.height / 2)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        let colors = [
            config.redColor, config.orangeColor, config.yellowColor, config.greenColor,
            config.yellowColor, config.orangeColor, config.redColor,
        ]
        for (frame, color) in zip(geometry.zoneFrames, colors) {
            let zone = SKShapeNode(rect: frame)
            zone.fillColor = color
            zone.strokeColor = .clear
            crop.addChild(zone)
        }
        crop.zPosition = 1
        addChild(crop)

        let centerLine = SKShapeNode(
            rectOf: CGSize(width: geometry.centerLineWidth, height: geometry.barFrame.height),
            cornerRadius: geometry.centerLineWidth / 2
        )
        centerLine.fillColor = UIColor.white.withAlphaComponent(0.92)
        centerLine.strokeColor = .clear
        centerLine.position = CGPoint(x: geometry.centerX, y: geometry.barFrame.midY)
        centerLine.zPosition = 3
        addChild(centerLine)

        indicatorNode.fillColor = .white
        indicatorNode.strokeColor = .clear
        indicatorNode.glowWidth = max(1, geometry.indicatorSize.width * 0.45)
        indicatorNode.position = CGPoint(x: CGFloat(logic.position), y: geometry.barFrame.midY)
        indicatorNode.zPosition = 8
        addChild(indicatorNode)

        attemptLabel.fontSize = max(15, size.width * 0.041)
        attemptLabel.fontColor = UIColor.white.withAlphaComponent(0.72)
        attemptLabel.horizontalAlignmentMode = .center
        attemptLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.665)
        attemptLabel.zPosition = 10
        addChild(attemptLabel)

        precisionLabel.fontSize = max(36, size.width * 0.135)
        precisionLabel.fontColor = config.precisionColor
        precisionLabel.horizontalAlignmentMode = .center
        precisionLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.555)
        precisionLabel.zPosition = 10
        addChild(precisionLabel)

        readyLabel.text = "Ready\nTap to start"
        readyLabel.numberOfLines = 2
        readyLabel.horizontalAlignmentMode = .center
        readyLabel.verticalAlignmentMode = .center
        readyLabel.fontSize = max(20, size.width * 0.056)
        readyLabel.fontColor = .white
        readyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
        readyLabel.zPosition = 20
        addChild(readyLabel)

        setupDebugNodes()
        updateDebugVisibility()
    }

    private func setupDebugNodes() {
        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.024)
        debugLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        debugLabel.position = CGPoint(x: 10, y: size.height - 48)
        debugLabel.zPosition = 100
        addChild(debugLabel)

        debugBoundsNode.path = CGPath(roundedRect: geometry.barFrame, cornerWidth: geometry.barFrame.height / 2, cornerHeight: geometry.barFrame.height / 2, transform: nil)
        debugBoundsNode.fillColor = .clear
        debugBoundsNode.strokeColor = .systemGreen
        debugBoundsNode.lineWidth = 1
        debugBoundsNode.zPosition = 50
        addChild(debugBoundsNode)

        let centerPath = CGMutablePath()
        centerPath.move(to: CGPoint(x: geometry.centerX, y: geometry.barFrame.minY - 30))
        centerPath.addLine(to: CGPoint(x: geometry.centerX, y: geometry.barFrame.maxY + 30))
        debugCenterNode.path = centerPath
        debugCenterNode.strokeColor = .systemPink
        debugCenterNode.lineWidth = 1
        debugCenterNode.zPosition = 51
        addChild(debugCenterNode)

        debugTouchNode.path = CGPath(
            rect: CGRect(x: -1, y: -geometry.indicatorSize.height / 2, width: 2, height: geometry.indicatorSize.height),
            transform: nil
        )
        debugTouchNode.fillColor = .cyan
        debugTouchNode.strokeColor = .clear
        debugTouchNode.position.y = geometry.barFrame.midY
        debugTouchNode.zPosition = 52
        addChild(debugTouchNode)

        debugErrorNode.strokeColor = .cyan
        debugErrorNode.lineWidth = 2
        debugErrorNode.zPosition = 52
        addChild(debugErrorNode)
    }

    private func handle(_ outcome: CenterHitTapOutcome, at timestamp: TimeInterval) {
        switch outcome {
        case .scored(let attempt):
            showEvaluatedPosition(attempt)
            gameDelegate?.centerHitSceneDidRecordTap(self)
        case .finished(let attempt):
            showEvaluatedPosition(attempt)
            gameDelegate?.centerHitSceneDidRecordTap(self)
            finishReportTime = timestamp + max(0, config.sessionEndHoldDuration)
        case .ignored, .started:
            break
        }
        syncPresentation()
    }

    private func syncPresentation() {
        indicatorNode.position.x = CGFloat(logic.position)
        attemptLabel.text = "TAP \(logic.currentAttemptNumber) OF \(max(config.attemptCount, 1))"
        readyLabel.isHidden = logic.state != .ready
        attemptLabel.isHidden = logic.state == .ready
        if let precision = logic.attempts.last?.precision {
            precisionLabel.text = CenterHitFormatter.percent(precision)
            precisionLabel.isHidden = false
        } else {
            precisionLabel.isHidden = true
        }
        syncAttemptMarkers()
        updateDebugErrorLine()
    }

    /// The reference retains every real attempt marker. Nodes are derived only from attempt
    /// telemetry, so their X coordinate is identical to the timestamp-resolved scoring position.
    func syncAttemptMarkers() {
        while attemptMarkerNodes.count > logic.attempts.count {
            attemptMarkerNodes.removeLast().removeFromParent()
        }
        while attemptMarkerNodes.count < logic.attempts.count {
            let attempt = logic.attempts[attemptMarkerNodes.count]
            let marker = SKShapeNode(circleOfRadius: geometry.barFrame.height * 0.0575)
            marker.fillColor = .clear
            marker.strokeColor = UIColor(red: 12 / 255, green: 126 / 255, blue: 57 / 255, alpha: 0.95)
            marker.lineWidth = max(1.5, geometry.barFrame.height * 0.019)
            marker.position = CGPoint(x: CGFloat(attempt.indicatorX), y: geometry.barFrame.midY)
            marker.zPosition = 6
            addChild(marker)
            attemptMarkerNodes.append(marker)
        }
    }

    private func showEvaluatedPosition(_ attempt: CenterHitAttempt) {
        debugTouchNode.position.x = CGFloat(attempt.indicatorX)
        debugTouchNode.isHidden = !debugOptions.showGeometry
    }

    private func updateDebugErrorLine() {
        let y = geometry.barFrame.minY - 18
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.centerX, y: y))
        path.addLine(to: CGPoint(x: CGFloat(logic.position), y: y))
        debugErrorNode.path = path
    }

    private func performDebugAutoTapIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard debugOptions.autoTap, logic.state == .running else { return }
        let signedErrors: [Double] = [0, 0.018, -0.014, 0.026, -0.032]
        let index = min(logic.attempts.count, signedErrors.count - 1)
        let target = logic.centerX + signedErrors[index] * logic.halfWidth
        let tolerance = max(Double(geometry.indicatorSize.width), logic.currentSpeed / 60)
        guard abs(logic.position - target) <= tolerance else { return }
        handle(logic.handleTap(at: time), at: time)
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showTimingOverlay
        debugBoundsNode.isHidden = !debugOptions.showGeometry
        debugCenterNode.isHidden = !debugOptions.showGeometry
        debugErrorNode.isHidden = !debugOptions.showGeometry
        debugTouchNode.isHidden = !debugOptions.showGeometry || logic.attempts.isEmpty
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showTimingOverlay else { return }
        let last = logic.attempts.last
        let average = logic.makeSummary(at: time).averagePrecision
        let traversal = logic.currentSpeed > 0 ? logic.travelWidth / logic.currentSpeed : 0
        debugLabel.text = [
            "FPS: \(Int(measuredFPS.rounded()))",
            "Attempt: \(logic.currentAttemptNumber) / \(max(config.attemptCount, 1))",
            "Direction: \(logic.direction.symbol)",
            String(format: "Indicator X: %.2f", logic.position),
            String(format: "Center X: %.2f", logic.centerX),
            String(format: "Error: %.2f pt", abs(logic.position - logic.centerX)),
            String(format: "Normalized: %.4f", logic.halfWidth > 0 ? abs(logic.position - logic.centerX) / logic.halfWidth : 0),
            String(format: "Speed: %.1f pt/s", logic.currentSpeed),
            String(format: "Traversal: %.3f s", traversal),
            "Last: \(CenterHitFormatter.percent(last?.precision))",
            "Average: \(CenterHitFormatter.percent(average))",
            String(format: "Game time: %.2f s", logic.makeSummary(at: time).duration),
        ].joined(separator: "\n")
    }
}
