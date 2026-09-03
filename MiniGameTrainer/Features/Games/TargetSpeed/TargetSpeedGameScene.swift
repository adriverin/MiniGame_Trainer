import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol TargetSpeedGameSceneDelegate: AnyObject {
    func targetSpeedSceneDidScore(_ scene: TargetSpeedGameScene)
    func targetSpeedSceneDidMiss(_ scene: TargetSpeedGameScene)
    func targetSpeedSceneDidFail(_ scene: TargetSpeedGameScene)
    func targetSpeedScene(_ scene: TargetSpeedGameScene, didEndWith summary: TargetSpeedSessionSummary)
}

@MainActor
final class TargetSpeedGameScene: SKScene {
    let logic: TargetSpeedGameLogic
    let config: TargetSpeedGameConfig
    let geometry: TargetSpeedGeometry
    weak var gameDelegate: TargetSpeedGameSceneDelegate?

    var debugOptions: TargetSpeedDebugOptions {
        didSet { applyDebugOverrides(); updateDebugVisibility() }
    }

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var heartNodes: [SKShapeNode] = []
    private var targetNodes: [Int: TargetSpeedTargetNode] = [:]
    private var hitboxNodes: [Int: SKShapeNode] = [:]

    private var previousFrameTime: TimeInterval?
    private var measuredFPS = 0.0
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var lastAutoPlayTime: TimeInterval = 0
    private var lastMissCount = 0

