import CoreGraphics

struct ColorReflexGeometry: Equatable {
    let sceneSize: CGSize
    let config: ColorReflexGameConfig
    let scorePosition: CGPoint
    let scoreFontSize: CGFloat
    let promptPosition: CGPoint
    let promptFontSize: CGFloat
    let reactionPosition: CGPoint
    let reactionFontSize: CGFloat
    let barTrackFrame: CGRect
    let barCornerRadius: CGFloat
    let barStrokeWidth: CGFloat

    init(sceneSize: CGSize, config: ColorReflexGameConfig) {
        self.sceneSize = sceneSize
        self.config = config
        scorePosition = CGPoint(
            x: sceneSize.width * config.scoreXRatio,
            y: sceneSize.height * config.scoreYRatio
        )
        scoreFontSize = max(28, sceneSize.width * config.scoreFontRatio)
        promptPosition = CGPoint(
            x: sceneSize.width / 2,
            y: sceneSize.height * config.promptYRatio
        )
        promptFontSize = max(20, sceneSize.width * config.promptFontRatio)
        reactionPosition = CGPoint(
            x: sceneSize.width / 2,
            y: sceneSize.height * config.reactionYRatio
        )
        reactionFontSize = max(12, sceneSize.width * config.reactionFontRatio)
        let barWidth = max(40, sceneSize.width * config.barWidthRatio)
        let barHeight = max(4, sceneSize.height * config.barHeightRatio)
        let center = CGPoint(
            x: sceneSize.width * config.barCenterXRatio,
            y: sceneSize.height * config.barCenterYRatio
        )
        barTrackFrame = CGRect(
            x: center.x - barWidth / 2,
            y: center.y - barHeight / 2,
            width: barWidth,
            height: barHeight
        )
        barCornerRadius = min(barHeight / 2, barWidth / 2, barHeight * max(0, config.barCornerRadiusRatio))
        barStrokeWidth = max(1, sceneSize.width * config.barStrokeWidthRatio)
    }

    func barFillFrame(remainingFraction: Double) -> CGRect {
        let fraction = CGFloat(min(max(remainingFraction, 0), 1))
        return CGRect(
            x: barTrackFrame.minX,
            y: barTrackFrame.minY,
            width: barTrackFrame.width * fraction,
            height: barTrackFrame.height
        )
    }
}
