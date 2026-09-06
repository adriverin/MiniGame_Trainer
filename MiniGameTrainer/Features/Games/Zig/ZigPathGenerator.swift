import Foundation

struct ZigSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

struct ZigPathGenerator {
    private var seeded: ZigSeededGenerator?
    private let turnProbability: Double
    private(set) var currentCell = ZigCell(x: 0, y: 3)
    private(set) var direction: ZigDirection = .positiveY
    private var emitted = 0

    init(config: ZigGameConfig) {
        turnProbability = min(max(config.turnProbability, 0), 1)
        if let seed = config.randomSeed { seeded = ZigSeededGenerator(seed: seed) }
    }

    mutating func nextCell(guaranteedStraightCells: Int) -> ZigCell {
        defer { emitted += 1 }
        if emitted == 0 { return currentCell }
        if emitted > guaranteedStraightCells, randomUnit() < turnProbability {
            direction = direction.toggled
        }
        switch direction {
        case .positiveX: currentCell = ZigCell(x: currentCell.x + 1, y: currentCell.y)
        case .positiveY: currentCell = ZigCell(x: currentCell.x, y: currentCell.y + 1)
        }
        return currentCell
    }

    private mutating func randomUnit() -> Double {
        if var seeded {
            let value = seeded.next()
            self.seeded = seeded
            return Double(value) / Double(UInt64.max)
        }
        return Double.random(in: 0..<1)
    }
}
