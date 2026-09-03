import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol SwipeFastGameSceneDelegate: AnyObject {
    func swipeFastSceneDidScore(_ scene: SwipeFastGameScene)
    func swipeFastSceneDidFail(_ scene: SwipeFastGameScene)
    func swipeFastScene(_ scene: SwipeFastGameScene, didEndWith summary: SwipeFastSessionSummary)
}

@MainActor
final class SwipeFastGameScene: SKScene {
    let logic: SwipeFastGameLogic
    let config: SwipeFastGameConfig
    let geometry: SwipeFastGeometry
    weak var gameDelegate: SwipeFastGameSceneDelegate?

    var debugOptions: SwipeFastDebugOptions {
        didSet { applyDebugOverrides(); updateDebugVisibility() }
    }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let readyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var boxNodes: [SKShapeNode] = []
    private var arrowNodes: [SKShapeNode] = []
    private var barNodes: [SKShapeNode] = []
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var debugBoxNodes: [SKShapeNode] = []

    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var activeTouch: UITouch?
    private var lastAutoPlayTime: TimeInterval = 0

    init(size: CGSize, config: SwipeFastGameConfig, debugOptions: SwipeFastDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = SwipeFastGeometry(sceneSize: size, config: config)
        logic = SwipeFastGameLogic(
            config: config,
            sceneSize: size,
            seed: debugOptions.seed ?? config.generatorSeed
        )
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        setupNodes()
        applyDebugOverrides()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if !config.requiresTapToStart {
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
        performDebugAutoPlayIfNeeded(at: timestamp)
        if logic.isFinished, finishReportTime == nil {
            finishReportTime = timestamp + config.sessionEndHoldDuration
            gameDelegate?.swipeFastSceneDidFail(self)
        }
        if logic.isFinished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.swipeFastScene(self, didEndWith: logic.makeSummary(at: timestamp))
        }
        syncPresentation(at: timestamp)
        updateDebugOverlay(at: timestamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let timestamp = CACurrentMediaTime()
        if logic.state == .ready {
            logic.start(at: timestamp)
            syncPresentation(at: timestamp)
            return
        }
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        _ = logic.beginGesture(at: touch.location(in: self), time: timestamp)
        syncPresentation(at: timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        logic.moveGesture(at: activeTouch.location(in: self), time: CACurrentMediaTime())
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        handle(logic.endGesture(at: activeTouch.location(in: self), time: CACurrentMediaTime()))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        logic.cancelGesture()
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
        lastAutoPlayTime = 0
        applyDebugOverrides()
        logic.resume(at: CACurrentMediaTime())
        if logic.state == .ready, !config.requiresTapToStart {
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
        lastAutoPlayTime = 0
        logic.reset()
        applyDebugOverrides()
        if !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func setupNodes() {
        for index in SwipeFastBoxIndex.allCases {
            let frame = geometry.frame(for: index)
            let box = SKShapeNode(rect: frame, cornerRadius: geometry.cornerRadius)
            box.fillColor = config.boxColor
            box.strokeColor = .clear
            box.zPosition = 2
            addChild(box)
            boxNodes.append(box)

            let arrow = SKShapeNode(path: SwipeFastArrowPath.make(size: CGSize(width: geometry.arrowSize, height: geometry.arrowSize)))
            arrow.fillColor = config.arrowColor
            arrow.strokeColor = .clear
            arrow.zPosition = 4
            arrow.position = geometry.arrowCenter(for: index)
            addChild(arrow)
            arrowNodes.append(arrow)

            let bar = SKShapeNode()
            bar.strokeColor = .clear
            bar.zPosition = 5
            addChild(bar)
            barNodes.append(bar)

            let debugBox = SKShapeNode(rect: frame, cornerRadius: geometry.cornerRadius)
            debugBox.fillColor = .clear
            debugBox.strokeColor = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.85)
            debugBox.lineWidth = 1
            debugBox.zPosition = 50
            addChild(debugBox)
            debugBoxNodes.append(debugBox)
        }

        scoreLabel.fontSize = geometry.scoreFontSize
        scoreLabel.fontColor = .white
        scoreLabel.position = geometry.scorePosition
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        readyLabel.text = "Tap to start"
        readyLabel.fontSize = max(22, size.width * 0.062)
        readyLabel.fontColor = .white
        readyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        readyLabel.zPosition = 20
        addChild(readyLabel)

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

    private func handle(_ outcome: SwipeFastInputOutcome) {
        switch outcome {
        case .correct:
            gameDelegate?.swipeFastSceneDidScore(self)
        case .wrong where logic.isFinished:
            gameDelegate?.swipeFastSceneDidFail(self)
        case .expired:
            gameDelegate?.swipeFastSceneDidFail(self)
        default:
            break
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func syncPresentation(at time: TimeInterval) {
        readyLabel.isHidden = logic.state != .ready
        scoreLabel.text = "\(logic.score)"
        scoreLabel.alpha = logic.state == .ready ? 0.45 : 1
        for index in SwipeFastBoxIndex.allCases {
            let box = logic.box(index)
            let fraction = box.remainingFraction(at: time)
            let stage = config.barStage(remainingFraction: fraction)
            arrowNodes[index.rawValue].zRotation = SwipeFastArrowPath.rotation(for: box.direction)
            arrowNodes[index.rawValue].isHidden = logic.state == .ready && config.requiresTapToStart
            let barRect = geometry.barFrame(for: index, remainingFraction: logic.state == .playing ? fraction : 1)
            barNodes[index.rawValue].path = CGPath(
                roundedRect: barRect,
                cornerWidth: barRect.height / 2,
                cornerHeight: barRect.height / 2,
                transform: nil
            )
            barNodes[index.rawValue].fillColor = config.barColor(for: logic.state == .playing ? stage : .cyan)
            barNodes[index.rawValue].isHidden = logic.state == .gameOver
        }
    }

    private func applyDebugOverrides() {
        logic.forcedDirections = debugOptions.forcedDirections
        logic.scoreOverride = debugOptions.forcedScore
        logic.allowedTimeOverride = debugOptions.allowedTimeOverride
        logic.wrongSwipeBehaviorOverride = debugOptions.wrongSwipeBehavior
    }

    private func performDebugAutoPlayIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard debugOptions.autoPlay, logic.state == .playing else { return }
        if debugOptions.autoPlayExpire {
            let target = debugOptions.expireBox ?? .topLeft
            _ = logic.expire(target, at: time)
            return
        }
        let delay = max(0, debugOptions.autoPlayReactionDelay)
        guard time - lastAutoPlayTime >= delay else { return }
        lastAutoPlayTime = time
        let target = SwipeFastBoxIndex.allCases.min { a, b in
            logic.remainingFraction(of: a, at: time) < logic.remainingFraction(of: b, at: time)
        } ?? .topLeft
        if debugOptions.autoPlayWrong {
            let actual = logic.box(target).direction
            let wrong = SwipeDirection.allCases.first { $0 != actual } ?? .down
            handle(logic.applySwipe(wrong, on: target, at: time))
        } else {
            handle(logic.applySwipe(logic.box(target).direction, on: target, at: time))
        }
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        debugBoxNodes.forEach { $0.isHidden = !debugOptions.showGeometry }
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showOverlay else { return }
        let gesture = logic.activeGesture
        var lines = [
            "Score: \(logic.score)  state: \(logic.state.rawValue)",
            "allowed: \(String(format: "%.3f", logic.allowedTime(forScore: logic.score)))s",
            "fps: \(Int(measuredFPS.rounded()))",
        ]
        for index in SwipeFastBoxIndex.allCases {
            let box = logic.box(index)
            let fraction = box.remainingFraction(at: time)
            lines.append(
                "\(index.label) \(box.direction.rawValue) age \(String(format: "%.3f", box.elapsed(at: time))) T \(String(format: "%.3f", box.allowedTime)) rem \(String(format: "%.0f", fraction * 100))% \(logic.barStage(of: index, at: time).rawValue)"
            )
        }
        if let gesture {
            let dx = gesture.last.x - gesture.start.x
            let dy = gesture.last.y - gesture.start.y
            let classified = logic.classifier.classify(dx: dx, dy: dy, duration: max(0, time - gesture.startedAt))
            lines.append(
                "gesture \(gesture.box.label) dx \(Int(dx)) dy \(Int(dy)) → \(classified?.rawValue ?? "none")"
            )
        } else {
            lines.append("gesture: none")
        }
        debugLabel.text = lines.joined(separator: "\n")
    }
}

enum SwipeFastArrowPath {
    static func make(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        let w = size.width / 2
        let h = size.height / 2
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.72, y: -h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.28, y: -h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.28, y: -h))
        path.addLine(to: CGPoint(x: -w * 0.28, y: -h))
        path.addLine(to: CGPoint(x: -w * 0.28, y: -h * 0.12))
        path.addLine(to: CGPoint(x: -w * 0.72, y: -h * 0.12))
        path.closeSubpath()
        return path
    }

    static func rotation(for direction: SwipeDirection) -> CGFloat {
        switch direction {
        case .up: 0
        case .right: -.pi / 2
        case .down: .pi
        case .left: .pi / 2
        }
    }
}
