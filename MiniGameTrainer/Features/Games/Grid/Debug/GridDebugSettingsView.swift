#if DEBUG
import SwiftUI

struct GridDebugSettingsView: View {
    @ObservedObject var store: GridTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Timing") {
                    slider("Presentation", value: $store.config.presentationDuration, in: 0.2...4, format: "%.2f s")
                    slider("Recall timeout", value: $store.config.recallTimeout, in: 3...40, format: "%.1f s")
                    slider("Feedback hold", value: $store.config.feedbackDuration, in: 0...1.5, format: "%.2f s")
                    slider("Result hold", value: $store.config.resultHoldDuration, in: 0...1.5, format: "%.2f s")
                }

                Section("Rules") {
                    Toggle("Allow deselection", isOn: $store.config.allowsDeselection)
                    Toggle("Wrong submit ends run", isOn: $store.config.incorrectSubmitEndsRun)
                    Toggle("Timeout ends run", isOn: $store.config.timeoutEndsRun)
                }

                Section("Geometry") {
                    slider("Grid width / viewport", value: $store.config.gridWidthRatio, in: 0.5...0.96, format: "%.3f")
                    slider("Grid height / viewport", value: $store.config.gridHeightRatio, in: 0.25...0.6, format: "%.3f")
                    slider("Grid center Y", value: $store.config.gridCenterYRatio, in: 0.3...0.7, format: "%.3f")
                    slider("Gap / cell", value: $store.config.cellGapToSizeRatio, in: 0.04...0.3, format: "%.3f")
                    slider("Corner / cell", value: $store.config.cellCornerRadiusRatio, in: 0.05...0.4, format: "%.3f")
                }

                Section("Force layout") {
                    optionalStepper("Level", value: $store.debugOptions.forceLevel, range: 1...20)
                    optionalStepper("Rows", value: $store.debugOptions.forceRows, range: 2...9)
                    optionalStepper("Columns", value: $store.debugOptions.forceColumns, range: 2...9)
                    optionalStepper("Targets", value: $store.debugOptions.forceTargetCount, range: 1...40)
                }

                Section("Deterministic QA") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Auto-correct", isOn: $store.debugOptions.autoCorrect)
                    Toggle("Force 3×3 QA pattern", isOn: $store.debugOptions.useQualityAssurancePattern)
                    Stepper(
                        "Seed: \(store.debugOptions.seed.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { Int(store.debugOptions.seed ?? 0) },
                            set: { store.debugOptions.seed = $0 == 0 ? nil : UInt64($0) }
                        ),
                        in: 0...10_000
                    )
                    optionalDuration("Presentation override", value: $store.debugOptions.presentationDurationOverride, range: 0.1...4)
                    optionalDuration("Timeout override", value: $store.debugOptions.recallTimeoutOverride, range: 1...40)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("GRID Tuning")
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

    private func slider(_ title: String, value: Binding<TimeInterval>, in range: ClosedRange<TimeInterval>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func optionalStepper(_ title: String, value: Binding<Int?>, range: ClosedRange<Int>) -> some View {
        Stepper(
            "\(title): \(value.wrappedValue.map(String.init) ?? "Off")",
            value: Binding(
                get: { value.wrappedValue ?? (range.lowerBound - 1) },
                set: { value.wrappedValue = $0 < range.lowerBound ? nil : $0 }
            ),
            in: (range.lowerBound - 1)...range.upperBound
        )
    }

    private func optionalDuration(_ title: String, value: Binding<TimeInterval?>, range: ClosedRange<TimeInterval>) -> some View {
        Stepper(
            "\(title): \(value.wrappedValue.map { String(format: "%.2f s", $0) } ?? "Off")",
            value: Binding(
                get: { value.wrappedValue ?? 0 },
                set: { value.wrappedValue = $0 <= 0 ? nil : $0 }
            ),
            in: 0...range.upperBound,
            step: 0.1
        )
    }
}
#endif
