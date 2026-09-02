import CoreGraphics

/// Geometry uses screen-down Y internally; the scene converts it to SpriteKit's Y-up coordinates.
struct TrampboxGeometry: Equatable {
    let sceneSize: CGSize
    let config: TrampboxGameConfig

    var width: CGFloat { sceneSize.width }
    var height: CGFloat { sceneSize.height }
    var ballRadius: CGFloat { width * config.ballRadiusRatio }
    var horizonY: CGFloat { height * config.horizonYRatio }
    var landingY: CGFloat { height * config.landingYRatio }
    var failureY: CGFloat { height * config.failureYRatio }
    var platformSpacing: CGFloat { height * config.platformSpacingRatio }
    var maximumHorizontalSpeed: CGFloat { width * config.maximumHorizontalSpeedRatio }

    func clampBallX(_ x: CGFloat) -> CGFloat {
        min(max(ballRadius, x), width - ballRadius)
    }

    func clampPlatformCenterX(_ x: CGFloat, width platformWidth: CGFloat) -> CGFloat {
        let half = platformWidth / 2
        return min(max(half, x), width - half)
    }

    /// Screen-down top edge for platform `slot`; slot 0 is the departure platform.
    func platformTopY(slot: Int, bouncePhase: CGFloat) -> CGFloat {
        let depth = CGFloat(slot) - bouncePhase
        if depth < 0 {
            return landingY - depth * platformSpacing
        }
        // One step uses the configured near spacing; additional steps contract toward the horizon.
        let visibleSpan = max(1, landingY - horizonY)
        let firstStepFraction = min(max(0.01, 1 - platformSpacing / visibleSpan), 0.99)
        return horizonY + visibleSpan * pow(firstStepFraction, depth)
    }

    func ballCenterY(bouncePhase: CGFloat) -> CGFloat {
        let phase = min(max(0, bouncePhase), 1)
        let arc = config.bounceHeightRatio * height * 4 * phase * (1 - phase)
        return landingY - ballRadius - arc
    }

    func projectionProgress(atScreenY y: CGFloat) -> CGFloat {
        let span = max(1, landingY - horizonY)
        return min(max(0, (y - horizonY) / span), 1)
    }

    func projectedWidthScale(atScreenY y: CGFloat) -> CGFloat {
        let curved = pow(projectionProgress(atScreenY: y), config.perspectiveExponent)
        return config.farScale + (config.nearScale - config.farScale) * curved
    }

    func projectedPlatformWidth(logicalWidth: CGFloat, atScreenY y: CGFloat) -> CGFloat {
        logicalWidth * projectedWidthScale(atScreenY: y)
    }

    func projectedTopDepth(projectedWidth: CGFloat, atScreenY y: CGFloat) -> CGFloat {
        let progress = pow(projectionProgress(atScreenY: y), config.depthProjectionExponent)
        let ratio = config.farTopDepthToWidthRatio
            + (config.nearTopDepthToWidthRatio - config.farTopDepthToWidthRatio) * progress
        return projectedWidth * ratio
    }

    func projectedSideDepth(projectedWidth: CGFloat, atScreenY y: CGFloat) -> CGFloat {
        let progress = pow(projectionProgress(atScreenY: y), config.depthProjectionExponent)
        let ratio = config.farSideDepthToWidthRatio
            + (config.nearSideDepthToWidthRatio - config.farSideDepthToWidthRatio) * progress
        return projectedWidth * ratio
    }

    /// Mild deterministic approach orientation; it resolves to zero at the landing band.
    func approachRotation(platformID: Int, atScreenY y: CGFloat) -> CGFloat {
        let progress = projectionProgress(atScreenY: y)
        let envelope = sin(.pi * progress)
        let phase = sin(CGFloat(platformID &* 73 &+ 19) * 1.618)
        return phase * envelope * config.approachRotationDegrees * .pi / 180
    }

    func scenePoint(screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x, y: height - screenPoint.y)
    }
}
