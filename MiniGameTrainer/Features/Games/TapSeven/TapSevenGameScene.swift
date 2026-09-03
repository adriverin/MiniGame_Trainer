import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol TapSevenGameSceneDelegate: AnyObject {
    func tapSevenSceneDidRecordTap(_ scene: TapSevenGameScene)
    func tapSevenScene(_ scene: TapSevenGameScene, didEndWith summary: TapSevenSessionSummary)
}

@MainActor
final class TapSevenGameScene: SKScene {
    let logic: TapSevenGameLogic
    let config: TapSevenGameConfig
    let geometry: TapSevenGeometry
    weak var gameDelegate: TapSevenGameSceneDelegate?

    var debugOptions: TapSevenDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let trackNode = SKShapeNode()
    private let progressNode = SKShapeNode()
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let resultDetailLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let resultTitleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let startButtonNode = SKShapeNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugBoundsNode = SKShapeNode()

    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var didReportFinish = false
    private var autoPlayArmed = true
    private var finishReportTime: TimeInterval?

    init(size: CGSize, config: TapSevenGameConfig, debugOptions: TapSevenDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = TapSevenGeometry(sceneSize: size, config: config)
        logic = TapSevenGameLogic(config: config)
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
        performDebugAutoTapIfNeeded(at: timestamp)
        if logic.state == .submitted, finishReportTime == nil {
            finishReportTime = timestamp + max(0, config.sessionEndHoldDuration)
        }
        if let finishReportTime, timestamp >= finishReportTime {
            reportFinishIfNeeded(at: timestamp)
        }
        syncPresentation(at: timestamp)
        updateDebugOverlay(at: timestamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let timestamp = CACurrentMediaTime()
        guard touches.first != nil else { return }
        handle(logic.handleTap(at: timestamp), at: timestamp)
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause(at: CACurrentMediaTime())
        syncPresentation(at: CACurrentMediaTime())
        isPaused = true
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        autoPlayArmed = true
        logic.resume(at: CACurrentMediaTime())
        if debugOptions.skipStartCue, logic.state == .ready {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    func startSession() {
        isPaused = false
        logic.reset()
        didReportFinish = false
        finishReportTime = nil
        previousFrameTime = nil
        autoPlayArmed = true
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func setupNodes() {
        trackNode.strokeColor = config.trackColor
        trackNode.fillColor = .clear
        trackNode.lineWidth = geometry.strokeWidth
        trackNode.lineCap = .round
        trackNode.zPosition = 1
        trackNode.path = makeFullCirclePath()
        addChild(trackNode)

        progressNode.strokeColor = config.progressColor
        progressNode.fillColor = .clear
        progressNode.lineWidth = geometry.strokeWidth
        progressNode.lineCap = .butt
        progressNode.zPosition = 2
        addChild(progressNode)

        timerLabel.fontSize = geometry.timerFontSize
        timerLabel.fontColor = .white
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .center
        timerLabel.position = geometry.ringCenter
        timerLabel.zPosition = 10
        addChild(timerLabel)

        instructionLabel.fontSize = geometry.instructionFontSize
        instructionLabel.fontColor = .white
        instructionLabel.horizontalAlignmentMode = .center
        instructionLabel.verticalAlignmentMode = .center
        instructionLabel.position = geometry.instructionPosition
        instructionLabel.zPosition = 10
        instructionLabel.numberOfLines = 3
        addChild(instructionLabel)

        resultDetailLabel.fontSize = max(12, geometry.instructionFontSize * 0.78)
        resultDetailLabel.fontColor = UIColor.white.withAlphaComponent(0.78)
        resultDetailLabel.horizontalAlignmentMode = .center
        resultDetailLabel.verticalAlignmentMode = .center
        resultDetailLabel.position = CGPoint(
            x: geometry.instructionPosition.x,
            y: geometry.instructionPosition.y + geometry.instructionFontSize * 1.15
        )
        resultDetailLabel.zPosition = 11
        addChild(resultDetailLabel)

        resultTitleLabel.fontSize = geometry.instructionFontSize * 1.15
        resultTitleLabel.fontColor = .white
        resultTitleLabel.horizontalAlignmentMode = .center
        resultTitleLabel.verticalAlignmentMode = .center
        resultTitleLabel.position = geometry.instructionPosition
        resultTitleLabel.zPosition = 11
        addChild(resultTitleLabel)

        startButtonNode.fillColor = config.startButtonColor
        startButtonNode.strokeColor = .clear
        startButtonNode.zPosition = 3
        startButtonNode.path = CGPath(
            ellipseIn: CGRect(
                x: geometry.startButtonCenter.x - geometry.startButtonRadius,
                y: geometry.startButtonCenter.y - geometry.startButtonRadius,
                width: geometry.startButtonRadius * 2,
                height: geometry.startButtonRadius * 2
            ),
            transform: nil
        )
        addChild(startButtonNode)

        debugBoundsNode.strokeColor = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.85)
        debugBoundsNode.fillColor = .clear
        debugBoundsNode.lineWidth = 1
        debugBoundsNode.path = makeFullCirclePath()
        debugBoundsNode.zPosition = 50
        addChild(debugBoundsNode)

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

    private func handle(_ outcome: TapSevenTapOutcome, at time: TimeInterval) {
        switch outcome {
        case .ignored, .started:
            break
        case .submitted:
            autoPlayArmed = false
            gameDelegate?.tapSevenSceneDidRecordTap(self)
            if config.sessionEndHoldDuration <= 0 {
                finishReportTime = time
            }
        }
        syncPresentation(at: time)
    }

    private func reportFinishIfNeeded(at time: TimeInterval) {
        guard !didReportFinish, let summary = logic.makeSummary(at: time) else { return }
        didReportFinish = true
        logic.markFinished()
        gameDelegate?.tapSevenScene(self, didEndWith: summary)
    }

    private func syncPresentation(at time: TimeInterval) {
        let ready = logic.state == .ready
        let timing = logic.isTiming
        let submitted = logic.state == .submitted || logic.state == .finished
        startButtonNode.isHidden = !ready
        instructionLabel.isHidden = submitted
        resultDetailLabel.isHidden = !submitted
        resultTitleLabel.isHidden = !submitted
        timerLabel.fontColor = ready ? UIColor.white.withAlphaComponent(0.35) : .white
        timerLabel.text = logic.displayedElapsed(at: time)
        if ready {
            instructionLabel.text = "Tap to start,\nthen at 7s"
            instructionLabel.fontSize = geometry.instructionFontSize
        } else if timing {
            instructionLabel.text = "TAP AT 7"
            instructionLabel.fontSize = geometry.instructionFontSize
        }
        if let result = logic.result {
            resultDetailLabel.text = "Exact: \(TapSevenFormatter.exactElapsed(result.actualElapsed))"
            if result.isPerfect {
                resultTitleLabel.text = "PERFECT"
            } else {
                resultTitleLabel.text = "By \(TapSevenFormatter.absoluteError(result.absoluteError))"
            }
        }
        updateProgressPath(progress: logic.progress(at: time))
    }

    private func updateProgressPath(progress: Double) {
        let clamped = min(max(progress, 0), 1)
        progressNode.isHidden = clamped <= 0
        if clamped >= 1 {
            progressNode.path = makeFullCirclePath()
            progressNode.lineCap = .round
            return
        }
        guard clamped > 0 else { return }
        let path = CGMutablePath()
        let start = CGFloat.pi / 2
        let end = start - 2 * .pi * CGFloat(clamped)
        path.addArc(
            center: geometry.ringCenter,
            radius: geometry.ringRadius,
            startAngle: start,
            endAngle: end,
            clockwise: true
        )
        progressNode.lineCap = .butt
        progressNode.path = path
    }

    private func makeFullCirclePath() -> CGPath {
        CGPath(
            ellipseIn: CGRect(
                x: geometry.ringCenter.x - geometry.ringRadius,
                y: geometry.ringCenter.y - geometry.ringRadius,
                width: geometry.ringRadius * 2,
                height: geometry.ringRadius * 2
            ),
            transform: nil
        )
    }

    private func performDebugAutoTapIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard autoPlayArmed,
              logic.isTiming,
              let offset = debugOptions.autoTapOffset,
              let start = logic.startTimestamp else { return }
        let tapTime = start + config.resolvedTargetDuration + offset
        guard time >= tapTime else { return }
        autoPlayArmed = false
        handle(logic.handleTap(at: tapTime), at: tapTime)
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        debugBoundsNode.isHidden = !debugOptions.showGeometry
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showOverlay else { return }
        let elapsed = logic.elapsed(at: time)
        let signed = TapSevenScoring.signedError(elapsed: elapsed, target: config.resolvedTargetDuration)
        debugLabel.text = """
        Target: \(String(format: "%.3f", config.resolvedTargetDuration))s
        Raw elapsed: \(String(format: "%.6f", elapsed))s
        Displayed: \(logic.displayedElapsed(at: time))
        Signed error: \(String(format: "%+.6f", logic.result?.signedError ?? signed))s
        Absolute error: \(String(format: "%.6f", logic.result?.absoluteError ?? abs(signed)))s
        Ring progress: \(String(format: "%.3f", logic.progress(at: time)))
        State: \(String(describing: logic.state))
        Start: \(logic.startTimestamp.map { String(format: "%.6f", $0) } ?? "–")
        Tap: \(logic.tapTimestamp.map { String(format: "%.6f", $0) } ?? "–")
        Perfect threshold: \(String(format: "%.6f", config.resolvedPerfectThreshold))s
        FPS: \(String(format: "%.0f", measuredFPS))
        """
    }
}
