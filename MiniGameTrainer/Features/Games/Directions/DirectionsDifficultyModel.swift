import Foundation

/// Level → sequence length and constant presentation timing measured from the reference.
///
/// Through level 12 the recording matches `length = level + 2` (3…14). Timing per item stays
/// near 0.87 s; late-game difficulty is working-memory load, not a speed ramp.
struct DirectionsDifficultyModel: Equatable {
    let config: DirectionsGameConfig

    func sequenceLength(forLevel level: Int) -> Int {
        let resolved = max(1, level) + config.sequenceLengthOffset
        return min(max(1, config.sequenceLengthCap), max(1, resolved))
    }

    func presentationDuration(forSequenceLength length: Int) -> TimeInterval {
        let count = max(0, length)
        guard count > 0 else { return max(0, config.transitionToRecallDuration) }
        let on = max(0, config.arrowOnDuration)
        let gap = max(0, config.interArrowGap)
        let transition = max(0, config.transitionToRecallDuration)
        return TimeInterval(count) * on + TimeInterval(count - 1) * gap + transition
    }

    func arrowOnDuration(forLevel level: Int) -> TimeInterval {
        _ = level
        return max(0, config.arrowOnDuration)
    }

    func interArrowGap(forLevel level: Int) -> TimeInterval {
        _ = level
        return max(0, config.interArrowGap)
    }
}
