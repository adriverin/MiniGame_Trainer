#if DEBUG
import SwiftUI

struct ReactDebugSettingsView: View {
    @ObservedObject var store: ReactTuningStore
    @Environment(\.dismiss) private var dismiss
    @State private var seedText = ""

    private var previewGeometry: ReactGeometry {
        ReactGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    Stepper("Rounds: \(store.config.roundCount)", value: $store.config.roundCount, in: 1...20)
                    slider("Minimum delay", value: $store.config.minimumStimulusDelay, in: 0.25...5, format: "%.2f s")
                    slider("Maximum delay", value: $store.config.maximumStimulusDelay, in: 0.25...7, format: "%.2f s")
                    slider("Feedback state", value: $store.config.feedbackDuration, in: 0...1.5, format: "%.2f s")
                    slider("Result hold", value: $store.config.sessionEndHoldDuration, in: 0...1.5, format: "%.2f s")
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                }

                Section("Grid geometry") {
                    slider("Circle diameter / width", value: $store.config.circleDiameterRatio, in: 0.12...0.26, format: "%.3f")
                    slider("Horizontal gap / diameter", value: $store.config.horizontalGapToDiameterRatio, in: 0...0.5, format: "%.3f")
                    slider("Vertical gap / diameter", value: $store.config.verticalGapToDiameterRatio, in: 0...0.5, format: "%.3f")
                    slider("Center X", value: $store.config.gridCenterXRatio, in: 0.4...0.6, format: "%.3f")
                    slider("Center Y from bottom", value: $store.config.gridCenterYRatio, in: 0.3...0.65, format: "%.3f")
                    LabeledContent("Resolved diameter") { Text(String(format: "%.1f pt", previewGeometry.circleDiameter)) }
                    LabeledContent("Resolved grid") { Text(String(format: "%.0f × %.0f pt", previewGeometry.gridWidth, previewGeometry.gridHeight)) }
                }

                Section("Visual contrast") {
                    slider("Active red", value: $store.config.activeRed, in: 0...1, format: "%.2f")
                    slider("Active green", value: $store.config.activeGreen, in: 0...1, format: "%.2f")
                    slider("Active blue", value: $store.config.activeBlue, in: 0...1, format: "%.2f")
                    slider("Inactive intensity", value: $store.config.inactiveIntensity, in: 0.35...1.8, format: "%.2f")
                }

                Section("Invalid input") {
                    Picker("Early tap", selection: $store.config.earlyTapRule) {
                        ForEach(ReactInvalidTapRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Wrong target", selection: $store.config.wrongTapRule) {
                        ForEach(ReactInvalidTapRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    slider("Penalty duration", value: $store.config.invalidTapPenalty, in: 0.25...3, format: "%.2f s")
                    Toggle("Prevent immediate repeat", isOn: $store.config.preventImmediateRepeat)
                }

                Section("Determinism") {
                    TextField("Seed (blank = random)", text: $seedText)
                        .keyboardType(.numberPad)
                        .onChange(of: seedText) { _, value in store.config.randomSeed = UInt64(value) }
                }

                Section("Diagnostics") {
                    Toggle("Timing overlay", isOn: $store.debugOptions.showTimingOverlay)
                    Toggle("Hitboxes", isOn: $store.debugOptions.showHitboxes)
                    Toggle("Skip start cue", isOn: $store.debugOptions.skipStartCue)
                    Toggle("Auto-tap at 288 ms (visual QA)", isOn: $store.debugOptions.autoTap)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) {
                        store.resetToReference()
                        seedText = ""
                    }
                }
            }
            .navigationTitle("REACT Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { seedText = store.config.randomSeed.map(String.init) ?? "" }
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
