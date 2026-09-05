import CoreGraphics
import Foundation

struct JumpyLaneGenerator {
    let config: JumpyGameConfig
    private(set) var rng: AnyRandomNumberGenerator
    private(set) var roadRowsRemaining = 0
    private(set) var nextLaneID = 0
    private var recentDirections: [JumpyLaneDirection] = []

    init(config: JumpyGameConfig) {
        self.config = config
        rng = .seeded(config.randomSeed)
    }

    mutating func row(at worldRow: Int, difficultyScore: Int? = nil) -> JumpyWorldRow {
        guard worldRow > 0 else { return JumpyWorldRow(worldRow: worldRow, kind: .safe) }
        if roadRowsRemaining == 0 {
            let range = JumpyDifficultyModel(config: config).values(at: difficultyScore ?? worldRow).roadGroupLength
            roadRowsRemaining = randomInt(in: range)
        }
        let lane = makeLane(row: worldRow, difficultyScore: difficultyScore ?? worldRow)
        roadRowsRemaining -= 1
        if roadRowsRemaining == 0 {
            // The next requested row is the safe strip.
            roadRowsRemaining = -1
        }
        return JumpyWorldRow(worldRow: worldRow, kind: .road(lane))
    }

    mutating func nextRow(at worldRow: Int, difficultyScore: Int? = nil) -> JumpyWorldRow {
        if roadRowsRemaining == -1 {
            roadRowsRemaining = 0
            return JumpyWorldRow(worldRow: worldRow, kind: .safe)
        }
        return row(at: worldRow, difficultyScore: difficultyScore)
    }

    private mutating func makeLane(row: Int, difficultyScore: Int) -> JumpyLane {
        let difficulty = JumpyDifficultyModel(config: config).values(at: difficultyScore)
        var direction: JumpyLaneDirection = randomBool() ? .left : .right
        if recentDirections.suffix(config.maximumSameDirectionRun).allSatisfy({ $0 == direction }) &&
            recentDirections.count >= config.maximumSameDirectionRun {
            direction = direction == .left ? .right : .left
        }
        recentDirections.append(direction)
        if recentDirections.count > config.maximumSameDirectionRun { recentDirections.removeFirst() }

        let speed = randomCGFloat(in: difficulty.speed)
        let width = randomCGFloat(in: config.vehicleWidthRange)
        let requestedGap = randomCGFloat(in: difficulty.gap)
        let crossingGap = config.playerWidthRatio * config.playerHitboxScale + speed * CGFloat(config.hopDuration) + config.trafficSafetyGap
        let spacing = max(requestedGap, crossingGap)
        let trackLength = 1 + config.trafficMargin * 2
        let count = max(1, Int(floor(trackLength / (width + spacing))))
        let phase = randomCGFloat(in: 0...(width + spacing))
        defer { nextLaneID += 1 }
        return JumpyLane(
            id: nextLaneID,
            worldRow: row,
            direction: direction,
            speed: speed,
            vehicleWidth: width,
            spacing: spacing,
            phaseOffset: phase,
            vehicleCount: count,
            phase: 0
        )
    }

    private mutating func randomBool() -> Bool { rng.next() & 1 == 0 }
    private mutating func randomInt(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &rng)
    }
    private mutating func randomCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &rng)
    }
}
