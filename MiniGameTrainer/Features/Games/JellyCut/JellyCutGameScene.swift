import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol JellyCutGameSceneDelegate: AnyObject {
    func jellyCutScene(_ scene: JellyCutGameScene, didCutWithAccuracy accuracy: Double)
    func jellyCutScene(_ scene: JellyCutGameScene, didEndWith summary: JellyCutSessionSummary)
}

@MainActor
final class JellyCutGameScene: SKScene {
    private enum Palette {
        static let pinkTop = UIColor(red: 1.00, green: 0.20, blue: 0.58, alpha: 1)
        static let pinkBottom = UIColor(red: 0.73, green: 0.025, blue: 0.35, alpha: 1)
        static let jellyTop = UIColor(red: 0.26, green: 1.00, blue: 0.72, alpha: 1)
        static let jellyBottom = UIColor(red: 0.04, green: 0.82, blue: 0.52, alpha: 1)
        static let jellyOutline = UIColor(red: 0.01, green: 0.55, blue: 0.39, alpha: 1)
        static let remainderTop = UIColor(red: 1.00, green: 0.82, blue: 0.25, alpha: 1)
        static let remainderBottom = UIColor(red: 1.00, green: 0.58, blue: 0.08, alpha: 1)
        static let remainderOutline = UIColor(red: 0.89, green: 0.39, blue: 0.04, alpha: 1)
        static let target = UIColor(red: 1.00, green: 0.90, blue: 0.20, alpha: 1)
    }

    weak var gameDelegate: JellyCutGameSceneDelegate?
    private(set) var logic: JellyCutGameLogic
    let config: JellyCutConfig

    private let jellyLayer = SKNode()
    private let effectsLayer = SKNode()
    private let interfaceLayer = SKNode()
    private let roundLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let targetLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let guideNode = SKShapeNode()
    private let startHandle = SKShapeNode(circleOfRadius: 4.5)
    private let endHandle = SKShapeNode(circleOfRadius: 4.5)

