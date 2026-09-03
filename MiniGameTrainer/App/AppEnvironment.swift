import Foundation
import Combine

/// Application-wide services. Intentionally free of any game-specific state:
/// individual games only communicate back through `GameResult`.
@MainActor
final class AppEnvironment: ObservableObject {
    let statisticsStore: StatisticsStore
    let preferences: UserPreferences
    let feedback: FeedbackService
    let attemptManager: AttemptManager
    let purchaseManager: PurchaseManager
    let consentManager: ConsentManager
    let rewardedAdManager: RewardedAdManager

    init(
        userDefaults: UserDefaults = .standard,
        clock: DayClock = SystemDayClock(),
        calendar: Calendar = .autoupdatingCurrent,
        storeKitClient: StoreKitClient? = nil
    ) {
        statisticsStore = StatisticsStore(userDefaults: userDefaults)
        preferences = UserPreferences(userDefaults: userDefaults)
        feedback = FeedbackService(preferences: preferences)
        purchaseManager = PurchaseManager(client: storeKitClient)
        attemptManager = AttemptManager(
            userDefaults: userDefaults,
            clock: clock,
            calendar: calendar,
            entitlement: purchaseManager
        )
        consentManager = ConsentManager()
        rewardedAdManager = RewardedAdManager(consent: consentManager, entitlement: purchaseManager)
    }

    func startMonetization() async {
        purchaseManager.start()
        await consentManager.updateAndPresentIfRequired()
        await rewardedAdManager.syncWithConsentAndEntitlement()
    }
}
