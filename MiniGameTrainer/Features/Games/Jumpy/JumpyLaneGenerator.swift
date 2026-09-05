import CoreGraphics
import Foundation

struct JumpyLaneGenerator {
    let config: JumpyGameConfig
    private(set) var rng: AnyRandomNumberGenerator
    private(set) var roadRowsRemaining = 0
    private(set) var safeRowsRemaining = 0
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
            let score = difficultyScore ?? worldRow
            let paired = score >= 20 && randomInt(in: 0...(config.pairedSafeRowChanceDenominator - 1)) == 0
            safeRowsRemaining = paired ? 2 : 1
        }
        return JumpyWorldRow(worldRow: worldRow, kind: .road(lane))
    }

    mutating func nextRow(at worldRow: Int, difficultyScore: Int? = nil) -> JumpyWorldRow {
        if safeRowsRemaining > 0 {
            safeRowsRemaining -= 1
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
        let requestedGap = randomCGFloat(in: difficulty.groupOpening)
        let crossingGap = config.playerWidthRatio * config.playerHitboxScale + speed * CGFloat(config.hopDuration) + config.trafficSafetyGap
        let opening = max(requestedGap, crossingGap)
        let cycleLength = 1 + config.trafficMargin * 2
        let pattern = makePattern(
            width: width,
            cycleLength: cycleLength,
            carsPerGroup: difficulty.carsPerGroup,
            internalGap: difficulty.internalGap,
            opening: opening
        )
        let phase = randomCGFloat(in: 0...cycleLength)
        defer { nextLaneID += 1 }
        return JumpyLane(
            id: nextLaneID,
            worldRow: row,
            direction: direction,
            speed: speed,
            vehicleWidth: width,
            vehicleOffsets: pattern.offsets,
            groupStartIndices: pattern.groupStarts,
            cycleLength: cycleLength,
            phase: phase
        )
    }

    private mutating func makePattern(
        width: CGFloat,
        cycleLength: CGFloat,
        carsPerGroup: ClosedRange<Int>,
        internalGap: ClosedRange<CGFloat>,
        opening: CGFloat
    ) -> (offsets: [CGFloat], groupStarts: [Int]) {
        var offsets: [CGFloat] = []
        var groupStarts: [Int] = []
        var cursor = opening / 2
        while true {
            let count = randomInt(in: carsPerGroup)
            let gaps = (0..<max(0, count - 1)).map { _ in randomCGFloat(in: internalGap) }
            let span = CGFloat(count) * width + gaps.reduce(0, +)
            guard cursor + span + opening / 2 <= cycleLength else { break }
            groupStarts.append(offsets.count)
            for index in 0..<count {
                offsets.append(cursor + width / 2)
                cursor += width
                if index < gaps.count { cursor += gaps[index] }
            }
            cursor += opening
        }
        if offsets.isEmpty {
            groupStarts = [0]
            offsets = [cycleLength / 2]
        }
        return (offsets, groupStarts)
    }

    private mutating func randomBool() -> Bool { rng.next() & 1 == 0 }
    private mutating func randomInt(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &rng)
    }
    private mutating func randomCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &rng)
    }
}
