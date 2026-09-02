import Foundation

/// Per-game aggregate statistics. Keyed by `MiniGameDescriptor.id` so every game gets its own record.
struct GameStatistics: Codable, Hashable {
    let gameID: String
    var gamesPlayed: Int = 0
    var bestScore: Int = 0
    /// Best score before the most recent game; lets the results screen detect a new record.
    var previousBestScore: Int = 0
    var lastScore: Int = 0
    var totalScore: Int = 0
    var bestReactionTime: TimeInterval?
    var lastPlayed: Date?

    init(gameID: String) {
        self.gameID = gameID
    }

    var averageScore: Double {
        gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : 0
    }

    /// Folds a finished game into the aggregate using that game's comparison direction.
    mutating func record(_ result: GameResult) {
        precondition(result.gameID == gameID)
        let isFirstResult = gamesPlayed == 0
        previousBestScore = bestScore
        if isFirstResult || result.scorePresentation.comparison.isBetter(result.score, than: bestScore) {
            bestScore = result.score
        }
        gamesPlayed += 1
        lastScore = result.score
        totalScore += result.score
        lastPlayed = result.date
        if let reaction = result.bestReactionTime {
            bestReactionTime = min(bestReactionTime ?? reaction, reaction)
        }
    }
}
