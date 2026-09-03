import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var statistics: StatisticsStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var consent: ConsentManager
    @State private var confirmReset = false
    @State private var restoreMessage: String?

    var body: some View {
        Form {
            Section("Subscription") {
                LabeledContent("Status", value: purchases.isPro ? "Pro" : "Free")
                if purchases.isPro {
                    Text("Pro active")
                        .foregroundStyle(AppTheme.Colors.success)
                } else {
                    Button("Get Pro") {
                        router.showPaywall()
                    }
                }
                Button("Restore Purchases") {
                    Task {
                        await purchases.restore()
                        switch purchases.actionState {
                        case .restored:
                            restoreMessage = purchases.isPro ? "Pro is active." : "No active Pro subscription found."
                        case .failed(let message):
                            restoreMessage = message
                        default:
                            restoreMessage = nil
                        }
                    }
                }
                .disabled(purchases.isBusy)
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Section("Feedback") {
                Toggle("Sound", isOn: $preferences.soundEnabled)
                Toggle("Haptics", isOn: $preferences.hapticsEnabled)
            }

            Section("Statistics") {
                ForEach(GameRegistry.descriptors) { descriptor in
                    let stats = statistics.statistics(for: descriptor.id)
                    LabeledContent(descriptor.name) {
                        Text("Best \(descriptor.scorePresentation.formatted(stats.bestScore)) · \(stats.gamesPlayed) played")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Button("Reset all statistics", role: .destructive) {
                    confirmReset = true
                }
            }

            Section("Legal") {
                if consent.privacyOptionsRequired {
                    Button("Privacy Options") {
                        Task { await consent.presentPrivacyOptions() }
                    }
                }
                Link("Terms of Use", destination: MonetizationConfiguration.termsOfUseURL)
                Link("Privacy Policy", destination: MonetizationConfiguration.privacyPolicyURL)
            }

            #if DEBUG
            MonetizationDebugSection()
            #endif

            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Text(AppInfo.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
        .navigationTitle("Settings")
        .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { statistics.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
