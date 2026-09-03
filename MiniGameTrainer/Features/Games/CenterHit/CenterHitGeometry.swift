import CoreGraphics

struct CenterHitGeometry: Equatable {
    let sceneSize: CGSize
    let barFrame: CGRect
    let indicatorSize: CGSize
    let centerLineWidth: CGFloat
    let zoneFrames: [CGRect]

    init(sceneSize: CGSize, config: CenterHitGameConfig) {
        self.sceneSize = sceneSize
        let width = max(80, sceneSize.width * config.barWidthRatio)
        let height = max(24, width * config.barHeightToWidthRatio)
        let center = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * config.barCenterYRatio)
        barFrame = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        indicatorSize = CGSize(
            width: max(4, width * config.indicatorWidthToBarRatio),
            height: max(height, height * config.indicatorHeightToBarRatio)
        )
        centerLineWidth = max(2, width * config.centerLineWidthToBarRatio)

        var frames: [CGRect] = []
        var x = barFrame.minX
        let fractions = config.normalizedZoneFractions
        for (index, fraction) in fractions.enumerated() {
            let zoneWidth = index == fractions.count - 1 ? barFrame.maxX - x : width * fraction
            frames.append(CGRect(x: x, y: barFrame.minY, width: zoneWidth, height: height))
            x += zoneWidth
        }
        zoneFrames = frames
    }

    var centerX: CGFloat { barFrame.midX }
    var leftBoundary: CGFloat { barFrame.minX }
    var rightBoundary: CGFloat { barFrame.maxX }
    var halfWidth: CGFloat { barFrame.width / 2 }
}
