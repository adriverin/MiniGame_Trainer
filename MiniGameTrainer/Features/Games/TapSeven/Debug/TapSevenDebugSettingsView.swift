#if DEBUG
import SwiftUI

struct TapSevenDebugSettingsView: View {
    @ObservedObject var store: TapSevenTuningStore
    @Environment(\.dismiss) private var dismiss

    private var previewGeometry: TapSevenGeometry {
        TapSevenGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Timing") {
                    slider("Target duration", value: $store.config.targetDuration, in: 1...20, format: "%.3f s")
                    slider("Perfect threshold", value: $store.config.perfectThreshold, in: 0...0.02, format: "%.4f s")
                    slider("Max attempt", value: $store.config.maxAttemptDuration, in: 7.05...30, format: "%.1f s")
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                    slider("Result hold", value: $store.config.sessionEndHoldDuration, in: 0...2, format: "%.2f s")
                    Text("Target stays at 7.000 unless you are calibrating. Max attempt is a trainer safety timeout; the source never shows a no-tap past 7.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Ring geometry") {
                    slider("Diameter / viewport", value: $store.config.ringDiameterRatio, in: 0.40...0.80, format: "%.3f")
                    slider("Stroke / viewport", value: $store.config.ringStrokeRatio, in: 0.030...0.120, format: "%.3f")
                    slider("Center X", value: $store.config.ringCenterXRatio, in: 0.40...0.60, format: "%.3f")
                    slider("Center Y from bottom", value: $store.config.ringCenterYRatio, in: 0.38...0.64, format: "%.3f")
                    slider("Instruction Y from bottom", value: $store.config.instructionYRatio, in: 0.18...0.42, format: "%.3f")
                    slider("Timer font / width", value: $store.config.timerFontSizeRatio, in: 0.12...0.30, format: "%.3f")
                    LabeledContent("Resolved ring") {
                        Text(String(
                            format: "r %.0f  stroke %.0f pt",
                            previewGeometry.ringRadius,
                            previewGeometry.strokeWidth
                        ))
                    }
                }

                Section("Diagnostics") {
                    Toggle("Timing overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry overlay", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip start cue", isOn: $store.debugOptions.skipStartCue)
                    Picker("Auto-tap offset", selection: autoTapBinding) {
                        Text("Off").tag(Optional<TimeInterval>.none)
                        Text("0.000 exact").tag(Optional(0.0))
                        Text("−0.010 early").tag(Optional(-0.010))
                        Text("+0.010 late").tag(Optional(0.010))
                        Text("−0.050 early").tag(Optional(-0.050))
                        Text("+0.050 late").tag(Optional(0.050))
                        Text("+0.250 late").tag(Optional(0.250))
                    }
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("TAP AT 7 Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var autoTapBinding: Binding<TimeInterval?> {
        Binding(
            get: { store.debugOptions.autoTapOffset },
            set: { store.debugOptions.autoTapOffset = $0 }
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
