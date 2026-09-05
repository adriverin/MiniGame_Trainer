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
            Section("Pro") {
                LabeledContent("\(AppInfo.name) Pro") {
                    Text(purchases.isPro ? "Active" : "Free Plan")
                        .foregroundStyle(purchases.isPro ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                }
                if purchases.isPro {
                    Label("Unlimited attempts", systemImage: "infinity")
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

            Section("Preferences") {
                Toggle("Sound", isOn: $preferences.soundEnabled)
                Toggle("Haptics", isOn: $preferences.hapticsEnabled)
            }

            Section("Statistics") {
                NavigationLink("View Statistics", value: AppRoute.statistics)
                Button("Reset All Statistics", role: .destructive) {
                    confirmReset = true
                }
            }

            if consent.privacyOptionsRequired {
                Section("Privacy") {
                    Button("Privacy Options") {
                        Task { await consent.presentPrivacyOptions() }
                    }
                }
            }

            Section("Legal") {
                Link("Terms of Use", destination: MonetizationConfiguration.termsOfUseURL)
                Link("Privacy Policy", destination: MonetizationConfiguration.privacyPolicyURL)
            }

            #if DEBUG
            MonetizationDebugSection()
            #endif

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Text(AppInfo.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .font(AppTheme.Fonts.body)
        .tint(AppTheme.Colors.accent)
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { statistics.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}
