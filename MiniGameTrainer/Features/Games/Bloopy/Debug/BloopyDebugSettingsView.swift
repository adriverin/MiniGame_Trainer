#if DEBUG
import SwiftUI

struct BloopyDebugSettingsView: View {
    @ObservedObject var store: BloopyTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Physics") {
                    slider("Gravity / height", value: $store.config.gravityHeightRatio, in: 1...10, format: "%.2f")
                    slider("Bounce impulse / height", value: $store.config.bounceImpulseHeightRatio, in: 0.4...3, format: "%.2f")
                    slider("Horizontal accel / width", value: $store.config.horizontalAccelerationWidthRatio, in: 0.4...6, format: "%.2f")
                    slider("Max VX / width", value: $store.config.maximumHorizontalSpeedWidthRatio, in: 0.3...3, format: "%.2f")
                    slider("Damping / s", value: $store.config.horizontalDampingPerSecond, in: 0...6, format: "%.2f")
                }

                Section("Camera and score") {
                    slider("Follow Y / height", value: $store.config.cameraFollowYRatio, in: 0.35...0.80, format: "%.2f")
                    slider("Failure margin / height", value: $store.config.failureMarginHeightRatio, in: 0...0.2, format: "%.3f")
                    slider("Score unit / height", value: $store.config.scoreUnitHeightRatio, in: 0.01...0.08, format: "%.3f")
                }

                Section("Platforms") {
                    slider("Initial width / width", value: $store.config.initialPlatformWidthRatio, in: 0.12...0.40, format: "%.3f")
                    slider("Minimum width / width", value: $store.config.minimumPlatformWidthRatio, in: 0.05...0.20, format: "%.3f")
                    slider("Initial spacing / height", value: $store.config.initialVerticalSpacingRatio, in: 0.08...0.30, format: "%.3f")
                    slider("Maximum spacing / height", value: $store.config.maximumVerticalSpacingRatio, in: 0.16...0.40, format: "%.3f")
                    slider("Reachability", value: $store.config.reachabilityMultiplier, in: 0.5...1.0, format: "%.2f")
                    Stepper("Lookahead: \(store.config.lookaheadPlatformCount)", value: $store.config.lookaheadPlatformCount, in: 3...16)
                }

                Section("Trail") {
                    slider("Sample interval", value: $store.config.trailSampleInterval, in: 0.02...0.12, format: "%.3f s")
                    slider("Lifetime", value: $store.config.trailLifetime, in: 0.2...1.2, format: "%.2f s")
                    Toggle("Show trail", isOn: $store.debugOptions.showTrail)
                }

                Section("Diagnostics") {
                    Toggle("Overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry", isOn: $store.debugOptions.showGeometry)
                    Toggle("Auto-steer", isOn: $store.debugOptions.autoSteer)
                    Stepper(
                        "Forced score: \(store.debugOptions.forcedScore.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { store.debugOptions.forcedScore ?? -1 },
                            set: { store.debugOptions.forcedScore = $0 < 0 ? nil : $0 }
                        ),
                        in: -1...800
                    )
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("Bloopy Tuning")
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
