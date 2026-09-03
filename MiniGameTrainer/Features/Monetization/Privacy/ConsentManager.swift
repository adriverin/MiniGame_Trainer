import Foundation
import Combine
import UserMessagingPlatform
import UIKit

@MainActor
final class ConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var isUpdating = false
    @Published private(set) var lastError: String?

    func updateAndPresentIfRequired() async {
        guard !isUpdating else { return }
        isUpdating = true
        lastError = nil
        defer { isUpdating = false }

        do {
            let parameters = UMPRequestParameters()
            parameters.tagForUnderAgeOfConsent = false
            #if DEBUG
            parameters.debugSettings = Self.debugParameters()
            #endif
            try await requestConsentInfoUpdate(parameters: parameters)
            try await loadAndPresentConsentFormIfRequired()
            refreshPublishedState()
            MonetizationLog.debug("UMP canRequestAds=\(canRequestAds) privacyOptions=\(privacyOptionsRequired)")
        } catch {
            lastError = error.localizedDescription
            refreshPublishedState()
            MonetizationLog.debug("UMP update failed: \(error.localizedDescription)")
        }
    }

    func presentPrivacyOptions() async {
        do {
            try await presentPrivacyOptionsForm()
            refreshPublishedState()
        } catch {
            lastError = error.localizedDescription
            MonetizationLog.debug("Privacy options failed: \(error.localizedDescription)")
        }
    }

    func refreshPublishedState() {
        let info = UMPConsentInformation.sharedInstance
        canRequestAds = info.canRequestAds
        privacyOptionsRequired = info.privacyOptionsRequirementStatus == .required
    }

    #if DEBUG
    func resetConsentForTesting() {
        UMPConsentInformation.sharedInstance.reset()
        refreshPublishedState()
    }

    /// Maps `umpDebugGeography` UserDefaults values onto UMP's geography enum.
    /// `other` / `notrequired` must be `.other` (no regulation), not `.disabled`.
    enum DebugGeography: Equatable {
        case eea
        case other
        case disabled
        case regulatedUSState

        static func parse(_ rawValue: String) -> DebugGeography? {
            switch rawValue.lowercased() {
            case "eea":
                return .eea
            case "other", "notrequired":
                return .other
            case "disabled":
                return .disabled
            case "regulated":
                return .regulatedUSState
            default:
                return nil
            }
        }

        var umpGeography: UMPDebugGeography {
            switch self {
            case .eea: return .EEA
            case .other: return .other
            case .disabled: return .disabled
            case .regulatedUSState: return .regulatedUSState
            }
        }
    }

    private static func debugParameters() -> UMPDebugSettings? {
        guard let raw = UserDefaults.standard.string(forKey: "umpDebugGeography"),
              let mapped = DebugGeography.parse(raw) else {
            return nil
        }
        let settings = UMPDebugSettings()
        settings.geography = mapped.umpGeography
        if let device = UserDefaults.standard.string(forKey: "umpDebugDeviceIdentifier") {
            settings.testDeviceIdentifiers = [device]
        }
        return settings
    }
    #endif

    private func requestConsentInfoUpdate(parameters: UMPRequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func loadAndPresentConsentFormIfRequired() async throws {
        let presenter = PresentingViewController.topMost()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UMPConsentForm.loadAndPresentIfRequired(from: presenter) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func presentPrivacyOptionsForm() async throws {
        let presenter = PresentingViewController.topMost()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UMPConsentForm.presentPrivacyOptionsForm(from: presenter) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
