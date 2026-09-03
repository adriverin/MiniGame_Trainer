import CoreGraphics

struct TimesUpGeometry: Equatable {
    let sceneSize: CGSize
    let barFrame: CGRect
    let cornerRadius: CGFloat
    let instructionPosition: CGPoint

    init(sceneSize: CGSize, config: TimesUpGameConfig) {
        self.sceneSize = sceneSize
        let width = max(24, sceneSize.width * config.barWidthRatio)
        let height = max(48, sceneSize.height * config.barHeightRatio)
        let center = CGPoint(
            x: sceneSize.width * config.barCenterXRatio,
            y: sceneSize.height * config.barCenterYRatio
        )
        barFrame = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        cornerRadius = min(width / 2, height / 2, width * max(0, config.cornerRadiusRatio))
        instructionPosition = CGPoint(
            x: sceneSize.width / 2,
            y: sceneSize.height * config.instructionYRatio
        )
    }
}
