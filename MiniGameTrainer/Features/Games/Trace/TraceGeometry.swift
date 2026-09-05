import CoreGraphics
import Foundation

struct TraceGeometry: Equatable {
    let sceneSize: CGSize
    let config: TraceGameConfig
    let field: TraceHexField
    let spacing: CGFloat
    let nodeVisualRadius: CGFloat
    let nodeHitRadius: CGFloat
    let lineWidth: CGFloat
    let origin: CGPoint

    init(sceneSize: CGSize, config: TraceGameConfig, field: TraceHexField) {
        self.sceneSize = sceneSize
        self.config = config
        self.field = TraceHexField(radius: max(0, field.radius))
        let playfield = CGSize(
            width: max(1, sceneSize.width * config.gridWidthRatio),
            height: max(1, sceneSize.height * config.gridHeightRatio)
        )
        let radius = CGFloat(max(self.field.radius, 1))
        let widthSpan = radius * 2
        let heightSpan = radius * CGFloat(sqrt(3.0))
        let widthSpacing = playfield.width / max(widthSpan, 1)
        let heightSpacing = playfield.height / max(heightSpan, 1)
        spacing = max(8, min(widthSpacing, heightSpacing))
        nodeVisualRadius = max(2.5, spacing * config.nodeVisualRadiusToSpacing)
        nodeHitRadius = max(nodeVisualRadius * 1.8, spacing * config.nodeHitRadiusToSpacing)
        lineWidth = max(1.5, spacing * config.lineWidthToSpacing)
        origin = CGPoint(
            x: sceneSize.width * config.gridCenterXRatio,
            y: sceneSize.height * config.gridCenterYRatio
        )
    }

    var scorePosition: CGPoint {
        CGPoint(x: sceneSize.width / 2, y: sceneSize.height * (1 - config.scoreYFromTopRatio))
    }

    var timerFrame: CGRect {
        let width = sceneSize.width * config.timerWidthRatio
        let height = max(3, sceneSize.width * config.timerThicknessRatio)
        let y = sceneSize.height * (1 - config.timerYFromTopRatio) - height / 2
        return CGRect(x: (sceneSize.width - width) / 2, y: y, width: width, height: height)
    }

    /// Pointy-top axial mapping. Neighbor center distances are all `spacing`.
    func position(for node: TraceNode) -> CGPoint {
        let x = origin.x + spacing * (CGFloat(node.q) + CGFloat(node.r) / 2)
        let y = origin.y - spacing * CGFloat(sqrt(3.0) / 2) * CGFloat(node.r)
        return CGPoint(x: x, y: y)
    }

    func node(at point: CGPoint) -> TraceNode? {
        var best: TraceNode?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for node in field.allNodes {
            let distance = hypot(point.x - position(for: node).x, point.y - position(for: node).y)
            if distance <= nodeHitRadius + 1e-9, distance < bestDistance {
                best = node
                bestDistance = distance
            }
        }
        return best
    }

    func contains(_ node: TraceNode) -> Bool { field.contains(node) }

    func isInsideHitRadius(point: CGPoint, node: TraceNode) -> Bool {
        let center = position(for: node)
        return hypot(point.x - center.x, point.y - center.y) <= nodeHitRadius + 1e-9
    }
}
