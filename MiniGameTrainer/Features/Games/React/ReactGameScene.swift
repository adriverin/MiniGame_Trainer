import QuartzCore
import SpriteKit

@MainActor
protocol ReactGameSceneDelegate: AnyObject {
    func reactSceneDidRecordCorrectTap(_ scene: ReactGameScene)
    func reactSceneDidRecordInvalidTap(_ scene: ReactGameScene)
    func reactScene(_ scene: ReactGameScene, didEndWith summary: ReactSessionSummary)
}

@MainActor
final class ReactGameScene: SKScene {
    let logic: ReactGameLogic
    let config: ReactGameConfig
    let geometry: ReactGeometry
    weak var gameDelegate: ReactGameSceneDelegate?

    var debugOptions: ReactDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private var targetNodes: [SKShapeNode] = []
    private var hitboxNodes: [SKShapeNode] = []
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let roundLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var renderedActiveTarget: Int?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var autoTapStimulusTime: TimeInterval?

    init(size: CGSize, config: ReactGameConfig, debugOptions: ReactDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = ReactGeometry(sceneSize: size, config: config)
        logic = ReactGameLogic(config: config)
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
            if delta > 0 { measuredFPS = measuredFPS == 0 ? 1 / delta : measuredFPS * 0.9 + (1 / delta) * 0.1 }
        }
        previousFrameTime = timestamp

        logic.update(at: timestamp)
        syncPresentation()
        performDebugAutoTapIfNeeded(at: timestamp)
        updateDebugOverlay(at: timestamp)

        if logic.state == .finished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.reactScene(self, didEndWith: logic.makeSummary(at: timestamp))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Capture the monotonic event timestamp before hit testing or any feedback work.
        let timestamp = CACurrentMediaTime()
        guard let touch = touches.first else { return }
        let targetIndex: Int?
        if touches.count == 1 {
            targetIndex = geometry.targetIndex(at: touch.location(in: self))
        } else {
            targetIndex = nil
        }