    private var gestureStart: CGPoint?
    private var gestureCurrent: CGPoint?
    private var jellyCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.48) }
    private var jellyWidth: CGFloat { min(size.width * config.jellyWidthRatio, size.height * 0.36) }
    private var jellyHeight: CGFloat { min(size.width * 0.64, size.height * config.jellyHeightRatio) }

    init(size: CGSize, config: JellyCutConfig) {
        self.config = config
        var random = SystemRandomNumberGenerator()
        let shapes = JellyCutGameScene.scaledShapes(
            JellyShapeGenerator.sessionShapes(pointCount: config.boundaryPointCount, using: &random),
            width: min(size.width * config.jellyWidthRatio, size.height * 0.36),
            height: min(size.width * 0.64, size.height * config.jellyHeightRatio)
        )
        logic = JellyCutGameLogic(shapes: shapes, config: config, startTime: CACurrentMediaTime())
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = Palette.pinkBottom
        setupScene()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        showRound()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard logic.isInputEnabled, let point = touches.first?.location(in: self) else { return }
        gestureStart = point
        gestureCurrent = point
        hideGuide()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard logic.isInputEnabled, let start = gestureStart,
              let point = touches.first?.location(in: self) else { return }
        gestureCurrent = point
        if hypot(point.x - start.x, point.y - start.y) >= 6 {
            showGuide(from: start, to: point)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = gestureStart else { return }
        let end = touches.first?.location(in: self) ?? gestureCurrent ?? start
        gestureStart = nil
        gestureCurrent = nil
        commitGesture(from: start, to: end)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        gestureStart = nil
        gestureCurrent = nil
        hideGuide()
    }

    func pauseGame() {
        guard !isPaused, logic.state != .finished else { return }
        hideGuide()
        gestureStart = nil
        gestureCurrent = nil
        logic.pause(at: CACurrentMediaTime())
        isPaused = true
    }

    func resumeGame() {
        guard isPaused else { return }
        isPaused = false
        logic.resume(at: CACurrentMediaTime())
    }

    func startSession() {
        removeAllActions()
        isPaused = false
        var random = SystemRandomNumberGenerator()
        let shapes = Self.scaledShapes(
            JellyShapeGenerator.sessionShapes(pointCount: config.boundaryPointCount, using: &random),
            width: jellyWidth,
            height: jellyHeight
        )
        logic = JellyCutGameLogic(shapes: shapes, config: config, startTime: CACurrentMediaTime())
        gestureStart = nil
        gestureCurrent = nil
        effectsLayer.removeAllChildren()
        interfaceLayer.childNode(withName: "summary")?.removeFromParent()
        showRound()
    }

    private func setupScene() {
        let background = SKSpriteNode(texture: gradientTexture(
            size: size, top: Palette.pinkTop, bottom: Palette.pinkBottom
        ))
        background.anchorPoint = .zero
        background.position = .zero
        background.zPosition = -100
        addChild(background)

        jellyLayer.zPosition = 10
        effectsLayer.zPosition = 30
        interfaceLayer.zPosition = 50
        addChild(jellyLayer)
        addChild(effectsLayer)
        addChild(interfaceLayer)

        roundLabel.fontSize = max(12, size.width * 0.035)
        roundLabel.fontColor = UIColor.white.withAlphaComponent(0.72)
        roundLabel.horizontalAlignmentMode = .center
        roundLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.825)
        interfaceLayer.addChild(roundLabel)

        instructionLabel.fontSize = max(28, size.width * 0.083)
        instructionLabel.fontColor = .white
        instructionLabel.horizontalAlignmentMode = .center
        instructionLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        interfaceLayer.addChild(instructionLabel)

        targetLabel.fontSize = max(19, size.width * 0.055)
        targetLabel.fontColor = Palette.target
        targetLabel.horizontalAlignmentMode = .center
        targetLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.715)
        interfaceLayer.addChild(targetLabel)

        guideNode.strokeColor = .white
        guideNode.lineWidth = 1.7
        guideNode.zPosition = 80
        interfaceLayer.addChild(guideNode)
        for handle in [startHandle, endHandle] {
            handle.fillColor = .white
            handle.strokeColor = UIColor.white.withAlphaComponent(0.4)
            handle.lineWidth = 2
            handle.zPosition = 81
            handle.isHidden = true
            interfaceLayer.addChild(handle)
        }
    }

    private func showRound() {
        jellyLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        hideGuide()
        interfaceLayer.childNode(withName: "summary")?.removeFromParent()
        roundLabel.isHidden = false
        instructionLabel.isHidden = false
        targetLabel.isHidden = false
        roundLabel.text = "ROUND \(logic.currentRoundIndex + 1) OF 3"
        instructionLabel.text = logic.currentRound.title
        targetLabel.text = logic.currentRound.displayTarget

        let shadow = SKShapeNode(ellipseOf: CGSize(width: jellyWidth * 0.62, height: jellyHeight * 0.12))
        shadow.fillColor = UIColor(red: 0.30, green: 0.00, blue: 0.22, alpha: 0.32)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: jellyCenter.x, y: jellyCenter.y - jellyHeight * 0.62)
        shadow.zPosition = -1
        jellyLayer.addChild(shadow)

        let jelly = makePieceNode(polygon: logic.currentShape, targetPiece: true, label: nil)
        jelly.position = jellyCenter
        jelly.alpha = 0
        jelly.setScale(0.96)
        jellyLayer.addChild(jelly)
        jelly.run(.group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.22)]))

        #if DEBUG
        scheduleDebugCutIfNeeded()
        #endif
    }

    private func commitGesture(from start: CGPoint, to end: CGPoint) {
        hideGuide()
        let localStart = CGPoint(x: start.x - jellyCenter.x, y: start.y - jellyCenter.y)
        let localEnd = CGPoint(x: end.x - jellyCenter.x, y: end.y - jellyCenter.y)
        switch logic.commitCut(start: localStart, end: localEnd, at: CACurrentMediaTime()) {
        case .invalid:
            break
        case .scored(let result):
            gameDelegate?.jellyCutScene(self, didCutWithAccuracy: result.accuracy)
            render(result: result, gestureStart: start, gestureEnd: end)
        }
    }

    private func render(result: JellyCutRoundResult, gestureStart: CGPoint, gestureEnd: CGPoint) {
        jellyLayer.children.filter { $0.zPosition >= 0 }.forEach { $0.removeFromParent() }
        let displayed = JellyCutScoring.displayedPercentages(result.fractions)
        let separation = jellyWidth * config.separationWidthRatio
        let normal = result.line.normal

        for index in 0..<2 {
            let piece = makePieceNode(
                polygon: result.pieces[index],
                targetPiece: index == result.targetPieceIndex,
                label: String(format: "%.1f%%", displayed[index])
            )
            piece.position = jellyCenter
            jellyLayer.addChild(piece)
            let sign: CGFloat = index == 0 ? -1 : 1
            let movement = CGVector(
                dx: normal.dx * separation * sign,
                dy: normal.dy * separation * sign
            )
            let move = SKAction.move(by: movement, duration: config.cutAnimationDuration)
            move.timingMode = .easeOut
            piece.run(move)
            if let label = piece.childNode(withName: "percentage") {
                label.alpha = 0
                label.run(.sequence([.wait(forDuration: 0.10), .fadeIn(withDuration: 0.16)]))
            }
        }

        showResolvedCutLine(from: gestureStart, to: gestureEnd)
        emitConfetti(near: cutCenter(for: result))
        #if DEBUG
        if debugShouldHold(round: result.round, stage: "result") { return }
        #endif
        run(.sequence([
            .wait(forDuration: config.resultHoldDuration),
            .run { [weak self] in
                guard let self else { return }
                self.logic.advanceAfterResult()
                if self.logic.state == .active { self.showRound() }
                else if self.logic.state == .summary { self.showSummary() }
            },
        ]), withKey: "roundTransition")
    }

    private func makePieceNode(polygon: [CGPoint], targetPiece: Bool, label: String?) -> SKNode {
        let container = SKNode()
        let path = polygonPath(polygon)
        let crop = SKCropNode()
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let top = targetPiece ? Palette.jellyTop : Palette.remainderTop
        let bottom = targetPiece ? Palette.jellyBottom : Palette.remainderBottom
        let fill = SKSpriteNode(texture: gradientTexture(
            size: CGSize(width: jellyWidth * 1.1, height: jellyHeight * 1.1),
            top: top, bottom: bottom
        ))
        fill.size = CGSize(width: jellyWidth * 1.1, height: jellyHeight * 1.1)
        crop.addChild(fill)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: jellyWidth * 0.25, height: jellyHeight * 0.12))
        highlight.fillColor = UIColor.white.withAlphaComponent(targetPiece ? 0.26 : 0.18)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -jellyWidth * 0.19, y: jellyHeight * 0.24)
        highlight.zRotation = 0.25
        crop.addChild(highlight)
        container.addChild(crop)

        let outline = SKShapeNode(path: path)
        outline.fillColor = .clear
        outline.strokeColor = targetPiece ? Palette.jellyOutline : Palette.remainderOutline
        outline.lineWidth = max(3, jellyWidth * 0.016)
        outline.lineJoin = .round
        outline.lineCap = .round
        container.addChild(outline)

        if let label {
            let percentage = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            percentage.name = "percentage"
            percentage.text = label
            percentage.fontSize = max(17, size.width * 0.052)
            percentage.fontColor = .white
            percentage.horizontalAlignmentMode = .center
            percentage.verticalAlignmentMode = .center
            percentage.position = JellyPolygonGeometry.centroid(of: polygon)
            percentage.zPosition = 8
            let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            shadow.text = label
            shadow.fontSize = percentage.fontSize
            shadow.fontColor = UIColor.black.withAlphaComponent(0.28)
            shadow.horizontalAlignmentMode = .center
            shadow.verticalAlignmentMode = .center
            shadow.position = CGPoint(x: 1.5, y: -2)
            shadow.zPosition = -1
            percentage.addChild(shadow)
            container.addChild(percentage)
        }
        return container
    }

    private func showGuide(from start: CGPoint, to end: CGPoint) {
        guard let line = JellyCutLine(start: start, end: end) else { hideGuide(); return }
        let span = hypot(size.width, size.height) * 1.5
        let from = CGPoint(x: line.point.x - line.direction.dx * span, y: line.point.y - line.direction.dy * span)
        let to = CGPoint(x: line.point.x + line.direction.dx * span, y: line.point.y + line.direction.dy * span)
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        guideNode.path = path.copy(dashingWithPhase: 0, lengths: [7, 6])
        guideNode.isHidden = false
        startHandle.position = start
        endHandle.position = end
        startHandle.isHidden = false
        endHandle.isHidden = false
    }

    private func hideGuide() {
        guideNode.isHidden = true
        guideNode.path = nil
        startHandle.isHidden = true
        endHandle.isHidden = true
    }

    private func showResolvedCutLine(from start: CGPoint, to end: CGPoint) {
        showGuide(from: start, to: end)
        startHandle.isHidden = true
        endHandle.isHidden = true
        guideNode.run(.sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.20), .run { [weak self] in
            self?.guideNode.alpha = 1
            self?.hideGuide()
        }]))
    }

    private func emitConfetti(near point: CGPoint) {
        let colors: [UIColor] = [.white, Palette.target, .systemTeal, .systemOrange, .systemPurple]
        for index in 0..<18 {
            let particle = SKShapeNode(rectOf: CGSize(width: 4, height: 8), cornerRadius: 1)
            particle.fillColor = colors[index % colors.count]
            particle.strokeColor = .clear
            particle.position = point
            particle.zRotation = CGFloat(index) * 0.73
            effectsLayer.addChild(particle)
            let angle = CGFloat(index) / 18 * 2 * .pi + CGFloat(index % 3) * 0.17
            let distance = jellyWidth * (0.16 + CGFloat(index % 5) * 0.025)
            let motion = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.55)
            motion.timingMode = .easeOut
            particle.run(.sequence([
                .group([motion, .rotate(byAngle: CGFloat.pi * 1.5, duration: 0.55), .fadeOut(withDuration: 0.55)]),
                .removeFromParent(),
            ]))
        }
    }

    private func cutCenter(for result: JellyCutRoundResult) -> CGPoint {
        guard !result.pieces.isEmpty else { return jellyCenter }
        let centers = result.pieces.map { JellyPolygonGeometry.centroid(of: $0) }
        return CGPoint(
            x: jellyCenter.x + centers.reduce(0) { $0 + $1.x } / CGFloat(centers.count),
            y: jellyCenter.y + centers.reduce(0) { $0 + $1.y } / CGFloat(centers.count)
        )
    }

    private func showSummary() {
        roundLabel.isHidden = true
        instructionLabel.isHidden = true
        targetLabel.isHidden = true
        let node = SKNode()
        node.name = "summary"
        node.zPosition = 100
        let width = min(size.width * 0.82, 360)
        let height: CGFloat = 194
        let card = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 22)
        card.fillColor = UIColor(red: 0.18, green: 0.03, blue: 0.18, alpha: 0.90)
        card.strokeColor = UIColor.white.withAlphaComponent(0.13)
        card.lineWidth = 1
        node.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "YOUR PRECISION"
        title.fontSize = 18
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 63)
        node.addChild(title)

        for (index, result) in logic.results.enumerated() {
            addSummaryRow(
                to: node,
                label: result.round.shortName,
                value: String(format: "%.1f%%", result.accuracy),
                y: 27 - CGFloat(index) * 31,
                width: width,
                emphasized: false
            )
        }
        addSummaryRow(
            to: node,
            label: "Average",
            value: String(format: "%.1f%%", logic.results.reduce(0) { $0 + $1.accuracy } / 3),
            y: -72,
            width: width,
            emphasized: true
        )
        node.position = CGPoint(x: size.width / 2, y: size.height * 0.39)
        node.alpha = 0
        node.setScale(0.96)
        interfaceLayer.addChild(node)
        node.run(.group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.22)]))

        #if DEBUG
        if debugHoldStage == "summary" { return }
        #endif
        run(.sequence([
            .wait(forDuration: config.summaryHoldDuration),
            .run { [weak self] in
                guard let self else { return }
                self.logic.finish(at: CACurrentMediaTime())
                self.gameDelegate?.jellyCutScene(self, didEndWith: self.logic.summary(at: CACurrentMediaTime()))
            },
        ]), withKey: "summaryTransition")
    }

    private func addSummaryRow(
        to node: SKNode, label: String, value: String, y: CGFloat, width: CGFloat, emphasized: Bool
    ) {
        let left = SKLabelNode(fontNamed: emphasized ? "AvenirNext-Bold" : "AvenirNext-DemiBold")
        left.text = label
        left.fontSize = emphasized ? 17 : 15
        left.fontColor = emphasized ? .white : UIColor.white.withAlphaComponent(0.76)
        left.horizontalAlignmentMode = .left
        left.position = CGPoint(x: -width / 2 + 24, y: y)
        node.addChild(left)
        let right = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        right.text = value
        right.fontSize = emphasized ? 23 : 16
        right.fontColor = Palette.target
        right.horizontalAlignmentMode = .right
        right.position = CGPoint(x: width / 2 - 24, y: y)
        node.addChild(right)
    }

    private func polygonPath(_ polygon: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = polygon.first else { return path }
        path.move(to: first)
        for point in polygon.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func gradientTexture(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(
            width: max(1, size.width), height: max(1, size.height)
        ))
        let image = renderer.image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: max(1, size.height)),
                end: .zero,
                options: []
            )
        }
        return SKTexture(image: image)
    }

    private static func scaledShapes(_ shapes: [[CGPoint]], width: CGFloat, height: CGFloat) -> [[CGPoint]] {
        shapes.map { polygon in
            polygon.map { CGPoint(x: $0.x * width, y: $0.y * height) }
        }
    }

    #if DEBUG
    private func scheduleDebugCutIfNeeded() {
        guard CommandLine.arguments.contains("-jellyCutAutoPlay") else { return }
        if debugShouldHold(round: logic.currentRound, stage: "before") { return }
        run(.sequence([
            .wait(forDuration: 0.72),
            .run { [weak self] in self?.beginDebugCut() },
        ]), withKey: "debugAutoCut")
    }

    private func beginDebugCut() {
        guard logic.state == .active else { return }
        let desired = logic.currentRound == .quarter && CommandLine.arguments.contains("-jellyCutImperfect")
            ? 0.30 : logic.currentRound.targetFraction
        let x = verticalCutX(in: logic.currentShape, target: desired)
        let start = CGPoint(x: jellyCenter.x + x, y: jellyCenter.y - jellyHeight)
        let end = CGPoint(x: jellyCenter.x + x, y: jellyCenter.y + jellyHeight)
        showGuide(from: start, to: end)
        if debugShouldHold(round: logic.currentRound, stage: "guide") { return }
        run(.sequence([
            .wait(forDuration: 0.52),
            .run { [weak self] in self?.commitGesture(from: start, to: end) },
        ]), withKey: "debugCommit")
    }

    private func verticalCutX(in polygon: [CGPoint], target: Double) -> CGFloat {
        var low = polygon.map(\.x).min() ?? -jellyWidth / 2
        var high = polygon.map(\.x).max() ?? jellyWidth / 2
        for _ in 0..<50 {
            let mid = (low + high) / 2
            let start = CGPoint(x: mid, y: -jellyHeight)
            let end = CGPoint(x: mid, y: jellyHeight)
            guard let line = JellyCutLine(start: start, end: end),
                  let split = JellyPolygonGeometry.split(polygon, by: line) else { break }
            let total = JellyPolygonGeometry.area(of: polygon)
            let leftFraction = JellyPolygonGeometry.area(of: split.positive) / total
            if leftFraction < target { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    private var debugHoldStage: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-jellyCutHoldStage"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1].lowercased()
    }

    private var debugHoldRound: JellyCutRound? {
        guard let index = CommandLine.arguments.firstIndex(of: "-jellyCutHoldRound"),
              CommandLine.arguments.indices.contains(index + 1),
              let number = Int(CommandLine.arguments[index + 1]) else { return nil }
        return JellyCutRound(rawValue: number - 1)
    }

    private func debugShouldHold(round: JellyCutRound, stage: String) -> Bool {
        debugHoldStage == stage && debugHoldRound == round
    }
    #endif
}

private extension JellyCutGameLogic {
    var isInputEnabled: Bool { state == .active }
}
