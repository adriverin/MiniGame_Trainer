import CoreGraphics
import Foundation

struct TraceGeometry: Equatable {
    let sceneSize: CGSize
    let config: TraceGameConfig
    let grid: TraceGridSize
    let spacing: CGFloat
    let verticalSpacing: CGFloat
    let nodeVisualRadius: CGFloat
    let nodeHitRadius: CGFloat
    let lineWidth: CGFloat
    let origin: CGPoint

    init(sceneSize: CGSize, config: TraceGameConfig, grid: TraceGridSize) {
        self.sceneSize = sceneSize
        self.config = config
        self.grid = TraceGridSize(rows: max(1, grid.rows), columns: max(1, grid.columns))
        let playfield = CGSize(
            width: max(1, sceneSize.width * config.gridWidthRatio),
            height: max(1, sceneSize.height * config.gridHeightRatio)
        )
        let columns = CGFloat(self.grid.columns)
        let rows = CGFloat(self.grid.rows)
        let widthSpacing = playfield.width / max(columns - 0.5, 1)
        let heightSpacing = playfield.height / max((rows - 1) * CGFloat(0.5 * sqrt(3.0)) + 1, 1)
        spacing = max(8, min(widthSpacing, heightSpacing))
        verticalSpacing = spacing * CGFloat(sqrt(3.0) / 2)
        nodeVisualRadius = max(3, spacing * config.nodeVisualRadiusToSpacing)
        nodeHitRadius = max(nodeVisualRadius, spacing * config.nodeHitRadiusToSpacing)
        lineWidth = max(2, spacing * config.lineWidthToSpacing)
        let gridWidth = spacing * max(columns - 0.5, 0)
        let gridHeight = verticalSpacing * max(rows - 1, 0)
        origin = CGPoint(
            x: sceneSize.width * config.gridCenterXRatio - gridWidth / 2,
            y: sceneSize.height * config.gridCenterYRatio - gridHeight / 2
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

    func position(for node: TraceNode) -> CGPoint {
        let x = origin.x + (CGFloat(node.column) + (node.row & 1 == 1 ? 0.5 : 0)) * spacing
        let y = origin.y + CGFloat(grid.rows - 1 - node.row) * verticalSpacing
        return CGPoint(x: x, y: y)
    }

    func node(at point: CGPoint) -> TraceNode? {
        var best: TraceNode?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for node in grid.allNodes {
            let distance = hypot(point.x - position(for: node).x, point.y - position(for: node).y)
            if distance <= nodeHitRadius + 1e-9, distance < bestDistance {
                best = node
                bestDistance = distance
            }
        }
        return best
    }

    func contains(_ node: TraceNode) -> Bool { grid.contains(node) }

    func isInsideHitRadius(point: CGPoint, node: TraceNode) -> Bool {
        let center = position(for: node)
        return hypot(point.x - center.x, point.y - center.y) <= nodeHitRadius + 1e-9
    }
}
