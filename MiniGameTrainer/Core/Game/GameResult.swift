import Foundation

enum ScoreComparison: String, Hashable, Codable {
    case higherIsBetter
    case lowerIsBetter

    func isBetter(_ candidate: Int, than incumbent: Int) -> Bool {
        switch self {
        case .higherIsBetter: candidate > incumbent
        case .lowerIsBetter: candidate < incumbent
        }
    }
}

/// Small, reusable description of what the primary result number means.
struct ScorePresentation: Hashable, Codable {
    let label: String
    let unit: String?
    let comparison: ScoreComparison
    /// Number of stored integer units per one displayed unit. A scale of 100 stores hundredths
    /// without changing the long-standing integer persistence format.
    let storageScale: Int
    let valueFractionDigits: Int
    let averageFractionDigits: Int
    let separatesUnit: Bool

    init(
        label: String = "Score",
        unit: String? = nil,
        comparison: ScoreComparison = .higherIsBetter,
        storageScale: Int = 1,
        valueFractionDigits: Int = 0,
        averageFractionDigits: Int = 1,
        separatesUnit: Bool = true
    ) {
        self.label = label
        self.unit = unit
        self.comparison = comparison
        self.storageScale = max(1, storageScale)
        self.valueFractionDigits = max(0, valueFractionDigits)
        self.averageFractionDigits = max(0, averageFractionDigits)
        self.separatesUnit = separatesUnit
    }

    func formatted(_ value: Int) -> String {
        let number = storageScale == 1 && valueFractionDigits == 0
            ? "\(value)"
            : String(format: "%.*f", valueFractionDigits, Double(value) / Double(storageScale))
        return appendingUnit(to: number)
    }

    func formattedAverage(_ value: Double) -> String {
        let number = String(format: "%.*f", averageFractionDigits, value / Double(storageScale))
        return appendingUnit(to: number)
    }

    private func appendingUnit(to number: String) -> String {
        guard let unit else { return number }
        return separatesUnit ? "\(number) \(unit)" : "\(number)\(unit)"
    }

    static let points = ScorePresentation()
    static let reactionMilliseconds = ScorePresentation(
        label: "Average",
        unit: "ms",
        comparison: .lowerIsBetter
    )
    /// Center Hit persists percentage hundredths as basis points: 97.89% is stored as 9789.
    static let precisionPercent = ScorePresentation(
        label: "Precision",
        unit: "%",
        comparison: .higherIsBetter,
        storageScale: 100,
        valueFractionDigits: 2,
        averageFractionDigits: 2,
        separatesUnit: false
    )

    private enum CodingKeys: String, CodingKey {
        case label, unit, comparison, storageScale, valueFractionDigits, averageFractionDigits, separatesUnit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? "Score"
        unit = try values.decodeIfPresent(String.self, forKey: .unit)
        comparison = try values.decodeIfPresent(ScoreComparison.self, forKey: .comparison) ?? .higherIsBetter
        storageScale = max(1, try values.decodeIfPresent(Int.self, forKey: .storageScale) ?? 1)
        valueFractionDigits = max(0, try values.decodeIfPresent(Int.self, forKey: .valueFractionDigits) ?? 0)
        averageFractionDigits = max(0, try values.decodeIfPresent(Int.self, forKey: .averageFractionDigits) ?? 1)
        separatesUnit = try values.decodeIfPresent(Bool.self, forKey: .separatesUnit) ?? true
    }
}

/// Outcome of one finished game session. Generic across all minigames; game-specific numbers go
/// into `metrics` so the shell never needs to know about tiles, targets, etc.
struct GameResult: Hashable, Codable, Identifiable {
    let id: UUID
    let gameID: String
    let score: Int
    let scorePresentation: ScorePresentation
    let date: Date
    /// Active play time in seconds (excludes countdown and pauses).
    let duration: TimeInterval
    /// Fraction 0...1 of correct actions over all evaluated actions, when meaningful.
    let accuracy: Double?
    let averageReactionTime: TimeInterval?
    let bestReactionTime: TimeInterval?
    /// Ordered, display-ready metrics shown on the results screen.
    let metrics: [GameMetric]

    init(
        id: UUID = UUID(),
        gameID: String,
        score: Int,
        scorePresentation: ScorePresentation = .points,
        date: Date = Date(),
        duration: TimeInterval,
        accuracy: Double? = nil,
        averageReactionTime: TimeInterval? = nil,
        bestReactionTime: TimeInterval? = nil,
        metrics: [GameMetric] = []
    ) {
        self.id = id
        self.gameID = gameID
        self.score = score
        self.scorePresentation = scorePresentation
        self.date = date
        self.duration = duration
        self.accuracy = accuracy
        self.averageReactionTime = averageReactionTime
        self.bestReactionTime = bestReactionTime
        self.metrics = metrics
    }
}

/// A single labelled value for the results screen, e.g. ("Correct taps", "157").
struct GameMetric: Hashable, Codable, Identifiable {
    let key: String
    let label: String
    let value: String

    var id: String { key }
}

enum MetricFormatter {
    static func milliseconds(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "–" }
        return "\(Int((seconds * 1000).rounded())) ms"
    }

    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    static func seconds(_ seconds: TimeInterval) -> String {
        String(format: "%.1f s", seconds)
    }
}
