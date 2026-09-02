import SpriteKit

/// Pseudo-3D block: a top face plus the two side faces that face the camera. All geometry comes
/// from `TowerStackProjection`; this node never computes gameplay values.
final class TowerStackBlockNode: SKNode {
    private let topFace = SKShapeNode()
    private let leftFace = SKShapeNode()
    private let rightFace = SKShapeNode()
    private let outline = SKShapeNode()
    /// Scene-space anchor used so squash/scale actions pivot around the top-face centre.
    private(set) var anchor: CGPoint = .zero

    override init() {
        super.init()
        for face in [leftFace, rightFace, topFace] {
            face.lineWidth = 0.5
            face.isAntialiased = true
            addChild(face)
        }
        outline.lineWidth = 1
        outline.fillColor = .clear
        outline.strokeColor = UIColor(white: 1, alpha: 0.10)
        outline.isAntialiased = true
        outline.isHidden = true
        addChild(outline)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    func render(_ block: TowerStackProjectedBlock, colors: TowerStackBlockColors, showOutline: Bool = false) {
        anchor = block.topCenter
        position = anchor
        let (left, right) = block.sideXIsLeft ? (block.sideX, block.sideZ) : (block.sideZ, block.sideX)
        topFace.path = path(block.top)
        leftFace.path = path(left)
        rightFace.path = path(right)
        topFace.fillColor = colors.top
        topFace.strokeColor = colors.top
        leftFace.fillColor = colors.leftFace
        leftFace.strokeColor = colors.leftFace
        rightFace.fillColor = colors.rightFace
        rightFace.strokeColor = colors.rightFace
        outline.isHidden = !showOutline
        if showOutline {
            outline.path = path(block.top)
        }
    }

    /// Brief squash-and-stretch used when a block lands (visual only).
    func playLanding(duration: TimeInterval) {
        removeAction(forKey: "landing")
        xScale = 1
        yScale = 1
        let squash = SKAction.group([
            .scaleX(to: 1.06, duration: duration * 0.35),
            .scaleY(to: 0.90, duration: duration * 0.35),
        ])
        squash.timingMode = .easeOut
        let recover = SKAction.group([
            .scaleX(to: 1, duration: duration * 0.65),
            .scaleY(to: 1, duration: duration * 0.65),
        ])
        recover.timingMode = .easeInEaseOut
        run(.sequence([squash, recover]), withKey: "landing")
    }

    private func path(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x - anchor.x, y: first.y - anchor.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x - anchor.x, y: point.y - anchor.y))
        }
        path.closeSubpath()
        return path
    }
}
