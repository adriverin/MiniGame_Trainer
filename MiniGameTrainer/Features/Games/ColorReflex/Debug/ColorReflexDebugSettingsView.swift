#if DEBUG
import SwiftUI

struct ColorReflexDebugSettingsView: View {
    @ObservedObject var store: ColorReflexTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    slider("Duration", value: $store.config.sessionDuration, in: 5...90, format: "%.1f s")
                    slider("Min wait", value: $store.config.minWait, in: 0.1...4, format: "%.2f s")
                    slider("Max wait", value: $store.config.maxWait, in: 0.2...8, format: "%.2f s")
                    slider("Premature penalty", value: $store.config.prematurePenalty, in: 0...5, format: "%.2f s")
                    Toggle("Reset wait after false start", isOn: $store.config.prematureResetsWait)
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                }

                Section("Geometry") {
                    slider("Score Y from bottom", value: $store.config.scoreYRatio, in: 0.62...0.88, format: "%.3f")
                    slider("Prompt Y from bottom", value: $store.config.promptYRatio, in: 0.32...0.62, format: "%.3f")
                    slider("Reaction Y from bottom", value: $store.config.reactionYRatio, in: 0.16...0.42, format: "%.3f")
                    slider("Bar width / viewport", value: $store.config.barWidthRatio, in: 0.55...0.92, format: "%.3f")
                    slider("Bar height / viewport", value: $store.config.barHeightRatio, in: 0.006...0.03, format: "%.3f")
                    slider("Bar Y from bottom", value: $store.config.barCenterYRatio, in: 0.86...0.98, format: "%.3f")
                }

                Section("Bar stages") {
                    slider("Green above", value: $store.config.greenRemainingThreshold, in: 0.30...0.80, format: "%.2f")
                    slider("Orange above", value: $store.config.orangeRemainingThreshold, in: 0.08...0.40, format: "%.2f")
                }

                Section("Diagnostics") {
                    Toggle("Timing overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry overlay", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip start cue", isOn: $store.debugOptions.skipStartCue)
                    Toggle("Auto-react", isOn: $store.debugOptions.autoReact)
                    slider("Auto-react delay", value: $store.debugOptions.autoReactDelay, in: 0.05...0.40, format: "%.3f s")
                    Toggle("Auto premature tap", isOn: $store.debugOptions.autoPremature)
                    slider("Auto premature at", value: $store.debugOptions.autoPrematureAt, in: 0.05...2.0, format: "%.2f s")
                    Stepper(
                        "Forced score: \(store.debugOptions.forcedScore.map(String.init) ?? "off")",
                        value: forcedScoreBinding,
                        in: 0...80
                    )
                    Stepper(
                        "Seed: \(store.debugOptions.seed.map(String.init) ?? "\(store.config.generatorSeed)")",
                        value: seedBinding,
                        in: 1...9_999
                    )
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("COLOR REFLEX Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var forcedScoreBinding: Binding<Int> {
        Binding(
            get: { store.debugOptions.forcedScore ?? 0 },
            set: { store.debugOptions.forcedScore = $0 == 0 ? nil : $0 }
        )
    }

    private var seedBinding: Binding<Int> {
        Binding(
            get: { Int(store.debugOptions.seed ?? store.config.generatorSeed) },
            set: { value in
                store.debugOptions.seed = UInt64(value)
                store.config.generatorSeed = UInt64(value)
            }
        )
    }

    private func slider(
        _ title: String,
        value: Binding<CGFloat>,
        in range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, Double(value.wrappedValue)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
#endif
