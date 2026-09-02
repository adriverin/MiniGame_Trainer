import Foundation
import Combine

/// UserDefaults-backed store of per-game statistics. Small data, no need for a database yet.
@MainActor
final class StatisticsStore: ObservableObject {
    @Published private(set) var statistics: [String: GameStatistics]

    private let userDefaults: UserDefaults
    private let storageKey = "statistics.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: GameStatistics].self, from: data) {
            statistics = decoded
        } else {
            statistics = [:]
        }
    }

    func statistics(for gameID: String) -> GameStatistics {
        statistics[gameID] ?? GameStatistics(gameID: gameID)
    }

    func bestScore(for gameID: String) -> Int {
        statistics[gameID]?.bestScore ?? 0
    }

    @discardableResult
    func record(_ result: GameResult) -> GameStatistics {
        var entry = statistics(for: result.gameID)
        entry.record(result)
        statistics[result.gameID] = entry
        persist()
        return entry
    }

    func reset(gameID: String) {
        statistics[gameID] = nil
        persist()
    }

    func resetAll() {
        statistics = [:]
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(statistics) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
