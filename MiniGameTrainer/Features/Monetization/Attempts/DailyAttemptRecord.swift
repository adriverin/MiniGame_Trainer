import Foundation

struct DailyAttemptRecord: Codable, Equatable, Hashable {
    var gameID: String
    var localDayIdentifier: String
    var freeAttemptsUsed: Int
    var rewardedAttemptsRemaining: Int

    static func fresh(gameID: String, day: String) -> DailyAttemptRecord {
        DailyAttemptRecord(
            gameID: gameID,
            localDayIdentifier: day,
            freeAttemptsUsed: 0,
            rewardedAttemptsRemaining: 0
        )
    }

    func freeRemaining(limit: Int) -> Int {
        max(0, limit - freeAttemptsUsed)
    }

    func totalRemaining(limit: Int) -> Int {
        freeRemaining(limit: limit) + max(0, rewardedAttemptsRemaining)
    }
}

struct AttemptPersistenceBox: Codable, Equatable {
    var version: Int
    var records: [String: DailyAttemptRecord]
}
