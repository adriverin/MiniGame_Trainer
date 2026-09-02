import Foundation
import Combine

/// Application-wide services. Intentionally free of any game-specific state:
/// individual games only communicate back through `GameResult`.
@MainActor
final class AppEnvironment: ObservableObject {
    let statisticsStore: StatisticsStore
    let preferences: UserPreferences
    let feedback: FeedbackService

    init(userDefaults: UserDefaults = .standard) {
        statisticsStore = StatisticsStore(userDefaults: userDefaults)
        preferences = UserPreferences(userDefaults: userDefaults)
        feedback = FeedbackService(preferences: preferences)
    }
}