        let outcome = logic.handleTap(targetIndex: targetIndex, at: timestamp)
        syncPresentation()
        switch outcome {
        case .correct:
            gameDelegate?.reactSceneDidRecordCorrectTap(self)
        case .premature, .wrongTarget, .penaltyRecorded:
            gameDelegate?.reactSceneDidRecordInvalidTap(self)
        case .ignored, .started:
            break
        }
        if logic.state == .finished {
            finishReportTime = timestamp + max(0, config.sessionEndHoldDuration)
        }
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
        renderedActiveTarget = nil
        autoTapStimulusTime = nil
        previousFrameTime = nil
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation()
    }

    private func setupNodes() {
        titleLabel.text = "REACT!"
        titleLabel.fontSize = max(24, size.width * 0.075)
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        roundLabel.fontSize = max(13, size.width * 0.038)
        roundLabel.fontColor = UIColor.white.withAlphaComponent(0.62)
        roundLabel.position = CGPoint(x: size.width / 2, y: geometry.gridCenter.y + geometry.gridHeight / 2 + size.height * 0.065)
        roundLabel.zPosition = 10
        addChild(roundLabel)

        let circlePath = CGPath(ellipseIn: CGRect(
            x: -geometry.circleDiameter / 2,
            y: -geometry.circleDiameter / 2,
            width: geometry.circleDiameter,
            height: geometry.circleDiameter
        ), transform: nil)
        for index in 0..<9 {
            let node = SKShapeNode(path: circlePath)
            node.fillColor = config.inactiveColor
            node.strokeColor = .clear
            node.position = geometry.center(for: index)
            node.zPosition = 2
            node.name = "react-target-\(index)"
            addChild(node)
            targetNodes.append(node)

            let hitbox = SKShapeNode(path: circlePath)
            hitbox.fillColor = .clear
            hitbox.strokeColor = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.75)
            hitbox.lineWidth = 1
            hitbox.position = node.position
            hitbox.zPosition = 5
            hitbox.isHidden = true
            addChild(hitbox)
            hitboxNodes.append(hitbox)
        }

        statusLabel.text = "Ready\nTap to start"
        statusLabel.numberOfLines = 2
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .center
        statusLabel.fontSize = max(20, size.width * 0.058)
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        statusLabel.zPosition = 20
        addChild(statusLabel)

        feedbackLabel.fontSize = max(14, size.width * 0.041)
        feedbackLabel.fontColor = UIColor.white.withAlphaComponent(0.82)
        feedbackLabel.horizontalAlignmentMode = .center
        feedbackLabel.position = CGPoint(
            x: geometry.gridCenter.x,
            y: geometry.gridCenter.y - geometry.gridHeight / 2 - size.height * 0.055
        )
        feedbackLabel.zPosition = 10
        feedbackLabel.isHidden = true
        addChild(feedbackLabel)

        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.025)
        debugLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        debugLabel.position = CGPoint(x: 10, y: size.height - 48)
        debugLabel.zPosition = 100
        addChild(debugLabel)
        updateDebugVisibility()
    }

    private func syncPresentation() {
        let active = logic.state == .targetVisible ? logic.activeTargetIndex : nil
        if active != renderedActiveTarget {
            for (index, node) in targetNodes.enumerated() {
                node.removeAllActions()
                node.setScale(1)
                node.fillColor = index == active ? config.activeColor : config.inactiveColor
            }
            renderedActiveTarget = active
            autoTapStimulusTime = active == nil ? nil : logic.stimulusPresentedTime
        }

        roundLabel.text = "Round \(logic.currentRoundNumber) / \(max(config.roundCount, 1))"
        roundLabel.isHidden = logic.state == .ready
        statusLabel.isHidden = logic.state != .ready
        if logic.state == .ready {
            statusLabel.text = "Ready\nTap to start"
        }

        if logic.state == .targetVisible || logic.lastFeedback == nil {
            feedbackLabel.isHidden = true
        } else {
            feedbackLabel.isHidden = false
            switch logic.lastFeedback {
            case .reaction(let reaction): feedbackLabel.text = MetricFormatter.milliseconds(reaction)
            case .tooSoon: feedbackLabel.text = "Too soon — wait reset"
            case .wrongTarget: feedbackLabel.text = "Wrong target — wait reset"
            case nil: feedbackLabel.text = nil
            }
        }
    }

    private func performDebugAutoTapIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard debugOptions.autoTap,
              logic.state == .targetVisible,
              let target = logic.activeTargetIndex,
              let autoTapStimulusTime,
              time - autoTapStimulusTime >= 0.288 else { return }
        let outcome = logic.handleTap(targetIndex: target, at: time)
        self.autoTapStimulusTime = nil
        syncPresentation()
        if case .correct = outcome { gameDelegate?.reactSceneDidRecordCorrectTap(self) }
        if logic.state == .finished {
            finishReportTime = time + max(0, config.sessionEndHoldDuration)
        }
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showTimingOverlay
        hitboxNodes.forEach { $0.isHidden = !debugOptions.showHitboxes }
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showTimingOverlay else { return }
        let remaining = logic.nextStimulusTime.map { max(0, $0 - time) }
        let lastReaction: String
        if case .reaction(let reaction) = logic.lastFeedback {
            lastReaction = MetricFormatter.milliseconds(reaction)
        } else {
            lastReaction = "–"
        }
        let nextDelayText = remaining.map { String(format: "%.3f s", $0) } ?? "–"
        let targetText = logic.activeTargetIndex.map(String.init) ?? "–"
        let stimulusText = logic.stimulusPresentedTime.map { String(format: "%.6f", $0) } ?? "–"
        let seedText = config.randomSeed.map(String.init) ?? "random"
        debugLabel.text = [
            "State: \(logic.state.rawValue)",
            "Round: \(logic.currentRoundNumber) / \(max(config.roundCount, 1))",
            "Next delay: \(nextDelayText)",
            "Target: \(targetText)",
            "Stimulus: \(stimulusText)",
            "Last reaction: \(lastReaction)",
            "Premature: \(logic.prematureTapCount)",
            "Wrong: \(logic.wrongTargetTapCount)",
            "FPS: \(Int(measuredFPS.rounded()))",
            "Seed: \(seedText)",
        ].joined(separator: "\n")
    }
}
