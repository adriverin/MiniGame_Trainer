import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol TimesUpGameSceneDelegate: AnyObject {
    func timesUpSceneDidRecordEstimate(_ scene: TimesUpGameScene)
    func timesUpScene(_ scene: TimesUpGameScene, didScore result: TimesUpLevelResult)
    func timesUpScene(_ scene: TimesUpGameScene, didEndWith summary: TimesUpSessionSummary)
}

@MainActor
final class TimesUpGameScene: SKScene {
    let logic: TimesUpGameLogic
    let config: TimesUpGameConfig
    let geometry: TimesUpGeometry
    weak var gameDelegate: TimesUpGameSceneDelegate?

    var debugOptions: TimesUpDebugOptions {
        didSet { updateDebugVisibility() }
    }

    private let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let readyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let containerNode: SKShapeNode
    private let cropNode = SKCropNode()
    private let maskNode = SKShapeNode()
    private let fillNode: SKSpriteNode
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private let debugBoundsNode = SKShapeNode()

    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var didReportFinish = false
    private var autoPlayArmed = true

    init(size: CGSize, config: TimesUpGameConfig, debugOptions: TimesUpDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = TimesUpGeometry(sceneSize: size, config: config)
        logic = TimesUpGameLogic(config: config)
        containerNode = SKShapeNode(rect: geometry.barFrame, cornerRadius: geometry.cornerRadius)
        fillNode = SKSpriteNode(texture: Self.makeFillTexture(size: geometry.barFrame.size, config: config))
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
        syncPresentation(at: timestamp)
        updateDebugOverlay(at: timestamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let timestamp = CACurrentMediaTime()
        guard touches.count == 1 else { return }
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
        previousFrameTime = nil
        autoPlayArmed = true
        if debugOptions.skipStartCue || !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    func startNextLevel() {
        autoPlayArmed = true
        logic.startNextLevel(at: CACurrentMediaTime())
        syncPresentation(at: CACurrentMediaTime())
    }

    private func setupNodes() {
        instructionLabel.text = "TAP WHEN YOU THINK IT ENDS"
        instructionLabel.fontSize = max(16, size.width * 0.048)
        instructionLabel.fontColor = .white
        instructionLabel.position = geometry.instructionPosition
        instructionLabel.zPosition = 10
        addChild(instructionLabel)

        readyLabel.text = "Tap to start"
        readyLabel.fontSize = max(22, size.width * 0.062)
        readyLabel.fontColor = .white
        readyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        readyLabel.zPosition = 20
        addChild(readyLabel)

        containerNode.fillColor = config.containerColor
        containerNode.strokeColor = .clear
        containerNode.zPosition = 2
        addChild(containerNode)

        maskNode.fillColor = .white
        maskNode.strokeColor = .clear
        cropNode.maskNode = maskNode
        cropNode.zPosition = 3
        fillNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        fillNode.size = geometry.barFrame.size
        fillNode.position = CGPoint(x: geometry.barFrame.midX, y: geometry.barFrame.midY)
        cropNode.addChild(fillNode)
        addChild(cropNode)

        debugBoundsNode.strokeColor = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.85)
        debugBoundsNode.fillColor = .clear
        debugBoundsNode.lineWidth = 1
        debugBoundsNode.path = CGPath(
            roundedRect: geometry.barFrame,
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
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

    private func handle(_ outcome: TimesUpTapOutcome, at time: TimeInterval) {
        switch outcome {
        case .ignored, .started:
            break
        case .scored(let result):
            autoPlayArmed = false
            gameDelegate?.timesUpSceneDidRecordEstimate(self)
            gameDelegate?.timesUpScene(self, didScore: result)
        case .finished(let result):
            autoPlayArmed = false
            gameDelegate?.timesUpSceneDidRecordEstimate(self)
            gameDelegate?.timesUpScene(self, didScore: result)
            if !didReportFinish {
                didReportFinish = true
                gameDelegate?.timesUpScene(self, didEndWith: logic.makeSummary(at: time))
            }
        }
        syncPresentation(at: time)
    }

    private func syncPresentation(at time: TimeInterval) {
        let timing = logic.isTiming
        let ready = logic.state == .ready
        readyLabel.isHidden = !ready
        instructionLabel.isHidden = !timing
        let visible = logic.isBarVisible(at: time)
        containerNode.isHidden = !visible
        cropNode.isHidden = !visible
        if visible {
            let height = max(0.5, geometry.barFrame.height * CGFloat(logic.progress(at: time)))
            let fillFrame = CGRect(
                x: geometry.barFrame.minX,
                y: geometry.barFrame.minY,
                width: geometry.barFrame.width,
                height: height
            )
            maskNode.path = CGPath(
                roundedRect: fillFrame,
                cornerWidth: geometry.cornerRadius,
                cornerHeight: geometry.cornerRadius,
                transform: nil
            )
        }
        fillNode.removeAllActions()
        containerNode.removeAllActions()
        cropNode.removeAllActions()
        instructionLabel.removeAllActions()
    }

    private func performDebugAutoTapIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard autoPlayArmed,
              logic.isTiming,
              let signed = debugOptions.signedError(forLevelIndex: logic.currentLevelIndex),
              let start = logic.levelStartTimestamp else { return }
        let tapTime = start + logic.currentTargetDuration + signed
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
        let last = logic.results.last
        let average = TimesUpScoring.averageAbsoluteError(logic.results)
        debugLabel.text = """
        Level: \(logic.currentLevelNumber) / \(config.resolvedLevelCount)
        Target: \(String(format: "%.3f", logic.currentTargetDuration))s
        Elapsed: \(String(format: "%.3f", logic.elapsed(at: time)))s
        Remaining: \(String(format: "%.3f", logic.remaining(at: time)))s
        Visible until: \(String(format: "%.3f", logic.currentVisibleDuration))s
        State: \(String(describing: logic.state))
        Last signed: \(last.map { String(format: "%+.3f", $0.signedError) } ?? "–")
        Last abs: \(last.map { String(format: "%.3f", $0.absoluteError) } ?? "–")
        Average: \(String(format: "%.3f", average))s
        Clock: \(String(format: "%.3f", time))
        FPS: \(String(format: "%.0f", measuredFPS))
        """
    }

    private static func makeFillTexture(size: CGSize, config: TimesUpGameConfig) -> SKTexture {
        let pixelSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        let image = renderer.image { context in
            let colors = [config.fillTopColor.cgColor, config.fillBottomColor.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: pixelSize.width / 2, y: pixelSize.height),
                end: CGPoint(x: pixelSize.width / 2, y: 0),
                options: []
            )
        }
        return SKTexture(image: image)
    }
}
