import CoreGraphics
import Foundation

/// Piecewise-linear score-threshold difficulty from the 731-point recording.
/// Capped at the last calibrated anchor so score 1,000 cannot collapse lifetime or spawn interval.
struct TargetSpeedDifficultyModel: Equatable {
    let config: TargetSpeedGameConfig

    func snapshot(forScore score: Int) -> TargetSpeedDifficultySnapshot {
        TargetSpeedDifficultySnapshot(
            stageIndex: stageIndex(forScore: score),
            lifetime: lifetime(forScore: score),
            spawnInterval: spawnInterval(forScore: score),
            maxActive: maxActive(forScore: score),
            minDiameterRatio: config.tinyDiameterRange.first ?? 0.022,
            maxDiameterRatio: config.largeDiameterRange.last ?? 0.228
        )
    }

    func stageIndex(forScore score: Int) -> Int {
        let scores = config.difficultyAnchorScores
        guard !scores.isEmpty else { return 0 }
        let clamped = max(0, score)
        if clamped <= scores[0] { return 0 }
        if clamped >= scores[scores.count - 1] { return scores.count - 1 }
        var index = 0
        for i in 0..<(scores.count - 1) where clamped >= scores[i] {
            index = i
        }
        return index
    }

    func lifetime(forScore score: Int) -> TimeInterval {
        max(config.minimumLifetime, interpolate(score: score, values: config.difficultyAnchorLifetimes))
    }

    func spawnInterval(forScore score: Int) -> TimeInterval {
        max(config.minimumSpawnInterval, interpolate(score: score, values: config.difficultyAnchorSpawnIntervals))
    }

    func maxActive(forScore score: Int) -> Int {
        let interpolated = interpolate(score: score, values: config.difficultyAnchorMaxActive.map(Double.init))
        let rounded = Int(interpolated.rounded())
        return min(max(1, rounded), config.maximumActiveTargets)
    }

    func sizeWeights(forScore score: Int) -> [Double] {
        let scores = config.difficultyAnchorScores
        let weights = config.sizeWeightAnchors
        guard !scores.isEmpty, scores.count == weights.count else {
            return [1, 0, 0, 0]
        }
        let clamped = max(0, score)
        if clamped <= scores[0] { return normalized(weights[0]) }
        if clamped >= scores[scores.count - 1] { return normalized(weights[weights.count - 1]) }
        for index in 0..<(scores.count - 1) {
            let lower = scores[index]
            let upper = scores[index + 1]
            if clamped >= lower, clamped <= upper {
                let span = max(1, upper - lower)
                let t = Double(clamped - lower) / Double(span)
                let a = weights[index]
                let b = weights[index + 1]
                let count = max(a.count, b.count)
                var mixed: [Double] = []
                for i in 0..<count {
                    let left = i < a.count ? a[i] : 0
                    let right = i < b.count ? b[i] : 0
                    mixed.append(left + t * (right - left))
                }
                return normalized(mixed)
            }
        }
        return normalized(weights[weights.count - 1])
    }

    private func interpolate(score: Int, values: [TimeInterval]) -> TimeInterval {
        let scores = config.difficultyAnchorScores
        guard !scores.isEmpty, scores.count == values.count else {
            return values.last ?? 1
        }
        let clamped = max(0, score)
        if clamped <= scores[0] { return values[0] }
        if clamped >= scores[scores.count - 1] { return values[values.count - 1] }
        for index in 0..<(scores.count - 1) {
            let lower = scores[index]
            let upper = scores[index + 1]
            if clamped >= lower, clamped <= upper {
                let span = max(1, upper - lower)
                let t = Double(clamped - lower) / Double(span)
                return values[index] + t * (values[index + 1] - values[index])
            }
        }
        return values[values.count - 1]
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let total = values.reduce(0, +)
        guard total > 0 else { return [1, 0, 0, 0] }
        return values.map { $0 / total }
    }
}
