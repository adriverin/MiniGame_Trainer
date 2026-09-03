#if DEBUG
import SwiftUI

struct TimesUpDebugSettingsView: View {
    @ObservedObject var store: TimesUpTuningStore
    @Environment(\.dismiss) private var dismiss

    private var previewGeometry: TimesUpGeometry {
        TimesUpGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Stepper("Levels: \(store.config.levelCount)", value: $store.config.levelCount, in: 1...8)
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                    slider("Visibility fraction", value: $store.config.visibilityFraction, in: 0.2...0.9, format: "%.2f")
                    slider("Disappear fade", value: $store.config.disappearFadeDuration, in: 0...0.6, format: "%.2f s")
                    slider("Result hold", value: $store.config.sessionEndHoldDuration, in: 0...1.5, format: "%.2f s")
                }

                Section("Target duration per level") {
                    durationStepper(0)
                    durationStepper(1)
                    durationStepper(2)
                    Text("Defaults are the drain-to-empty fits from the reference recording (~10 s). Changing one level does not ramp the others.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Bar geometry") {
                    slider("Width / viewport", value: $store.config.barWidthRatio, in: 0.14...0.45, format: "%.3f")
                    slider("Height / viewport", value: $store.config.barHeightRatio, in: 0.22...0.58, format: "%.3f")
                    slider("Center X", value: $store.config.barCenterXRatio, in: 0.35...0.65, format: "%.3f")
                    slider("Center Y from bottom", value: $store.config.barCenterYRatio, in: 0.28...0.60, format: "%.3f")
                    slider("Corner radius / width", value: $store.config.cornerRadiusRatio, in: 0.15...0.5, format: "%.3f")
                    slider("Instruction Y from bottom", value: $store.config.instructionYRatio, in: 0.62...0.88, format: "%.3f")
                    LabeledContent("Resolved bar") {
                        Text(String(format: "%.0f × %.0f pt", previewGeometry.barFrame.width, previewGeometry.barFrame.height))
                    }
                }

                Section("Diagnostics") {
                    Toggle("Timing overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry overlay", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip start cue", isOn: $store.debugOptions.skipStartCue)
                    Picker("Auto-play", selection: autoPlayBinding) {
                        Text("Off").tag(TimesUpAutoPlayMode.off)
                        Text("Exact").tag(TimesUpAutoPlayMode.exact)
                        Text("0.01 s late").tag(TimesUpAutoPlayMode.offset(0.01))
                        Text("0.03 s early").tag(TimesUpAutoPlayMode.offset(-0.03))
                        Text("Reference script").tag(TimesUpAutoPlayMode.scripted([0.01, -0.03, -0.16]))
                    }
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("TIME'S UP Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var autoPlayBinding: Binding<TimesUpAutoPlayMode> {
        Binding(
            get: { store.debugOptions.autoPlay },
            set: { store.debugOptions.autoPlay = $0 }
        )
    }

    private func durationStepper(_ index: Int) -> some View {
        Stepper(value: durationBinding(index), in: 1...20, step: 0.5) {
            HStack {
                Text("Level \(index + 1)")
                Spacer()
                Text(String(format: "%.1f s", store.config.targetDuration(forLevelIndex: index)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func durationBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { store.config.targetDuration(forLevelIndex: index) },
            set: { value in
                var durations = store.config.targetDurations
                while durations.count <= index { durations.append(durations.last ?? 10) }
                durations[index] = value
                store.config.targetDurations = durations
            }
        )
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
