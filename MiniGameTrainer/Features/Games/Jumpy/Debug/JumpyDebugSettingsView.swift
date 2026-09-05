#if DEBUG
import SwiftUI

struct JumpyDebugSettingsView: View {
    @ObservedObject var store: JumpyTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    doubleSlider("Hop duration", value: $store.config.hopDuration, in: 0.12...0.40, format: "%.2f s")
                    valueSlider("Swipe threshold", value: $store.config.gestureThreshold, in: 8...60, format: "%.0f pt")
                }
                Section("Traffic") {
                    valueSlider("Safety gap", value: $store.config.trafficSafetyGap, in: 0...0.20, format: "%.3f W")
                    valueSlider("Player hitbox", value: $store.config.playerHitboxScale, in: 0.4...1, format: "%.2f")
                    valueSlider("Vehicle hitbox", value: $store.config.vehicleHitboxScale, in: 0.4...1, format: "%.2f")
                    Stepper("Seed: \(store.config.randomSeed.map(String.init) ?? "Random")", value: Binding(
                        get: { Int(store.config.randomSeed ?? 0) },
                        set: { store.config.randomSeed = $0 == 0 ? nil : UInt64($0) }
                    ), in: 0...9999)
                }
                Section("QA") {
                    Toggle("Diagnostics overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Show hitboxes", isOn: $store.debugOptions.showHitboxes)
                    Toggle("Auto advance", isOn: $store.debugOptions.autoAdvance)
                    Toggle("Hold collision frame", isOn: $store.debugOptions.holdCollision)
                    Toggle("Control QA script", isOn: $store.debugOptions.controlQAScript)
                    Toggle("Disable collisions", isOn: $store.debugOptions.disableCollisions)
                    Stepper("Difficulty: \(store.debugOptions.forcedDifficultyScore.map(String.init) ?? "Live")", value: Binding(
                        get: { store.debugOptions.forcedDifficultyScore ?? -1 },
                        set: { store.debugOptions.forcedDifficultyScore = $0 < 0 ? nil : $0 }
                    ), in: -1...200)
                    Stepper("Starting score: \(store.config.startingScore)", value: $store.config.startingScore, in: 0...200)
                }
                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("JUMPY Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func valueSlider(_ title: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, Double(value.wrappedValue)))
            Slider(value: value, in: range)
        }
    }

    private func doubleSlider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, value.wrappedValue))
            Slider(value: value, in: range)
        }
    }
}
#endif
