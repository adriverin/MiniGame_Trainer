#if DEBUG
import SwiftUI

struct TraceDebugSettingsView: View {
    @ObservedObject var store: TraceTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Grid") {
                    Stepper("Forced rows: \(store.debugOptions.forcedRows.map(String.init) ?? "Off")", value: intOptional($store.debugOptions.forcedRows), in: 0...12)
                    Stepper("Forced columns: \(store.debugOptions.forcedColumns.map(String.init) ?? "Off")", value: intOptional($store.debugOptions.forcedColumns), in: 0...12)
                    Stepper("Forced target count: \(store.debugOptions.forcedTargetCount.map(String.init) ?? "Off")", value: intOptional($store.debugOptions.forcedTargetCount), in: 0...20)
                    slider("Footprint width", value: $store.config.gridWidthRatio, in: 0.4...0.95, format: "%.3f")
                    slider("Footprint height", value: $store.config.gridHeightRatio, in: 0.3...0.75, format: "%.3f")
                    slider("Center Y", value: $store.config.gridCenterYRatio, in: 0.25...0.6, format: "%.3f")
                }

                Section("Nodes and hit") {
                    slider("Visual radius / spacing", value: $store.config.nodeVisualRadiusToSpacing, in: 0.10...0.40, format: "%.3f")
                    slider("Hit radius / spacing", value: $store.config.nodeHitRadiusToSpacing, in: 0.20...0.55, format: "%.3f")
                    slider("Line width / spacing", value: $store.config.lineWidthToSpacing, in: 0.15...0.70, format: "%.3f")
                    Toggle("Require adjacent steps", isOn: $store.config.requireAdjacentSteps)
                    Toggle("Accept reverse sequence", isOn: $store.config.acceptReverseSequence)
                }

                Section("Timing") {
                    slider("Segment reveal", value: $store.config.segmentRevealDuration, in: 0.05...1.0, format: "%.2f s")
                    slider("Pattern hold", value: $store.config.patternHoldDuration, in: 0...1.2, format: "%.2f s")
                    slider("Recall base", value: $store.config.recallBaseDuration, in: 0.5...8, format: "%.2f s")
                    slider("Recall / segment", value: $store.config.recallDurationPerSegment, in: 0...2, format: "%.2f s")
                    slider("Session duration", value: $store.config.sessionDuration, in: 0...240, format: "%.0f s")
                    Toggle("Timeout ends session", isOn: $store.config.timeoutEndsSession)
                    Toggle("Wrong node ends session", isOn: $store.config.wrongNodeEndsSession)
                    Toggle("Restart pattern on background", isOn: $store.config.restartPatternOnBackground)
                }

                Section("Diagnostics") {
                    Toggle("DEBUG overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Hitboxes", isOn: $store.debugOptions.showHitboxes)
                    Toggle("Skip presentation", isOn: $store.debugOptions.skipPresentation)
                    Toggle("Auto-solve correct", isOn: $store.debugOptions.autoSolve)
                    Toggle("Auto-solve wrong node", isOn: $store.debugOptions.autoSolveWrong)
                    Stepper("Forced score: \(store.debugOptions.forcedScore.map(String.init) ?? "Off")", value: intOptional($store.debugOptions.forcedScore), in: -1...300)
                    Stepper("Seed: \(store.debugOptions.forcedSeed.map(String.init) ?? "Off")", value: uintOptional($store.debugOptions.forcedSeed), in: 0...10_000)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("Trace Tuning")
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

    private func intOptional(_ binding: Binding<Int?>) -> Binding<Int> {
        Binding(
            get: { binding.wrappedValue ?? 0 },
            set: { binding.wrappedValue = $0 <= 0 ? nil : $0 }
        )
    }

    private func uintOptional(_ binding: Binding<UInt64?>) -> Binding<Int> {
        Binding(
            get: { Int(binding.wrappedValue ?? 0) },
            set: { binding.wrappedValue = $0 <= 0 ? nil : UInt64($0) }
        )
    }
}
#endif
