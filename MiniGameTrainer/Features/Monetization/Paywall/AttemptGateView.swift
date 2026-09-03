import SwiftUI

struct AttemptGateView: View {
    let gameID: String

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var attempts: AttemptManager
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var ads: RewardedAdManager

    @State private var isWatching = false
    @State private var message: String?

    private var gameName: String {
        GameRegistry.descriptor(for: gameID)?.name ?? gameID
    }

    var body: some View {
        let _ = attempts.revision
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    Text(title)
                        .font(AppTheme.Fonts.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    if let message {
                        Text(message)
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.warning)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        contentButtons
                    }
                    .padding(.top, 8)
                }
                .padding(AppTheme.Metrics.screenPadding)
            }
        }
        .navigationTitle(gameName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            Task { await ads.preload() }
        }
    }

    @ViewBuilder
    private var contentButtons: some View {
        switch attempts.availability(for: gameID) {
        case .proUnlimited, .free, .rewarded:
            PrimaryButton(title: "PLAY", systemImage: "play.fill") {
                router.startGame(gameID)
            }
            PrimaryButton(title: "Back", systemImage: "chevron.left", style: .outlined) {
                router.quitToIntro()
            }
        case .exhausted:
            exhaustedButtons
        }
    }

    @ViewBuilder
    private var exhaustedButtons: some View {
        if ads.readiness == .loading || isWatching {
            PrimaryButton(title: isWatching ? "Showing ad…" : "Loading ad…", systemImage: "hourglass") {}
                .disabled(true)
        } else if ads.readiness == .unavailable {
            Text("Ad unavailable right now")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise") {
                Task { await ads.preload() }
            }
        } else {
            PrimaryButton(title: "Watch ad · +3 attempts", systemImage: "play.rectangle.fill") {
                Task { await watchAd() }
            }
            .disabled(isWatching || ads.readiness == .presenting)
        }

        PrimaryButton(title: "Get Pro · Unlimited", systemImage: "star.fill", style: .outlined) {
            router.showPaywall()
        }
        PrimaryButton(title: "Back", systemImage: "chevron.left", style: .outlined) {
            router.quitToIntro()
        }
    }

    private var title: String {
        switch attempts.availability(for: gameID) {
        case .proUnlimited, .free, .rewarded:
            return "Ready to play"
        case .exhausted:
            return "Free attempts used"
        }
    }

    private var subtitle: String {
        switch attempts.availability(for: gameID) {
        case .proUnlimited:
            return "Pro is active. Play \(gameName) anytime."
        case .free(let remaining):
            return "\(remaining) / \(attempts.freeLimit) free attempts remaining for \(gameName)."
        case .rewarded(let remaining):
            let noun = remaining == 1 ? "attempt" : "attempts"
            return "\(remaining) bonus \(noun) remaining for \(gameName)."
        case .exhausted:
            return "You've used today's free attempts for \(gameName)."
        }
    }

    private func watchAd() async {
        guard !isWatching else { return }
        isWatching = true
        defer { isWatching = false }
        message = nil
        let result = await ads.watchAd(for: gameID, grantTo: attempts)
        switch result {
        case .presented:
            message = nil
        case .notReady:
            message = "Ad unavailable right now"
        case .alreadyPresenting:
            break
        case .notPermitted:
            message = nil
        }
    }
}
