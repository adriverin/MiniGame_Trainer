#if DEBUG
import SwiftUI

struct CenterHitDebugSettingsView: View {
    @ObservedObject var store: CenterHitTuningStore
    @Environment(\.dismiss) private var dismiss

    private var previewGeometry: CenterHitGeometry {
        CenterHitGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Stepper("Attempts: \(store.config.attemptCount)", value: $store.config.attemptCount, in: 1...20)
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                    slider("Result hold", value: $store.config.sessionEndHoldDuration, in: 0...1.5, format: "%.2f s")
                    slider("Max simulation delta", value: $store.config.maximumSimulationDelta, in: 0.05...1, format: "%.2f s")
                }

                Section("Bar geometry") {
                    slider("Bar width / viewport", value: $store.config.barWidthRatio, in: 0.5...0.96, format: "%.3f")
                    slider("Bar height / width", value: $store.config.barHeightToWidthRatio, in: 0.10...0.36, format: "%.3f")
                    slider("Center Y from bottom", value: $store.config.barCenterYRatio, in: 0.15...0.50, format: "%.3f")
                    LabeledContent("Resolved bar") {
                        Text(String(format: "%.0f × %.0f pt", previewGeometry.barFrame.width, previewGeometry.barFrame.height))
                    }
                }

                Section("Zone widths per side") {
                    slider("Red", value: $store.config.redZoneRatio, in: 0.06...0.20, format: "%.3f")
                    slider("Orange", value: $store.config.orangeZoneRatio, in: 0.06...0.20, format: "%.3f")
                    slider("Yellow", value: $store.config.yellowZoneRatio, in: 0.08...0.22, format: "%.3f")
                    LabeledContent("Center green") {
                        Text(String(format: "%.1f%%", Double(store.config.normalizedZoneFractions[3] * 100)))
                    }
                }

                Section("Markers") {
                    slider("Indicator width / bar", value: $store.config.indicatorWidthToBarRatio, in: 0.005...0.04, format: "%.4f")
                    slider("Indicator height / bar", value: $store.config.indicatorHeightToBarRatio, in: 1...1.5, format: "%.2f")
                    slider("Center line width / bar", value: $store.config.centerLineWidthToBarRatio, in: 0.002...0.02, format: "%.4f")
                }

                Section("Speed levels (bar widths / s)") {
                    ForEach(0..<5, id: \.self) { index in
                        slider("Attempt \(index + 1)", value: speedBinding(index), in: 0.2...5, format: "%.2f")
                    }
                }

                Section("Precision mapping") {
                    slider("Perfect half-width / bar", value: $store.config.perfectCenterHalfWidthRatio, in: 0...0.10, format: "%.3f")
                    slider("Exponent", value: $store.config.precisionExponent, in: 0.25...3, format: "%.2f")
                    slider("Coefficient", value: $store.config.precisionCoefficient, in: 0.25...2, format: "%.2f")
                }

                Section("Initial state") {
                    slider("Position from left", value: $store.config.initialPositionRatio, in: 0...1, format: "%.3f")
                    Picker("Direction", selection: $store.config.initialDirection) {
                        ForEach(CenterHitDirection.allCases) { direction in
                            Text("\(direction.symbol) \(direction.displayName)").tag(direction)
                        }
                    }
                }

                Section("Diagnostics") {
                    Toggle("Timing overlay", isOn: $store.debugOptions.showTimingOverlay)
                    Toggle("Geometry overlay", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip start cue", isOn: $store.debugOptions.skipStartCue)
                    Toggle("Deterministic auto-taps", isOn: $store.debugOptions.autoTap)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("Center Hit Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func speedBinding(_ index: Int) -> Binding<CGFloat> {
        Binding(
            get: { store.config.speedRatio(forAttemptIndex: index) },
            set: { value in
                var levels = store.config.speedLevels
                while levels.count < 5 { levels.append(levels.last ?? 1) }
                levels[index] = value
                store.config.speedLevels = levels
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
