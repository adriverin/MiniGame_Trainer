import CoreGraphics

struct KeepUpGeometry: Equatable {
    let sceneSize: CGSize
    let platformRadius: CGFloat
    let platformCenterBounds: CGRect
    let ballRadius: CGFloat
    let effectiveCatchRadius: CGFloat
    let landingTolerance: CGFloat
    let failureY: CGFloat
    let upperLineY: CGFloat
    let upperLineHorizontalInset: CGFloat
    let upperLineThickness: CGFloat

    init(sceneSize: CGSize, config: KeepUpGameConfig) {
        self.sceneSize = sceneSize
        platformRadius = max(24, sceneSize.width * config.platformDiameterRatio / 2)
        let minimumX = sceneSize.width * min(config.minimumPlatformCenterXRatio, config.maximumPlatformCenterXRatio)
        let maximumX = sceneSize.width * max(config.minimumPlatformCenterXRatio, config.maximumPlatformCenterXRatio)
        let minimumY = sceneSize.height * min(config.minimumPlatformCenterYRatio, config.maximumPlatformCenterYRatio)
        let maximumY = sceneSize.height * max(config.minimumPlatformCenterYRatio, config.maximumPlatformCenterYRatio)
        platformCenterBounds = CGRect(
            x: minimumX,
            y: minimumY,
            width: max(0, maximumX - minimumX),
            height: max(0, maximumY - minimumY)
        )
        ballRadius = max(5, sceneSize.width * config.ballDiameterRatio / 2)
        effectiveCatchRadius = platformRadius * min(max(config.effectiveCatchRadiusRatio, 0.1), 1)
        landingTolerance = max(0, sceneSize.width * config.landingToleranceWidthRatio)
        failureY = sceneSize.height * config.failureYRatio
        upperLineY = sceneSize.height * config.upperLineYRatio
        upperLineHorizontalInset = sceneSize.width * config.upperLineHorizontalInsetRatio
        upperLineThickness = max(1, sceneSize.width * config.upperLineThicknessWidthRatio)
    }

    var minimumPlatformX: CGFloat { platformCenterBounds.minX }
    var maximumPlatformX: CGFloat { platformCenterBounds.maxX }
    var minimumPlatformY: CGFloat { platformCenterBounds.minY }
    var maximumPlatformY: CGFloat { platformCenterBounds.maxY }
    var minimumBallX: CGFloat { ballRadius }
    var maximumBallX: CGFloat { sceneSize.width - ballRadius }
    /// Visible line and physical ceiling share this Y. Collision uses the ball top.
    var ceilingY: CGFloat { upperLineY }
    /// Legal ball-center maximum: `ceilingY - ballRadius`.
    var maximumBallY: CGFloat { ceilingY - ballRadius }

    func clampedPlatformPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, minimumPlatformX), maximumPlatformX),
            y: min(max(position.y, minimumPlatformY), maximumPlatformY)
        )
    }
}