    init(size: CGSize, config: TargetSpeedGameConfig, debugOptions: TargetSpeedDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        geometry = TargetSpeedGeometry(sceneSize: size, config: config)
        logic = TargetSpeedGameLogic(
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
        reportMissesIfNeeded()
        performDebugAutoPlayIfNeeded(at: timestamp)
        if logic.isFinished, finishReportTime == nil {
            finishReportTime = timestamp + config.sessionEndHoldDuration
            gameDelegate?.targetSpeedSceneDidFail(self)
        }
        if logic.isFinished,
           let finishReportTime,
           timestamp >= finishReportTime,
           !didReportFinish {
            didReportFinish = true
            gameDelegate?.targetSpeedScene(self, didEndWith: logic.makeSummary(at: timestamp))
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
        guard let touch = touches.first else { return }
        handle(logic.handleTap(at: touch.location(in: self), time: timestamp))
    }

    func pauseGame() {
        guard !isPaused else { return }
        logic.pause(at: CACurrentMediaTime())
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
        lastMissCount = 0
        applyDebugOverrides()
        logic.resume(at: CACurrentMediaTime())
        if logic.state == .ready, !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    func startSession() {
        isPaused = false
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        lastAutoPlayTime = 0
        lastMissCount = 0
        clearTargetNodes()
        logic.reset()
        applyDebugOverrides()
        if !config.requiresTapToStart {
            logic.start(at: CACurrentMediaTime())
        }
        syncPresentation(at: CACurrentMediaTime())
    }

    private func setupNodes() {
        scoreLabel.fontSize = geometry.scoreFontSize
        scoreLabel.fontColor = .white
        scoreLabel.position = geometry.scorePosition
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = 20
        addChild(scoreLabel)

        for index in 0..<config.startingLives {
            let heart = SKShapeNode(path: TargetSpeedHeartPath.make(size: geometry.heartSize))
            heart.fillColor = config.heartColor
            heart.strokeColor = .clear
            heart.position = geometry.heartPosition(index: index)
            heart.zPosition = 20
            addChild(heart)
            heartNodes.append(heart)
        }

        instructionLabel.text = "Tap the targets before they disappear!"
        instructionLabel.fontSize = max(16, size.width * 0.048)
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        instructionLabel.verticalAlignmentMode = .center
        instructionLabel.horizontalAlignmentMode = .center
        instructionLabel.preferredMaxLayoutWidth = size.width * 0.82
        instructionLabel.numberOfLines = 2
        instructionLabel.zPosition = 25
        addChild(instructionLabel)

        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontSize = max(9, size.width * 0.022)
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.position = CGPoint(x: 10, y: size.height - 48)
        debugLabel.zPosition = 100
        addChild(debugLabel)
        updateDebugVisibility()
    }

    private func handle(_ outcome: TargetSpeedInputOutcome) {
        switch outcome {
        case .hit:
            gameDelegate?.targetSpeedSceneDidScore(self)
        case .missed:
            gameDelegate?.targetSpeedSceneDidMiss(self)
        case .gameOver:
            gameDelegate?.targetSpeedSceneDidFail(self)
        case .ignored:
            break
        }
        lastMissCount = logic.misses
        syncPresentation(at: CACurrentMediaTime())
    }

    private func reportMissesIfNeeded() {
        if logic.misses > lastMissCount, !logic.isFinished {
            gameDelegate?.targetSpeedSceneDidMiss(self)
        }
        lastMissCount = logic.misses
    }

    private func syncPresentation(at time: TimeInterval) {
        scoreLabel.text = "\(logic.score)"
        let elapsed = logic.makeSummary(at: time).duration
        instructionLabel.alpha = logic.state == .playing && elapsed < config.instructionOverlayDuration ? 1 : 0
        for (index, heart) in heartNodes.enumerated() {
            heart.alpha = index < logic.lives ? 1 : 0.18
        }

        let visible = logic.visibleTargets(at: time)
        let visibleIDs = Set(visible.map(\.id))
        for (id, node) in targetNodes where !visibleIDs.contains(id) {
            node.removeFromParent()
            targetNodes.removeValue(forKey: id)
            hitboxNodes[id]?.removeFromParent()
            hitboxNodes.removeValue(forKey: id)
        }

        for target in visible {
            let node = targetNodes[target.id] ?? makeTargetNode(for: target)
            targetNodes[target.id] = node
            node.position = target.center
            node.update(target: target, config: config, at: time)
            if debugOptions.showHitboxes {
                let hit = hitboxNodes[target.id] ?? makeHitbox(for: target)
                hitboxNodes[target.id] = hit
                hit.position = target.center
                hit.path = CGPath(
                    ellipseIn: CGRect(
                        x: -max(target.radius, geometry.minimumHitRadius),
                        y: -max(target.radius, geometry.minimumHitRadius),
                        width: max(target.radius, geometry.minimumHitRadius) * 2,
                        height: max(target.radius, geometry.minimumHitRadius) * 2
                    ),
                    transform: nil
                )
                hit.isHidden = false
            } else {
                hitboxNodes[target.id]?.isHidden = true
            }
        }
    }

    private func makeTargetNode(for target: TargetSpeedTargetState) -> TargetSpeedTargetNode {
        let node = TargetSpeedTargetNode(radius: target.radius, config: config, lineWidth: geometry.ringLineWidth)
        node.zPosition = 5
        addChild(node)
        return node
    }

    private func makeHitbox(for target: TargetSpeedTargetState) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = .clear
        node.strokeColor = AppTheme.UIColors.debugHitbox
        node.lineWidth = 1
        node.zPosition = 50
        addChild(node)
        return node
    }

    private func clearTargetNodes() {
        targetNodes.values.forEach { $0.removeFromParent() }
        targetNodes.removeAll()
        hitboxNodes.values.forEach { $0.removeFromParent() }
        hitboxNodes.removeAll()
    }

    private func applyDebugOverrides() {
        logic.scoreOverride = debugOptions.forcedScore
        logic.livesOverride = debugOptions.forcedLives
        logic.radiusOverride = debugOptions.forcedRadius
        logic.positionOverride = debugOptions.forcedPosition
        logic.spawnIntervalOverride = debugOptions.spawnIntervalOverride
        logic.lifetimeOverride = debugOptions.lifetimeOverride
        logic.maxActiveOverride = debugOptions.maxActiveOverride
    }

    private func performDebugAutoPlayIfNeeded(at time: TimeInterval) {
        #if DEBUG
        guard logic.state == .playing else { return }
        if debugOptions.autoMiss {
            if let target = logic.liveTargets(at: time).min(by: { $0.expiresAt < $1.expiresAt }) {
                _ = logic.expire(id: target.id, at: time)
            }
            return
        }
        guard debugOptions.autoHit else { return }
        let delay = max(0, debugOptions.autoPlayReactionDelay)
        guard time - lastAutoPlayTime >= 0.01 else { return }
        let ready = logic.liveTargets(at: time).filter { $0.elapsed(at: time) >= delay }
        guard let target = ready.min(by: { $0.expiresAt < $1.expiresAt }) else { return }
        lastAutoPlayTime = time
        handle(logic.hit(id: target.id, at: time))
        #endif
    }

    private func updateDebugVisibility() {
        debugLabel.isHidden = !debugOptions.showOverlay
        if !debugOptions.showHitboxes {
            hitboxNodes.values.forEach { $0.isHidden = true }
        }
    }

    private func updateDebugOverlay(at time: TimeInterval) {
        guard debugOptions.showOverlay else { return }
        let snap = logic.difficultySnapshot()
        var lines = [
            "Score: \(logic.score)  Lives: \(logic.lives)  state: \(logic.state.rawValue)",
            "elapsed: \(String(format: "%.2f", logic.makeSummary(at: time).duration))s  stage: \(snap.stageIndex)",
            "active: \(logic.liveTargets(at: time).count)/\(snap.maxActive)  next: \(logic.nextSpawnTimestamp.map { String(format: "%.3f", $0 - time) } ?? "-")",
            "interval: \(String(format: "%.3f", snap.spawnInterval))  life: \(String(format: "%.3f", snap.lifetime))",
            "fps: \(Int(measuredFPS.rounded()))",
        ]
        for target in logic.visibleTargets(at: time) {
            lines.append(
                "#\(target.id) r=\(Int(target.radius)) age=\(String(format: "%.2f", target.elapsed(at: time))) rem=\(String(format: "%.2f", target.remaining(at: time))) pts=\(target.pointValue) (\(Int(target.center.x)),\(Int(target.center.y)))"
            )
        }
        debugLabel.text = lines.joined(separator: "\n")
    }
}

@MainActor
final class TargetSpeedTargetNode: SKNode {
    private let outer: SKShapeNode
    private let ring: SKShapeNode
    private let centerDot: SKShapeNode
    private let timer: SKShapeNode
    private let radius: CGFloat
    private let lineWidth: CGFloat

    init(radius: CGFloat, config: TargetSpeedGameConfig, lineWidth: CGFloat) {
        self.radius = radius
        self.lineWidth = lineWidth
        outer = SKShapeNode(circleOfRadius: radius)
        ring = SKShapeNode(circleOfRadius: radius * 0.62)
        centerDot = SKShapeNode(circleOfRadius: radius * 0.28)
        timer = SKShapeNode()
        super.init()
        outer.fillColor = config.targetOuterColor
        outer.strokeColor = .clear
        ring.fillColor = config.targetRingColor
        ring.strokeColor = .clear
        centerDot.fillColor = config.targetOuterColor
        centerDot.strokeColor = .clear
        timer.lineWidth = lineWidth
        timer.lineCap = .round
        timer.fillColor = .clear
        addChild(outer)
        addChild(ring)
        addChild(centerDot)
        addChild(timer)
    }

    required init?(coder aDecoder: NSCoder) { nil }

    func update(target: TargetSpeedTargetState, config: TargetSpeedGameConfig, at time: TimeInterval) {
        let remaining = target.remainingFraction(at: time)
        let stage = config.ringStage(remainingFraction: remaining)
        if let missedAt = target.missedAt {
            let fade = 1 - min(max((time - missedAt) / config.missFadeDuration, 0), 1)
            alpha = 0.18 + 0.22 * fade
            timer.alpha = 0
        } else if remaining <= config.fadeWarningFraction {
            let warning = remaining / max(config.fadeWarningFraction, 0.001)
            alpha = 0.28 + 0.72 * warning
            timer.strokeColor = config.ringColor(for: stage)
            timer.alpha = 1
        } else {
            alpha = 1
            timer.strokeColor = config.ringColor(for: stage)
            timer.alpha = 1
        }
        timer.path = TargetSpeedRingPath.arc(radius: radius + lineWidth, remaining: remaining)
    }
}

enum TargetSpeedRingPath {
    static func arc(radius: CGFloat, remaining: Double) -> CGPath {
        let path = CGMutablePath()
        let start = CGFloat.pi / 2
        let sweep = CGFloat(min(max(remaining, 0), 1)) * CGFloat.pi * 2
        if sweep <= 0.001 { return path }
        path.addArc(center: .zero, radius: radius, startAngle: start, endAngle: start - sweep, clockwise: true)
        return path
    }
}

enum TargetSpeedHeartPath {
    static func make(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let w = size
        let h = size
        path.move(to: CGPoint(x: 0, y: -h * 0.32))
        path.addCurve(
            to: CGPoint(x: -w * 0.48, y: h * 0.08),
            control1: CGPoint(x: -w * 0.18, y: -h * 0.08),
            control2: CGPoint(x: -w * 0.50, y: -h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.42),
            control1: CGPoint(x: -w * 0.48, y: h * 0.36),
            control2: CGPoint(x: -w * 0.16, y: h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.48, y: h * 0.08),
            control1: CGPoint(x: w * 0.16, y: h * 0.42),
            control2: CGPoint(x: w * 0.48, y: h * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -h * 0.32),
            control1: CGPoint(x: w * 0.50, y: -h * 0.08),
            control2: CGPoint(x: w * 0.18, y: -h * 0.08)
        )
        path.closeSubpath()
        return path
    }
}
