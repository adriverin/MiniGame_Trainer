import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var statistics: StatisticsStore
    @State private var confirmReset = false

    var body: some View {
        Form {
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
