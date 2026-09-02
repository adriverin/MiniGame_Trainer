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

    init(label: String = "Score", unit: String? = nil, comparison: ScoreComparison = .higherIsBetter) {
        self.label = label
        self.unit = unit
        self.comparison = comparison
    }

    func formatted(_ value: Int) -> String {
        unit.map { "\(value) \($0)" } ?? "\(value)"
    }

    func formattedAverage(_ value: Double) -> String {
        let number = String(format: "%.1f", value)
        return unit.map { "\(number) \($0)" } ?? number
    }

    static let points = ScorePresentation()
    static let reactionMilliseconds = ScorePresentation(
        label: "Average",
        unit: "ms",
        comparison: .lowerIsBetter
    )
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
