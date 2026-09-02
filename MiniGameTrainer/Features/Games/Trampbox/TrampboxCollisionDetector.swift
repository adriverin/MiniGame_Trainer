import CoreGraphics

enum TrampboxCollisionDetector {
    static func horizontallyOverlaps(
        ballX: CGFloat,
        ballRadius: CGFloat,
        platformCenterX: CGFloat,
        platformWidth: CGFloat,
        rule: TrampboxLandingRule,
        tolerance: CGFloat
    ) -> Bool {
        let halfWidth = platformWidth / 2
        let distance = abs(ballX - platformCenterX)
        switch rule {
        case .centerInsidePlatform:
            return distance <= halfWidth * max(0, tolerance)
        case .ballOverlap:
            return distance <= halfWidth + ballRadius * max(0, tolerance)
        }
    }

    /// Swept vertical crossing prevents tunnelling when a fast bounce completes between frames.
    static func didLand(
        previousBallBottom: CGFloat,
        currentBallBottom: CGFloat,
        previousPlatformTop: CGFloat,
        currentPlatformTop: CGFloat,
        descending: Bool,
        ballX: CGFloat,
        ballRadius: CGFloat,
        platformCenterX: CGFloat,
        platformWidth: CGFloat,
        rule: TrampboxLandingRule,
        tolerance: CGFloat
    ) -> Bool {
        guard descending,
              previousBallBottom <= previousPlatformTop + 0.001,
              currentBallBottom >= currentPlatformTop - 0.001
        else { return false }
        return horizontallyOverlaps(
            ballX: ballX,
            ballRadius: ballRadius,
            platformCenterX: platformCenterX,
            platformWidth: platformWidth,
            rule: rule,
            tolerance: tolerance
        )
    }
}
