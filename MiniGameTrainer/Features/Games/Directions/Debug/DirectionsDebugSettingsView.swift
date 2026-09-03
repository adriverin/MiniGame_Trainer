#if DEBUG
import SwiftUI

struct DirectionsDebugSettingsView: View {
    @ObservedObject var store: DirectionsTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sequence") {
                    Stepper("Length offset: \(store.config.sequenceLengthOffset)", value: $store.config.sequenceLengthOffset, in: 0...8)
                    Stepper("Length cap: \(store.config.sequenceLengthCap)", value: $store.config.sequenceLengthCap, in: 3...24)
                    Toggle("Allow consecutive repeats", isOn: $store.config.allowsConsecutiveRepeats)
                    Text("Reference: length = level + 2 (level 1 → 3, level 12 → 14).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Presentation timing") {
                    slider("Arrow on", value: $store.config.arrowOnDuration, in: 0.15...1.2, format: "%.3f s")
                    slider("Inter-arrow gap", value: $store.config.interArrowGap, in: 0...0.8, format: "%.3f s")
                    slider("Recall transition", value: $store.config.transitionToRecallDuration, in: 0...1, format: "%.3f s")
                    slider("Correct hold", value: $store.config.roundSuccessHoldDuration, in: 0...1.5, format: "%.2f s")
                    Text("Reference timing is constant across levels. Difficulty comes from length.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Geometry") {
                    slider("Observe arrow width", value: $store.config.observeArrowWidthRatio, in: 0.16...0.45, format: "%.3f")
                    slider("Observe arrow Y", value: $store.config.observeArrowCenterYRatio, in: 0.30...0.65, format: "%.3f")
                    slider("Button size", value: $store.config.buttonSizeRatio, in: 0.14...0.30, format: "%.3f")
                    slider("Button gap", value: $store.config.buttonGapRatio, in: 0.01...0.10, format: "%.3f")
                    slider("D-pad Y", value: $store.config.dpadCenterYRatio, in: 0.22...0.55, format: "%.3f")
                    slider("Hit padding", value: $store.config.buttonHitPaddingRatio, in: 1.00...1.20, format: "%.2f")
                }

                Section("Deterministic QA") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry hitboxes", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip presentation", isOn: $store.debugOptions.skipPresentation)
                    Toggle("Auto-input correct", isOn: $store.debugOptions.autoInputCorrect)
                    Stepper(
                        "Fail at input: \(store.debugOptions.autoInputFailAt.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { store.debugOptions.autoInputFailAt ?? -1 },
                            set: { store.debugOptions.autoInputFailAt = $0 < 0 ? nil : $0 }
                        ),
                        in: -1...20
                    )
                    Stepper(
                        "Forced level: \(store.debugOptions.forcedLevel.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { store.debugOptions.forcedLevel ?? 0 },
                            set: { store.debugOptions.forcedLevel = $0 <= 0 ? nil : $0 }
                        ),
                        in: 0...50
                    )
                    Stepper(
                        "Forced length: \(store.debugOptions.sequenceLengthOverride.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { store.debugOptions.sequenceLengthOverride ?? 0 },
                            set: { store.debugOptions.sequenceLengthOverride = $0 <= 0 ? nil : $0 }
                        ),
                        in: 0...20
                    )
                    Text("Launch: -autoPlay directions -directionsAutoInput -directionsOverlay -directionsLevel 12 -directionsSeed 1 -directionsFailAt 3 -directionsSequence up,left,down,right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("Directions Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func slider(_ title: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, Double(value.wrappedValue))).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
#endif
