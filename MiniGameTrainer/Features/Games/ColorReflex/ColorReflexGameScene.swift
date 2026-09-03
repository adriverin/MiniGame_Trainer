import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol ColorReflexGameSceneDelegate: AnyObject {
    func colorReflexSceneDidScore(_ scene: ColorReflexGameScene)
    func colorReflexSceneDidPrematureTap(_ scene: ColorReflexGameScene)
    func colorReflexScene(_ scene: ColorReflexGameScene, didEndWith summary: ColorReflexSessionSummary)
}

@MainActor
final class ColorReflexGameScene: SKScene {
    let logic: ColorReflexGameLogic
    let config: ColorReflexGameConfig
    let geometry: ColorReflexGeometry
    weak var gameDelegate: ColorReflexGameSceneDelegate?

    var debugOptions: ColorReflexDebugOptions {
        didSet { applyDebugOverrides(); updateDebugVisibility() }
    }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let promptLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let reactionLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let barTrackNode: SKShapeNode
    private let barFillNode: SKShapeNode
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugBoundsNode = SKShapeNode()

    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var activeTouch: UITouch?
    private var didAutoPremature = false
    private var lastAutoReactTrigger: TimeInterval?

    init(size: CGSize, config: ColorReflexGameConfig, debugOptions: ColorReflexDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = ColorReflexGeometry(sceneSize: size, config: config)
        logic = ColorReflexGameLogic(config: config, seed: debugOptions.seed ?? config.generatorSeed)
        barTrackNode = SKShapeNode(rect: geometry.barTrackFrame, cornerRadius: geometry.barCornerRadius)
        barFillNode = SKShapeNode()
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = ColorReflexSwatch.teal.uiColor
        setupNodes()
        applyDebugOverrides()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
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
        performDebugAutomationIfNeeded(at: timestamp)
        if logic.isFinished, finishReportTime == nil {
            finishReportTime = timestamp + config.sessionEndHoldDuration
        }
        if logic.isFinished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.colorReflexScene(self, didEndWith: logic.makeSummary(at: timestamp))
        }
        syncPresentation(at: timestamp)
        updateDebugOverlay(at: timestamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let timestamp = CACurrentMediaTime()
        guard activeTouch == nil, let touch = touches.first, touches.count == 1 else { return }
        activeTouch = touch
        handle(logic.handleTouchBegan(at: timestamp))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.handleTouchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.handleTouchEnded()
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause(at: CACurrentMediaTime())
        activeTouch = nil
        isPaused = true
        syncPresentation(at: CACurrentMediaTime())
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        didAutoPremature = false
        lastAutoReactTrigger = nil
        applyDebugOverrides()
        logic.resume(at: CACurrentMediaTime())
        if logic.state == .ready, debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    func startSession() {
        isPaused = false
        activeTouch = nil
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        didAutoPremature = false
        lastAutoReactTrigger = nil
        logic.reset()
        applyDebugOverrides()
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func setupNodes() {
        scoreLabel.fontSize = geometry.scoreFontSize
        scoreLabel.fontColor = .white
        scoreLabel.position = geometry.scorePosition
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        promptLabel.fontSize = geometry.promptFontSize
        promptLabel.fontColor = .white
        promptLabel.position = geometry.promptPosition
        promptLabel.verticalAlignmentMode = .center
        promptLabel.zPosition = 10
        addChild(promptLabel)

        reactionLabel.fontSize = geometry.reactionFontSize
        reactionLabel.fontColor = UIColor.white.withAlphaComponent(config.reactionOpacity)
        reactionLabel.position = geometry.reactionPosition
        reactionLabel.verticalAlignmentMode = .center
        reactionLabel.zPosition = 10
        addChild(reactionLabel)

        barTrackNode.fillColor = UIColor.black.withAlphaComponent(config.barTrackOpacity)
        barTrackNode.strokeColor = config.barStrokeColor
        barTrackNode.lineWidth = geometry.barStrokeWidth
        barTrackNode.zPosition = 8
        addChild(barTrackNode)

        barFillNode.strokeColor = .clear
        barFillNode.zPosition = 9
        addChild(barFillNode)

        debugBoundsNode.strokeColor = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.85)
        debugBoundsNode.fillColor = .clear
        debugBoundsNode.lineWidth = 1
        debugBoundsNode.path = CGPath(
            roundedRect: geometry.barTrackFrame,
            cornerWidth: geometry.barCornerRadius,
            cornerHeight: geometry.barCornerRadius,
            transform: nil
        )
        debugBoundsNode.zPosition = 50
        addChild(debugBoundsNode)

        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.022)
        debugLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        debugLabel.position = CGPoint(x: 10, y: size.height - 48)
        debugLabel.zPosition = 100
        addChild(debugLabel)
        updateDebugVisibility()
    }

