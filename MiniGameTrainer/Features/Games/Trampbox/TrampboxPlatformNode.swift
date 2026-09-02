import SpriteKit
import UIKit

/// Original pseudo-3D platform assembled from normalized vector faces and scaled per frame.
final class TrampboxPlatformNode: SKNode {
    private let topFace = SKShapeNode()
    private let sideFace = SKShapeNode()
    private let outline = SKShapeNode()
    private let centerMark = SKShapeNode(circleOfRadius: 2)

    override init() {
        super.init()
        name = "trampboxPlatform"

        let top = CGMutablePath()
        top.move(to: CGPoint(x: -0.48, y: 0))
        top.addLine(to: CGPoint(x: 0.38, y: 0))
        top.addLine(to: CGPoint(x: 0.50, y: -1))
        top.addLine(to: CGPoint(x: -0.38, y: -1))
        top.closeSubpath()
        topFace.path = top
        topFace.fillColor = UIColor(red: 1.0, green: 0.83, blue: 0.20, alpha: 1)
        topFace.strokeColor = .clear
        topFace.zPosition = 2

        let side = CGMutablePath()
        side.move(to: CGPoint(x: -0.38, y: 0))
        side.addLine(to: CGPoint(x: 0.50, y: 0))
        side.addLine(to: CGPoint(x: 0.40, y: -1.0))
        side.addLine(to: CGPoint(x: -0.48, y: -1.0))
        side.closeSubpath()
        sideFace.path = side
        sideFace.fillColor = UIColor(red: 0.68, green: 0.49, blue: 0.08, alpha: 1)
        sideFace.strokeColor = .clear
        sideFace.zPosition = 1

        outline.strokeColor = AppTheme.UIColors.debugHitbox
        outline.fillColor = .clear
        outline.path = top
        outline.lineWidth = 1
        outline.zPosition = 5
        outline.isHidden = true
        centerMark.fillColor = AppTheme.UIColors.debugHitbox
        centerMark.strokeColor = .clear
        centerMark.zPosition = 6
        centerMark.isHidden = true

        addChild(sideFace)
        addChild(topFace)
        addChild(outline)
        addChild(centerMark)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    func render(width: CGFloat, topDepth: CGFloat, sideDepth: CGFloat, rotation: CGFloat, showGeometry: Bool) {
        topFace.xScale = width
        topFace.yScale = max(1, topDepth)
        sideFace.position.y = -topDepth
        sideFace.xScale = width
        sideFace.yScale = max(1, sideDepth)
        outline.xScale = width
        outline.yScale = max(1, topDepth)
        centerMark.position = CGPoint(x: 0, y: -topDepth / 2)
        zRotation = rotation
        outline.isHidden = !showGeometry
        centerMark.isHidden = !showGeometry
    }

    func depart(
        sceneSize: CGSize,
        duration: TimeInterval,
        direction: CGFloat,
        config: TrampboxGameConfig
    ) {
        removeAllActions()
        let travel = SKAction.moveBy(
            x: direction * sceneSize.width * config.departureLateralDriftRatio,
            y: -sceneSize.height * config.departureDownwardDistanceRatio,
            duration: duration
        )
        travel.timingMode = .easeIn
        let rotate = SKAction.rotate(
            byAngle: direction * config.departureRotationDegrees * .pi / 180,
            duration: duration
        )
        rotate.timingMode = .easeIn
        let enlarge = SKAction.scale(to: config.foregroundScaleMultiplier, duration: duration)
        enlarge.timingMode = .easeIn
        let fade = SKAction.sequence([
            .wait(forDuration: duration * 0.58),
            .fadeOut(withDuration: duration * 0.42),
        ])
        run(.sequence([.group([travel, rotate, enlarge, fade]), .removeFromParent()]))
    }
}
