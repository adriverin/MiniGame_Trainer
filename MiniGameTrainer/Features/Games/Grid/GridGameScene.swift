import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol GridGameSceneDelegate: AnyObject {
    func gridSceneDidToggle(_ scene: GridGameScene)
    func gridSceneDidSubmit(_ scene: GridGameScene, correct: Bool)
    func gridSceneDidFail(_ scene: GridGameScene)
    func gridScene(_ scene: GridGameScene, didEndWith summary: GridSessionSummary)
}

@MainActor
final class GridGameScene: SKScene {
    let logic: GridGameLogic
    let config: GridGameConfig
    weak var gameDelegate: GridGameSceneDelegate?

    var debugOptions: GridDebugOptions {
        didSet { applyDebugOptions() }
    }

    private var geometry: GridGeometry
    private var cellNodes: [GridCell: SKShapeNode] = [:]
    private let boardLayer = SKNode()
    private let hudLayer = SKNode()
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let timerTrack = SKShapeNode()
    private let timerFill = SKShapeNode()
    private let submitNode = SKShapeNode()
    private let submitLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")
    private var previousFrameTime: TimeInterval?
    private var finishReportTime: TimeInterval?
    private var didReportFinish = false
    private var consumedTouches: Set<ObjectIdentifier> = []
    private var autoCorrectArmed = false

    init(size: CGSize, config: GridGameConfig, debugOptions: GridDebugOptions) {
        self.config = config
        self.debugOptions = debugOptions
        logic = GridGameLogic(config: config, seed: debugOptions.seed)
        geometry = GridGeometry(sceneSize: size, rows: logic.stage.rows, columns: logic.stage.columns, config: config)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = config.backgroundColor
        applyDebugOptions(resetting: false)
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        if children.isEmpty {
            buildScene()
            startSession()
        }
    }

    func startSession() {
        isPaused = false
        previousFrameTime = nil
        finishReportTime = nil
        didReportFinish = false
        consumedTouches.removeAll()
        autoCorrectArmed = false
        logic.reset()
        applyDebugOptions(resetting: false)
        logic.start(at: CACurrentMediaTime())
        rebuildBoardIfNeeded()
        syncPresentation()
    }

    func pauseGame() {
        guard !isPaused, !logic.isFinished else { return }
        logic.pause(at: CACurrentMediaTime())
        isPaused = true
        consumedTouches.removeAll()
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        previousFrameTime = nil
        logic.resume(at: CACurrentMediaTime())
        rebuildBoardIfNeeded()
        syncPresentation()
    }