    private func handle(_ outcome: ColorReflexTapOutcome) {
        switch outcome {
        case .scored:
            gameDelegate?.colorReflexSceneDidScore(self)
        case .premature:
            gameDelegate?.colorReflexSceneDidPrematureTap(self)
        default:
            break
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func syncPresentation(at time: TimeInterval) {
        backgroundColor = logic.currentColor.uiColor
        scoreLabel.text = "\(logic.score)"
        switch logic.state {
        case .ready:
            promptLabel.text = config.requiresTapToStart ? "Tap to start" : "Wait..."
        case .waiting:
            promptLabel.text = "Wait..."
        case .tapNow:
            promptLabel.text = "Tap!"
        case .gameOver, .paused:
            promptLabel.text = logic.state == .paused ? "Paused" : "Wait..."
        }
        if let last = logic.lastReactionTime {
            reactionLabel.text = MetricFormatter.milliseconds(last)
            reactionLabel.isHidden = false
        } else {
            reactionLabel.isHidden = true
        }

        let playing = logic.isPlaying || logic.state == .ready
        let fraction = logic.state == .ready ? 1 : logic.remainingFraction(at: time)
        let fill = geometry.barFillFrame(remainingFraction: fraction)
        barFillNode.path = CGPath(
            roundedRect: fill,
            cornerWidth: min(geometry.barCornerRadius, fill.height / 2, fill.width / 2),
            cornerHeight: min(geometry.barCornerRadius, fill.height / 2, fill.width / 2),
            transform: nil
        )
        barFillNode.fillColor = config.barFillColor(for: config.barStage(remainingFraction: fraction))
        barTrackNode.isHidden = !playing && logic.state != .paused
        barFillNode.isHidden = barTrackNode.isHidden
        scoreLabel.alpha = logic.state == .ready && config.requiresTapToStart ? 0.45 : 1
    }

    private func applyDebugOverrides() {
        logic.forcedColorSequence = debugOptions.forcedColorSequence
        logic.scoreOverride = debugOptions.forcedScore
        logic.waitDelayOverride = debugOptions.waitDelayOverride
    }

    private func performDebugAutomationIfNeeded(at time: TimeInterval) {
        #if DEBUG
        if debugOptions.autoPremature,
           logic.state == .waiting,
           !didAutoPremature,
           let start = logic.sessionStartTimestamp,
           time - start >= debugOptions.autoPrematureAt {
            didAutoPremature = true
            handle(logic.handleTouchBegan(at: time))
            logic.handleTouchEnded()
            return
        }
        guard debugOptions.autoReact, logic.state == .tapNow, let trigger = logic.triggerTimestamp else { return }
        if lastAutoReactTrigger == trigger { return }
        guard time - trigger >= max(0, debugOptions.autoReactDelay) else { return }
        lastAutoReactTrigger = trigger
        handle(logic.handleTouchBegan(at: time))
        logic.handleTouchEnded()
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        debugBoundsNode.isHidden = !debugOptions.showGeometry
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showOverlay else { return }
        let remainingText = String(format: "%.3f", logic.remaining(at: time))
        let elapsedText = String(format: "%.3f", logic.elapsed(at: time))
        let deadlineText = logic.sessionDeadline.map { String(format: "%.6f", $0) } ?? "–"
        let waitText = logic.scheduledWaitDelay.map { String(format: "%.3f", $0) } ?? "–"
        let triggerText = logic.triggerTimestamp.map { String(format: "%.6f", $0) } ?? "–"
        let toTrigger = logic.timeUntilTrigger(at: time).map { String(format: "%.3f", $0) } ?? "–"
        let last = logic.lastReactionTime.map { MetricFormatter.milliseconds($0) } ?? "–"
        let average = logic.makeSummary(at: time).averageReactionTime.map { MetricFormatter.milliseconds($0) } ?? "–"
        let seedText = "\(debugOptions.seed ?? config.generatorSeed)"
        debugLabel.text = [
            "Score: \(logic.score)",
            "State: \(logic.state.rawValue)",
            "Elapsed: \(elapsedText)",
            "Remaining: \(remainingText)",
            "Deadline: \(deadlineText)",
            "Wait delay: \(waitText)",
            "Trigger: \(triggerText)",
            "To trigger: \(toTrigger)",
            "Last reaction: \(last)",
            "Average: \(average)",
            "Premature: \(logic.prematureTapCount)",
            "Color: \(logic.currentColor.rawValue)",
            "Next: \(logic.nextColor?.rawValue ?? "–")",
            "Seed: \(seedText)",
            "FPS: \(Int(measuredFPS.rounded()))",
        ].joined(separator: "\n")
    }
}
