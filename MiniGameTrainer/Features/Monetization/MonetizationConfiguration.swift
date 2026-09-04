import Foundation

/// Central monetization constants. Production AdMob IDs and legal URLs are set
/// here; DEBUG builds never request the production rewarded unit.
enum MonetizationConfiguration {
    static let freeAttemptsPerGamePerDay = 7
    static let rewardedAttemptGrant = 3
    static let persistenceVersion = 1
    static let persistenceKey = "attempts.v1"

    /// Final production bundle ID from `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`).
    static let currentBundleID = "com.gamewe.minigametrainer"

    static let monthlyProductID = "com.gamewe.minigametrainer.pro.monthly"
    static let yearlyProductID = "com.gamewe.minigametrainer.pro.yearly"
    static let subscriptionGroupName = "MiniGameTrainer Pro"

    static var proProductIDs: Set<String> {
        [monthlyProductID, yearlyProductID]
    }

    static let privacyPolicyURL = URL(string: "https://adriverin.github.io/gamewe_support/#privacy")!
    static let termsOfUseURL = URL(string: "https://adriverin.github.io/gamewe_support/#terms")!

    enum Ads {
        /// Official Google sample AdMob App ID. DEBUG `GADApplicationIdentifier` only.
        static let googleSampleAdMobAppID = "ca-app-pub-3940256099942544~1458002511"

        /// Production AdMob App ID. Release `GADApplicationIdentifier` only.
        static let productionAdMobAppID = "ca-app-pub-2544426617197908~2256365307"

        /// Official Google rewarded test unit. DEBUG builds always use this.
        static let googleTestRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

        /// Production rewarded ad unit. Release builds only.
        static let productionRewardedAdUnitID = "ca-app-pub-2544426617197908/1399895858"

        static var rewardedAdUnitID: String {
            #if DEBUG
            googleTestRewardedAdUnitID
            #else
            productionRewardedAdUnitID
            #endif
        }
    }
}
