import Foundation
import Combine
import GoogleMobileAds
import UIKit

enum RewardedAdReadiness: Equatable {
    case idle
    case loading
    case ready
    case presenting
    case unavailable
}

enum RewardedPresentationResult: Equatable {
    case presented
    case notReady
    case alreadyPresenting
    case notPermitted
}

@MainActor
final class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var readiness: RewardedAdReadiness = .idle
    @Published private(set) var lastError: String?

    let grantSession = RewardedGrantSession()
    private let entitlement: ProEntitlementStatus
    private let consent: ConsentManager
    private var rewardedAd: RewardedAd?
    private var didStartMobileAds = false
    private var isLoading = false
    private var activeToken: UUID?

    init(consent: ConsentManager, entitlement: ProEntitlementStatus) {
        self.consent = consent
        self.entitlement = entitlement
        super.init()
    }

    var isReady: Bool { readiness == .ready }

    func syncWithConsentAndEntitlement() async {
        if entitlement.isEnabled(.noRewardedAds) {
            MonetizationLog.debug("Skipping ads for Pro")
            return
        }
        guard consent.canRequestAds else {
            MonetizationLog.debug("Ads blocked by UMP canRequestAds=false")
            return
        }
        await startMobileAdsIfNeeded()
        await preload()
    }

    func preload() async {
        guard !entitlement.isEnabled(.noRewardedAds) else { return }
        guard consent.canRequestAds else { return }
        guard rewardedAd == nil, !isLoading, readiness != .presenting else { return }

        isLoading = true
        readiness = .loading
        lastError = nil
        let unitID = MonetizationConfiguration.Ads.rewardedAdUnitID
        let result: Result<RewardedAd, Error> = await withCheckedContinuation { continuation in
            RewardedAd.load(with: unitID, request: Request()) { ad, error in
                if let ad {
                    continuation.resume(returning: .success(ad))
                } else {
                    let loadError = error ?? NSError(
                        domain: "RewardedAdManager",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Ad unavailable right now"]
                    )
                    continuation.resume(returning: .failure(loadError))
                }
            }
        }
        switch result {
        case .success(let ad):
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            readiness = .ready
            MonetizationLog.debug("Rewarded ad ready")
        case .failure(let error):
            rewardedAd = nil
            readiness = .unavailable
            lastError = "Ad unavailable right now"
            MonetizationLog.debug("Rewarded load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func watchAd(for gameID: String, grantTo attemptManager: AttemptManager) async -> RewardedPresentationResult {
        if entitlement.isEnabled(.noRewardedAds) {
            return .notPermitted
        }
        guard attemptManager.canRequestRewardedGrant(for: gameID) else {
            return .notPermitted
        }
        guard let token = grantSession.begin(gameID: gameID) else {
            return .alreadyPresenting
        }
        activeToken = token

        if rewardedAd == nil {
            await preload()
        }
        guard let ad = rewardedAd else {
            grantSession.end(token: token)
            activeToken = nil
            readiness = .unavailable
            return .notReady
        }

        readiness = .presenting
        let capturedGameID = gameID
        ad.present(from: PresentingViewController.topMost()) { [weak self] in
            guard let self else { return }
            if let rewardedGameID = self.grantSession.consumeReward(token: token) {
                _ = attemptManager.grantRewardedAttempts(
                    MonetizationConfiguration.rewardedAttemptGrant,
                    for: rewardedGameID
                )
                MonetizationLog.debug("Reward callback granted +\(MonetizationConfiguration.rewardedAttemptGrant) for \(rewardedGameID)")
            } else {
                MonetizationLog.debug("Ignored duplicate reward callback for \(capturedGameID)")
            }
        }
        return .presented
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastError = "Ad unavailable right now"
        MonetizationLog.debug("Rewarded present failed: \(error.localizedDescription)")
        finishPresentation()
    }

    private func finishPresentation() {
        if let token = activeToken {
            grantSession.end(token: token)
        }
        activeToken = nil
        rewardedAd = nil
        if readiness == .presenting {
            readiness = .idle
        }
        Task { await preload() }
    }

    private func startMobileAdsIfNeeded() async {
        guard !didStartMobileAds else { return }
        didStartMobileAds = true
        await withCheckedContinuation { continuation in
            MobileAds.shared.start { _ in
                continuation.resume()
            }
        }
        MonetizationLog.debug("Mobile Ads started")
    }
}
