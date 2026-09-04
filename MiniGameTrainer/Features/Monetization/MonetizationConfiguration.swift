import Foundation

/// Central monetization constants. Production IDs and legal URLs that are not yet
/// supplied stay here as explicit placeholders — see Documentation/MANUAL_SETUP.md.
enum MonetizationConfiguration {
    static let freeAttemptsPerGamePerDay = 7
    static let rewardedAttemptGrant = 3
    static let persistenceVersion = 1
    static let persistenceKey = "attempts.v1"

    /// Final production bundle ID from `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`).
    /// Create this App ID in Apple Developer / App Store Connect.
    static let currentBundleID = "com.gamewe.minigametrainer"

    static let monthlyProductID = "com.gamewe.minigametrainer.pro.monthly"
    static let yearlyProductID = "com.gamewe.minigametrainer.pro.yearly"
    static let subscriptionGroupName = "MiniGameTrainer Pro"

    static var proProductIDs: Set<String> {
        [monthlyProductID, yearlyProductID]
    }

    /// REQUIRED MANUAL SETUP: replace with the production Privacy Policy URL.
    static let privacyPolicyURL = URL(string: "https://EXAMPLE-REQUIRED-PRIVACY-POLICY.invalid/privacy")!

    /// REQUIRED MANUAL SETUP: replace with the production Terms URL, or use Apple's standard EULA.
    static let termsOfUseURL = URL(string: "https://EXAMPLE-REQUIRED-TERMS.invalid/terms")!

    enum Ads {
        /// Official Google sample AdMob App ID for development. Not a production ID.
        static let googleSampleAdMobAppID = "ca-app-pub-3940256099942544~1458002511"

        /// REQUIRED MANUAL SETUP: production AdMob App ID. Paste into `project.yml`
        /// `info.properties.GADApplicationIdentifier` then run `xcodegen generate`.
        static let productionAdMobAppIDPlaceholder = "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"

        /// Official Google rewarded test unit. DEBUG builds always use this.
        static let googleTestRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

        /// REQUIRED MANUAL SETUP: production rewarded ad unit ID.
        static let productionRewardedAdUnitIDPlaceholder = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"

        static var rewardedAdUnitID: String {
            #if DEBUG
            googleTestRewardedAdUnitID
            #else
            productionRewardedAdUnitIDPlaceholder
            #endif
        }
    }
}
