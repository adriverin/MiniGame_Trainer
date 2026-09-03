import CoreGraphics
import Foundation

/// Timestamp-scheduled target factory. Placement is deterministic for a given RNG stream.
struct TargetSpeedSpawner {
    let config: TargetSpeedGameConfig
    let difficulty: TargetSpeedDifficultyModel
    let geometry: TargetSpeedGeometry

    func nextSpawnTime(after time: TimeInterval, score: Int, intervalOverride: TimeInterval?) -> TimeInterval {
        time + (intervalOverride ?? difficulty.spawnInterval(forScore: score))
    }

    func makeTarget(
        id: Int,
        at time: TimeInterval,
        score: Int,
        existing: [TargetSpeedTargetState],
        rng: inout AnyRandomNumberGenerator,
        lifetimeOverride: TimeInterval?,
        radiusOverride: CGFloat?,
        positionOverride: CGPoint?
    ) -> TargetSpeedTargetState? {
        let lifetime = lifetimeOverride ?? difficulty.lifetime(forScore: score)
        let radius: CGFloat
        let tier: TargetSpeedSizeTier
        if let radiusOverride {
            radius = radiusOverride
            tier = tierMatching(diameterRatio: (radiusOverride * 2) / max(geometry.sceneSize.width, 1))
        } else {
            tier = sampleTier(score: score, rng: &rng)
            radius = sampleRadius(tier: tier, rng: &rng)
        }

        let center: CGPoint
        if let positionOverride {
            center = geometry.clampCenter(positionOverride, radius: radius)
        } else if let placed = place(radius: radius, existing: existing, rng: &rng) {
            center = placed
        } else {
            return nil
        }

        return TargetSpeedTargetState(
            id: id,
            center: center,
            radius: radius,
            spawnedAt: time,
            expiresAt: time + lifetime,
            pointValue: TargetSpeedScoring.points(forHit: config),
            sizeTier: tier
        )
    }

    func sampleTier(score: Int, rng: inout AnyRandomNumberGenerator) -> TargetSpeedSizeTier {
        let weights = difficulty.sizeWeights(forScore: score)
        let pick = unit(rng: &rng)
        var cumulative = 0.0
        let tiers = TargetSpeedSizeTier.allCases
        for (index, tier) in tiers.enumerated() {
            cumulative += index < weights.count ? weights[index] : 0
            if pick <= cumulative { return tier }
        }
        return .large
    }

    func sampleRadius(tier: TargetSpeedSizeTier, rng: inout AnyRandomNumberGenerator) -> CGFloat {
        let range = config.diameterRange(for: tier)
        let diameter = range.lowerBound + CGFloat(unit(rng: &rng)) * (range.upperBound - range.lowerBound)
        return max(4, geometry.sceneSize.width * diameter / 2)
    }

    func place(
        radius: CGFloat,
        existing: [TargetSpeedTargetState],
        rng: inout AnyRandomNumberGenerator
    ) -> CGPoint? {
        let inset = geometry.playRect.insetBy(dx: radius, dy: radius)
        guard inset.width > 0, inset.height > 0 else { return geometry.playRect.origin }
        for _ in 0..<max(1, config.spawnPlacementAttempts) {
            let x = inset.minX + CGFloat(unit(rng: &rng)) * inset.width
            let y = inset.minY + CGFloat(unit(rng: &rng)) * inset.height
            let center = CGPoint(x: x, y: y)
            if !geometry.overlapsExisting(center: center, radius: radius, existing: existing) {
                return center
            }
        }
        return nil
    }

    func tierMatching(diameterRatio: CGFloat) -> TargetSpeedSizeTier {
        for tier in TargetSpeedSizeTier.allCases {
            if config.diameterRange(for: tier).contains(diameterRatio) { return tier }
        }
        if diameterRatio < (config.smallDiameterRange.first ?? 0.045) { return .tiny }
        if diameterRatio < (config.mediumDiameterRange.first ?? 0.09) { return .small }
        if diameterRatio < (config.largeDiameterRange.first ?? 0.175) { return .medium }
        return .large
    }

    private func unit(rng: inout AnyRandomNumberGenerator) -> Double {
        Double(rng.next() % 1_000_000) / 1_000_000
    }
}
