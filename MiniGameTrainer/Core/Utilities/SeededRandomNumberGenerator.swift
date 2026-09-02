import Foundation

/// SplitMix64: tiny, fast, deterministic generator used to replay identical sessions.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Type-erased generator so game logic can accept either the system RNG or a seeded one.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: some RandomNumberGenerator) {
        self.base = base
    }

    static func seeded(_ seed: UInt64?) -> AnyRandomNumberGenerator {
        if let seed {
            return AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
        }
        return AnyRandomNumberGenerator(SystemRandomNumberGenerator())
    }

    mutating func next() -> UInt64 {
        base.next()
    }
}
