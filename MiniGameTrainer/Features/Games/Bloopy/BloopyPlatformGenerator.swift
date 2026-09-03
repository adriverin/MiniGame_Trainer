import CoreGraphics
import Foundation

struct BloopyPlatformGenerator {
    private let config: BloopyGameConfig
    private let difficulty: BloopyDifficultyModel
    private var random: AnyRandomNumberGenerator
    private var nextID = 0

    init(config: BloopyGameConfig) {
        self.config = config
        difficulty = BloopyDifficultyModel(config: config)
        random = .seeded(config.randomSeed)
    }

    mutating func reset() {
        random = .seeded(config.randomSeed)
        nextID = 0
    }

    mutating func initialPlatforms(geometry: BloopyGeometry) -> [BloopyPlatform] {
        reset()
        let width = difficulty.platformWidth(forScore: 0, sceneWidth: geometry.width)
        let start = BloopyPlatform(
            id: consumeID(),
            worldX: geometry.width * config.startingPlatformXRatio,
            worldY: geometry.height * config.startingPlatformYRatio,
            width: width,
            kind: .fresh
        )
        var result = [start]
        while result.count < max(2, config.lookaheadPlatformCount) {
            result.append(next(after: result[result.count - 1], score: 0, geometry: geometry))
        }
        return result
    }

    mutating func next(after current: BloopyPlatform, score: Int, geometry: BloopyGeometry) -> BloopyPlatform {
        let width = jitteredWidth(score: score, sceneWidth: geometry.width)
        let gap = jitteredGap(score: score, sceneHeight: geometry.height)
        let worldY = current.worldY + gap
        let center = reachableCenter(from: current, nextWidth: width, gap: gap, geometry: geometry)
        return BloopyPlatform(id: consumeID(), worldX: center, worldY: worldY, width: width, kind: .fresh)
    }

    func isReachable(
        from current: BloopyPlatform,
        to candidate: BloopyPlatform,
        geometry: BloopyGeometry
    ) -> Bool {
        let gap = candidate.worldY - current.worldY
        guard gap > 0 else { return false }
        let bounceHeight = difficulty.bounceHeight(sceneHeight: geometry.height)
        guard gap < bounceHeight * 0.96 else { return false }
        let flight = BloopyPhysics.bounceFlightTime(
            impulse: difficulty.bounceImpulse(sceneHeight: geometry.height),
            gravity: difficulty.gravity(sceneHeight: geometry.height),
            heightGain: gap
        ) ?? 0
        let travel = BloopyPhysics.maximumHorizontalTravel(
            acceleration: difficulty.horizontalAcceleration(sceneWidth: geometry.width),
            maximumSpeed: difficulty.maximumHorizontalSpeed(sceneWidth: geometry.width),
            flightTime: flight
        ) * config.reachabilityMultiplier
        let needed = BloopyPhysics.toroidalDistance(current.worldX, candidate.worldX, width: geometry.width)
            - current.width / 2 - candidate.width / 2
        return needed <= travel + 1e-6
    }

    private mutating func reachableCenter(
        from current: BloopyPlatform,
        nextWidth: CGFloat,
        gap: CGFloat,
        geometry: BloopyGeometry
    ) -> CGFloat {
        let flight = BloopyPhysics.bounceFlightTime(
            impulse: difficulty.bounceImpulse(sceneHeight: geometry.height),
            gravity: difficulty.gravity(sceneHeight: geometry.height),
            heightGain: gap
        ) ?? 0.35
        let travel = BloopyPhysics.maximumHorizontalTravel(
            acceleration: difficulty.horizontalAcceleration(sceneWidth: geometry.width),
            maximumSpeed: difficulty.maximumHorizontalSpeed(sceneWidth: geometry.width),
            flightTime: flight
        ) * config.reachabilityMultiplier
        let allowed = max(0, travel + current.width / 2 + nextWidth / 2)
        let signed = (randomUnit() * 2 - 1) * allowed
        return BloopyPhysics.wrap(current.worldX + signed, width: geometry.width)
    }

    private mutating func jitteredWidth(score: Int, sceneWidth: CGFloat) -> CGFloat {
        let base = difficulty.platformWidth(forScore: score, sceneWidth: sceneWidth)
        let jitter = (randomUnit() * 2 - 1) * config.widthJitterRatio * sceneWidth
        return max(sceneWidth * config.minimumPlatformWidthRatio, base + jitter)
    }

    private mutating func jitteredGap(score: Int, sceneHeight: CGFloat) -> CGFloat {
        let base = difficulty.verticalSpacing(forScore: score, sceneHeight: sceneHeight)
        let jitter = (randomUnit() * 2 - 1) * config.spacingJitterRatio * sceneHeight
        let bounceHeight = difficulty.bounceHeight(sceneHeight: sceneHeight)
        let minimum = sceneHeight * 0.08
        return min(max(base + jitter, minimum), bounceHeight * 0.92)
    }

    private mutating func consumeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private mutating func randomUnit() -> CGFloat {
        CGFloat(Double(random.next()) / Double(UInt64.max))
    }
}
