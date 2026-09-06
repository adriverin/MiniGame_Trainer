import CoreGraphics

struct ZigProjection {
    let size: CGSize
    let config: ZigGameConfig
    let cameraProgress: CGFloat
    let cameraLateral: CGFloat

    var horizontalScale: CGFloat { size.width * config.horizontalScaleRatio }
    var verticalScale: CGFloat { size.width * config.verticalScaleRatio }
    var anchorY: CGFloat { size.height * config.cameraAnchorYRatio }
    var slabDepth: CGFloat { size.width * config.slabDepthRatio }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (x - y - cameraLateral) * horizontalScale,
            y: anchorY + (x + y - cameraProgress) * verticalScale
        )
    }

    func topPolygon(centerX: CGFloat, centerY: CGFloat, width: CGFloat = 1) -> [CGPoint] {
        let half = width / 2
        return [
            point(x: centerX - half, y: centerY - half),
            point(x: centerX + half, y: centerY - half),
            point(x: centerX + half, y: centerY + half),
            point(x: centerX - half, y: centerY + half),
        ]
    }
}
