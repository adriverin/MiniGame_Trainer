import CoreGraphics
import Foundation

struct TargetSpeedGeometry: Equatable {
    let sceneSize: CGSize
    let config: TargetSpeedGameConfig
    let playRect: CGRect
    let scorePosition: CGPoint
    let livesOrigin: CGPoint
    let scoreFontSize: CGFloat
    let heartSize: CGFloat
    let heartSpacing: CGFloat
    let minimumHitRadius: CGFloat
    let overlapPadding: CGFloat
    let ringLineWidth: CGFloat

    init(sceneSize: CGSize, config: TargetSpeedGameConfig) {
        self.sceneSize = sceneSize
        self.config = config
        let minX = sceneSize.width * config.playMinXRatio
        let maxX = sceneSize.width * config.playMaxXRatio
        let minY = sceneSize.height * config.playMinYRatio
        let maxY = sceneSize.height * config.playMaxYRatio
        playRect = CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        scorePosition = CGPoint(
            x: sceneSize.width * config.scoreXRatio,
            y: sceneSize.height * config.scoreYRatio
        )
        livesOrigin = CGPoint(
            x: sceneSize.width * config.livesXRatio,
            y: sceneSize.height * config.livesYRatio
        )
        scoreFontSize = max(28, sceneSize.width * config.scoreFontRatio)
        heartSize = max(12, sceneSize.width * config.heartSizeRatio)
        heartSpacing = max(heartSize, sceneSize.width * config.livesSpacingRatio)
        minimumHitRadius = max(8, sceneSize.width * config.minimumHitRadiusRatio)
        overlapPadding = max(2, sceneSize.width * config.overlapPaddingRatio)
        ringLineWidth = max(2, sceneSize.width * config.ringLineWidthRatio)
    }

    func heartPosition(index: Int) -> CGPoint {
        CGPoint(x: livesOrigin.x + CGFloat(index) * heartSpacing, y: livesOrigin.y)
    }

    func clampCenter(_ center: CGPoint, radius: CGFloat) -> CGPoint {
        let inset = playRect.insetBy(dx: radius, dy: radius)
        guard inset.width > 0, inset.height > 0 else {
            return CGPoint(x: playRect.midX, y: playRect.midY)
        }
        return CGPoint(
            x: min(max(center.x, inset.minX), inset.maxX),
            y: min(max(center.y, inset.minY), inset.maxY)
        )
    }

    func isFullyContained(center: CGPoint, radius: CGFloat) -> Bool {
        center.x - radius >= playRect.minX - 0.001
            && center.x + radius <= playRect.maxX + 0.001
            && center.y - radius >= playRect.minY - 0.001
            && center.y + radius <= playRect.maxY + 0.001
    }

    func overlapsExisting(
        center: CGPoint,
        radius: CGFloat,
        existing: [TargetSpeedTargetState]
    ) -> Bool {
        existing.contains { other in
            let dx = center.x - other.center.x
            let dy = center.y - other.center.y
            let minimum = radius + other.radius + overlapPadding
            return dx * dx + dy * dy < minimum * minimum
        }
    }

    func nearestTarget(
        at point: CGPoint,
        among targets: [TargetSpeedTargetState],
        time: TimeInterval
    ) -> TargetSpeedTargetState? {
        let hits = targets.filter { $0.isAlive(at: time) && $0.contains(point, minimumHitRadius: minimumHitRadius) }
        return hits.min { a, b in
            let da = hypot(point.x - a.center.x, point.y - a.center.y)
            let db = hypot(point.x - b.center.x, point.y - b.center.y)
            if abs(da - db) > 0.0001 { return da < db }
            return a.id > b.id
        }
    }
}
