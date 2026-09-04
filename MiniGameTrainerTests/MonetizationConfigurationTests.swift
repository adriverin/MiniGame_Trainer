import XCTest
@testable import MiniGameTrainer

final class MonetizationConfigurationTests: XCTestCase {
    private let googleSampleAppID = "ca-app-pub-3940256099942544~1458002511"
    private let googleTestRewardedID = "ca-app-pub-3940256099942544/1712485313"
    private let productionAppID = "ca-app-pub-2544426617197908~2256365307"
    private let productionRewardedID = "ca-app-pub-2544426617197908/1399895858"

    func testProductionLegalURLsAreHTTPSAndNotPlaceholders() {
        XCTAssertEqual(
            MonetizationConfiguration.privacyPolicyURL.absoluteString,
            "https://adriverin.github.io/gamewe_support/#privacy"
        )
        XCTAssertEqual(
            MonetizationConfiguration.termsOfUseURL.absoluteString,
            "https://adriverin.github.io/gamewe_support/#terms"
        )
        XCTAssertEqual(MonetizationConfiguration.privacyPolicyURL.scheme, "https")
        XCTAssertEqual(MonetizationConfiguration.termsOfUseURL.scheme, "https")
        XCTAssertFalse(MonetizationConfiguration.privacyPolicyURL.absoluteString.contains("EXAMPLE"))
        XCTAssertFalse(MonetizationConfiguration.termsOfUseURL.absoluteString.contains("EXAMPLE"))
        XCTAssertFalse(MonetizationConfiguration.privacyPolicyURL.absoluteString.contains("invalid"))
        XCTAssertFalse(MonetizationConfiguration.termsOfUseURL.absoluteString.contains("invalid"))
    }

    func testStoreKitProductIDsRemainCanonical() {
        XCTAssertEqual(MonetizationConfiguration.monthlyProductID, "com.gamewe.minigametrainer.pro.monthly")
        XCTAssertEqual(MonetizationConfiguration.yearlyProductID, "com.gamewe.minigametrainer.pro.yearly")
        XCTAssertEqual(MonetizationConfiguration.currentBundleID, "com.gamewe.minigametrainer")
        XCTAssertFalse(MonetizationConfiguration.monthlyProductID.contains("minigametrainer.app"))
        XCTAssertFalse(MonetizationConfiguration.yearlyProductID.contains("minigametrainer.app"))
    }

    func testProductionAdMobIDsAreRealAndDistinctFromGoogleSamples() {
        XCTAssertEqual(MonetizationConfiguration.Ads.productionAdMobAppID, productionAppID)
        XCTAssertEqual(MonetizationConfiguration.Ads.productionRewardedAdUnitID, productionRewardedID)
        XCTAssertEqual(MonetizationConfiguration.Ads.googleSampleAdMobAppID, googleSampleAppID)
        XCTAssertEqual(MonetizationConfiguration.Ads.googleTestRewardedAdUnitID, googleTestRewardedID)

        XCTAssertNotEqual(
            MonetizationConfiguration.Ads.productionAdMobAppID,
            MonetizationConfiguration.Ads.googleSampleAdMobAppID
        )
        XCTAssertNotEqual(
            MonetizationConfiguration.Ads.productionRewardedAdUnitID,
            MonetizationConfiguration.Ads.googleTestRewardedAdUnitID
        )
        XCTAssertFalse(MonetizationConfiguration.Ads.productionAdMobAppID.contains("XXXX"))
        XCTAssertFalse(MonetizationConfiguration.Ads.productionRewardedAdUnitID.contains("XXXX"))
        XCTAssertFalse(MonetizationConfiguration.Ads.productionAdMobAppID.contains("PLACEHOLDER"))
        XCTAssertFalse(MonetizationConfiguration.Ads.productionRewardedAdUnitID.contains("PLACEHOLDER"))
    }

    func testDebugRewardedUnitNeverRequestsProductionTraffic() {
        #if DEBUG
        XCTAssertEqual(
            MonetizationConfiguration.Ads.rewardedAdUnitID,
            MonetizationConfiguration.Ads.googleTestRewardedAdUnitID
        )
        XCTAssertNotEqual(
            MonetizationConfiguration.Ads.rewardedAdUnitID,
            MonetizationConfiguration.Ads.productionRewardedAdUnitID
        )
        #else
        XCTAssertEqual(
            MonetizationConfiguration.Ads.rewardedAdUnitID,
            MonetizationConfiguration.Ads.productionRewardedAdUnitID
        )
        XCTAssertNotEqual(
            MonetizationConfiguration.Ads.rewardedAdUnitID,
            MonetizationConfiguration.Ads.googleTestRewardedAdUnitID
        )
        #endif
    }

    func testInfoPlistUsesBuildSettingNotHardcodedSampleAppID() throws {
        let plist = try String(contentsOf: repositoryFile("MiniGameTrainer/Resources/Info.plist"), encoding: .utf8)
        XCTAssertTrue(plist.contains("$(GAD_APPLICATION_IDENTIFIER)"))
        XCTAssertFalse(plist.contains(googleSampleAppID))
        XCTAssertFalse(plist.contains("XXXXXXXXX"))
        XCTAssertFalse(plist.contains("PLACEHOLDER"))
    }

    func testProjectYmlSplitsAdMobAppIDByConfiguration() throws {
        let yaml = try String(contentsOf: repositoryFile("project.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("GADApplicationIdentifier: $(GAD_APPLICATION_IDENTIFIER)"))
        XCTAssertTrue(yaml.contains("GAD_APPLICATION_IDENTIFIER: \(googleSampleAppID)"))
        XCTAssertTrue(yaml.contains("GAD_APPLICATION_IDENTIFIER: \(productionAppID)"))

        let debugRange = try XCTUnwrap(yaml.range(of: "Debug:"))
        let releaseRange = try XCTUnwrap(yaml.range(of: "Release:", range: debugRange.upperBound..<yaml.endIndex))
        let debugBlock = yaml[debugRange.lowerBound..<releaseRange.lowerBound]
        let afterRelease = yaml[releaseRange.lowerBound...]
        let nextTopLevel = afterRelease.range(of: "\npackages:")?.lowerBound ?? afterRelease.endIndex
        let releaseBlock = afterRelease[..<nextTopLevel]

        XCTAssertTrue(debugBlock.contains(googleSampleAppID))
        XCTAssertFalse(debugBlock.contains(productionAppID))
        XCTAssertTrue(releaseBlock.contains(productionAppID))
        XCTAssertFalse(releaseBlock.contains(googleSampleAppID))
    }

    func testStoreKitConfigurationProductIDsMatchCode() throws {
        let data = try Data(contentsOf: repositoryFile("MiniGameTrainer/Resources/Monetization.storekit"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(json["subscriptionGroups"] as? [[String: Any]])
        let subscriptions = try XCTUnwrap(groups.first?["subscriptions"] as? [[String: Any]])
        let ids = Set(subscriptions.compactMap { $0["productID"] as? String })
        XCTAssertEqual(ids, MonetizationConfiguration.proProductIDs)
    }

    func testBusinessModelUnchanged() {
        XCTAssertEqual(MonetizationConfiguration.freeAttemptsPerGamePerDay, 7)
        XCTAssertEqual(MonetizationConfiguration.rewardedAttemptGrant, 3)
    }

    private func repositoryFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }
}
