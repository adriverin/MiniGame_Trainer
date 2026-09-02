import CoreGraphics
import Foundation

struct TrampboxPlatformGenerator {
    private let config: TrampboxGameConfig
    private let difficulty: TrampboxDifficultyModel
    private var random: AnyRandomNumberGenerator
    private var nextID = 0

    init(config: TrampboxGameConfig) {
        self.config = config
        difficulty = TrampboxDifficultyModel(config: config)
        random = .seeded(config.randomSeed)
    }

    mutating func reset() {
        random = .seeded(config.randomSeed)
        nextID = 0
    }

    mutating func initialPlatforms(geometry: TrampboxGeometry) -> [TrampboxPlatform] {
        reset()
        let width = difficulty.platformWidthRatio(for: 0) * geometry.width
        let start = TrampboxPlatform(
            id: consumeID(),
            centerX: geometry.clampPlatformCenterX(config.startingXRatio * geometry.width, width: width),
            width: width,
            scoreLevel: 0
        )
        var result = [start]
        while result.count < max(2, config.visiblePlatformCount) {
            let nextScore = result.count
            result.append(next(after: result[result.count - 1], score: nextScore, geometry: geometry))
        }
        return result
    }

    mutating func next(after current: TrampboxPlatform, score: Int, geometry: TrampboxGeometry) -> TrampboxPlatform {
        let width = difficulty.platformWidthRatio(for: score) * geometry.width
        let maximumReach = self.maximumReach(from: current, geometry: geometry)
        let configuredMaximum = config.maximumHorizontalOffsetRatio * geometry.width
        let allowedOffset = max(0, min(maximumReach, configuredMaximum))
        let configuredMinimum = config.minimumHorizontalOffsetRatio * geometry.width
        let minimumOffset = min(configuredMinimum, allowedOffset)
        let magnitude = minimumOffset + randomUnit() * (allowedOffset - minimumOffset)
        let sign: CGFloat = random.next().isMultiple(of: 2) ? -1 : 1
        let proposed = current.centerX + sign * magnitude
        let center = geometry.clampPlatformCenterX(proposed, width: width)
        return TrampboxPlatform(id: consumeID(), centerX: center, width: width, scoreLevel: score)
    }

    func maximumReach(from platform: TrampboxPlatform, geometry: TrampboxGeometry) -> CGFloat {
        geometry.maximumHorizontalSpeed
            * difficulty.bounceDuration(for: platform.scoreLevel)
            * config.reachabilityMultiplier
    }

    private mutating func consumeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private mutating func randomUnit() -> CGFloat {
        CGFloat(Double(random.next()) / Double(UInt64.max))
    }
}