    func handleInterruption() {
        guard !logic.isFinished else { return }
        logic.restartCurrentRound(at: CACurrentMediaTime())
        consumedTouches.removeAll()
        autoCorrectArmed = false
        rebuildBoardIfNeeded()
        syncPresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        if let previousFrameTime {
            _ = min(max(0, currentTime - previousFrameTime), config.maximumSimulationDelta)
        }
        previousFrameTime = currentTime
        logic.update(at: CACurrentMediaTime())
        handle(logic.drainEvents())
        applyAutoCorrectIfNeeded()
        rebuildBoardIfNeeded()
        syncPresentation()

        if logic.isFinished, let finishReportTime, currentTime >= finishReportTime, !didReportFinish {
            didReportFinish = true
            gameDelegate?.gridScene(self, didEndWith: logic.makeSummary(at: CACurrentMediaTime()))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !logic.isFinished else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard !consumedTouches.contains(id) else { continue }
            consumedTouches.insert(id)
            let point = touch.location(in: self)
            if geometry.submitButtonFrame.contains(point) {
                submitSelection()
                return
            }
            if let cell = geometry.cell(at: point) {
                _ = logic.tapCell(cell)
                handle(logic.drainEvents())
                syncPresentation()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { consumedTouches.remove(ObjectIdentifier(touch)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func buildScene() {
        addChild(boardLayer)
        hudLayer.zPosition = 100
        addChild(hudLayer)

        scoreLabel.fontSize = size.height * 0.07
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = geometry.scorePosition
        hudLayer.addChild(scoreLabel)

        levelLabel.fontSize = size.height * 0.028
        levelLabel.fontColor = UIColor.white.withAlphaComponent(0.88)
        levelLabel.horizontalAlignmentMode = .center
        levelLabel.verticalAlignmentMode = .center
        levelLabel.position = geometry.levelPosition
        hudLayer.addChild(levelLabel)

        timerTrack.fillColor = config.timerTrackColor
        timerTrack.strokeColor = .clear
        hudLayer.addChild(timerTrack)
        timerFill.fillColor = config.timerFillColor
        timerFill.strokeColor = .clear
        hudLayer.addChild(timerFill)

        submitNode.zPosition = 2
        hudLayer.addChild(submitNode)
        submitLabel.fontSize = size.height * 0.028
        submitLabel.fontColor = .white
        submitLabel.horizontalAlignmentMode = .center
        submitLabel.verticalAlignmentMode = .center
        submitLabel.text = "SUBMIT"
        submitLabel.zPosition = 3
        hudLayer.addChild(submitLabel)

        debugLabel.fontSize = 11
        debugLabel.fontColor = AppTheme.UIColors.debugText
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.numberOfLines = 0
        debugLabel.position = CGPoint(x: 10, y: size.height - 58)
        debugLabel.isHidden = true
        hudLayer.addChild(debugLabel)

        layoutChrome()
        rebuildBoardIfNeeded(force: true)
    }

    private func layoutChrome() {
        timerTrack.path = CGPath(roundedRect: geometry.timerBarFrame, cornerWidth: geometry.timerBarFrame.height / 2, cornerHeight: geometry.timerBarFrame.height / 2, transform: nil)
        let radius = geometry.submitButtonFrame.height * config.submitButtonCornerRadiusRatio
        submitNode.path = CGPath(
            roundedRect: geometry.submitButtonFrame,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        submitLabel.position = CGPoint(x: geometry.submitButtonFrame.midX, y: geometry.submitButtonFrame.midY)
        scoreLabel.position = geometry.scorePosition
        levelLabel.position = geometry.levelPosition
    }

    private func rebuildBoardIfNeeded(force: Bool = false) {
        let next = GridGeometry(sceneSize: size, rows: logic.stage.rows, columns: logic.stage.columns, config: config)
        if !force, next.rows == geometry.rows, next.columns == geometry.columns { return }
        geometry = next
        layoutChrome()
        boardLayer.removeAllChildren()
        cellNodes.removeAll()
        for row in 0..<geometry.rows {
            for column in 0..<geometry.columns {
                let cell = GridCell(row: row, column: column)
                let node = SKShapeNode(rect: geometry.frame(for: cell), cornerRadius: geometry.cornerRadius)
                node.lineWidth = 0
                node.fillColor = config.inactiveCellColor
                node.name = "cell-\(row)-\(column)"
                node.isAccessibilityElement = true
                node.accessibilityLabel = "Row \(row + 1) column \(column + 1)"
                boardLayer.addChild(node)
                cellNodes[cell] = node
            }
        }
    }

    private func syncPresentation() {
        let lit = logic.highlightedCells
        for (cell, node) in cellNodes {
            node.fillColor = lit.contains(cell) ? config.activeCellColor : config.inactiveCellColor
            let selected = logic.state == .recalling && logic.selectedCells.contains(cell)
            node.accessibilityLabel = selected
                ? "Row \(cell.row + 1) column \(cell.column + 1), selected"
                : "Row \(cell.row + 1) column \(cell.column + 1)"
        }

        scoreLabel.text = "\(logic.score)"
        levelLabel.text = "LEVEL \(logic.level)"

        let recalling = logic.state == .recalling
        submitNode.fillColor = recalling ? config.submitColor : config.submitDisabledColor
        submitNode.alpha = recalling ? 1 : 0.55
        submitLabel.alpha = recalling ? 1 : 0.55

        let fraction: CGFloat
        if recalling {
            fraction = CGFloat(max(0, min(1, logic.recallRemaining / max(logic.currentRecallTimeout, 0.001))))
        } else {
            fraction = 0
        }
        var fill = geometry.timerBarFrame
        fill.size.width *= fraction
        timerFill.path = CGPath(
            roundedRect: fill,
            cornerWidth: fill.height / 2,
            cornerHeight: fill.height / 2,
            transform: nil
        )
        timerTrack.isHidden = !recalling
        timerFill.isHidden = !recalling || fraction <= 0

        updateDebugOverlay()
    }

    private func submitSelection() {
        let result = logic.submit()
        handle(logic.drainEvents())
        if case .submitted(let correct) = result {
            if correct {
                gameDelegate?.gridSceneDidSubmit(self, correct: true)
            } else {
                gameDelegate?.gridSceneDidFail(self)
            }
        }
        syncPresentation()
    }

    private func handle(_ events: [GridGameEvent]) {
        for event in events {
            switch event {
            case .cellToggled:
                gameDelegate?.gridSceneDidToggle(self)
            case .submitted(let correct):
                if !correct { gameDelegate?.gridSceneDidFail(self) }
            case .timedOut:
                gameDelegate?.gridSceneDidFail(self)
            case .finished:
                finishReportTime = (previousFrameTime ?? CACurrentMediaTime()) + config.resultHoldDuration
            default:
                break
            }
        }
    }

    private func applyAutoCorrectIfNeeded() {
        guard debugOptions.autoCorrect, logic.state == .recalling, !autoCorrectArmed else {
            if logic.state != .recalling { autoCorrectArmed = false }
            return
        }
        autoCorrectArmed = true
        logic.fillCorrectSelectionForDebug()
        submitSelection()
    }

    private func applyDebugOptions(resetting: Bool = true) {
        logic.applyDebugOverrides(
            level: debugOptions.forceLevel,
            rows: debugOptions.forceRows,
            columns: debugOptions.forceColumns,
            targetCount: debugOptions.forceTargetCount,
            presentationDuration: debugOptions.presentationDurationOverride,
            recallTimeout: debugOptions.recallTimeoutOverride,
            forcedPattern: debugOptions.useQualityAssurancePattern ? GridDifficultyModel.qualityAssurancePattern : nil
        )
        debugLabel.isHidden = !debugOptions.showOverlay
        if resetting, logic.state != .ready, !logic.isFinished {
            logic.restartCurrentRound(at: CACurrentMediaTime())
        }
    }

    private func updateDebugOverlay() {
        guard debugOptions.showOverlay else { return }
        let targetsHidden = logic.state == .recalling
        debugLabel.text = [
            "state \(String(describing: logic.state))",
            "level \(logic.level)  score \(logic.score)",
            "grid \(logic.stage.rows)×\(logic.stage.columns)",
            "targets \(logic.targetCells.count)  selected \(logic.selectedCells.count)",
            String(format: "present %.2fs  recall %.2fs", logic.currentPresentationDuration, logic.recallElapsed),
            String(format: "timeout left %.2fs", logic.recallRemaining),
            "seed \(debugOptions.seed.map(String.init) ?? "none")",
            targetsHidden ? "targets hidden during recall" : "targets visible (presentation)",
        ].joined(separator: "\n")
    }
}
