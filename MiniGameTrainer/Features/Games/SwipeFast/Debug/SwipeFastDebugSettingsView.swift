#if DEBUG
import SwiftUI

struct SwipeFastDebugSettingsView: View {
    @ObservedObject var store: SwipeFastTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Timers") {
                    slider("Score 0 allowed time", value: durationBinding(0), in: 0.4...4, format: "%.2f s")
                    slider("Score 70 allowed time", value: durationBinding(7), in: 0.4...3, format: "%.2f s")
                    slider("Minimum allowed time", value: $store.config.minimumAllowedTime, in: 0.4...2, format: "%.2f s")
                    LabeledContent("Preview at 35") {
                        Text(String(format: "%.2f s", SwipeFastDifficultyModel(config: store.config).allowedTime(forScore: 35)))
                            .monospacedDigit()
                    }
                }

                Section("Gesture") {
                    slider("Min swipe / box", value: $store.config.minimumSwipeDistanceRatio, in: 0.06...0.30, format: "%.2f")
                    slider("Max gesture duration", value: $store.config.maximumGestureDuration, in: 0.2...2, format: "%.2f s")
                    Picker("Wrong swipe", selection: $store.config.wrongSwipeBehavior) {
                        Text("Ignore").tag(SwipeFastWrongSwipeBehavior.ignore)
                        Text("Game over").tag(SwipeFastWrongSwipeBehavior.gameOver)
                    }
                    Toggle("Avoid immediate direction repeat", isOn: $store.config.avoidImmediateRepeat)
                }

                Section("Geometry") {
                    slider("Box size / width", value: $store.config.boxSizeRatio, in: 0.28...0.46, format: "%.3f")
                    slider("Gap / width", value: $store.config.boxGapRatio, in: 0.02...0.08, format: "%.3f")
                    slider("Grid Y from bottom", value: $store.config.boxGridCenterYRatio, in: 0.32...0.55, format: "%.3f")
                    slider("Corner radius / box", value: $store.config.boxCornerRadiusRatio, in: 0.08...0.28, format: "%.3f")
                    slider("Arrow / box", value: $store.config.arrowSizeRatio, in: 0.30...0.62, format: "%.3f")
                    slider("Bar height / box", value: $store.config.barHeightRatio, in: 0.03...0.10, format: "%.3f")
                }

                Section("Urgency colors") {
                    slider("Cyan above", value: $store.config.cyanRemainingThreshold, in: 0.35...0.80, format: "%.2f")
                    slider("Yellow above", value: $store.config.yellowRemainingThreshold, in: 0.18...0.50, format: "%.2f")
                    slider("Orange above", value: $store.config.orangeRemainingThreshold, in: 0.05...0.30, format: "%.2f")
                }

                Section("Diagnostics") {
                    Toggle("Timer overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry overlay", isOn: $store.debugOptions.showGeometry)
                    Toggle("Auto-play correct", isOn: $store.debugOptions.autoPlay)
                    Toggle("Auto-play wrong", isOn: $store.debugOptions.autoPlayWrong)
                    Toggle("Auto-expire", isOn: $store.debugOptions.autoPlayExpire)
                    slider("Auto-play delay", value: $store.debugOptions.autoPlayReactionDelay, in: 0...0.4, format: "%.2f s")
                    Stepper(
                        "Forced score: \(store.debugOptions.forcedScore.map(String.init) ?? "off")",
                        value: forcedScoreBinding,
                        in: 0...200
                    )
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("SWIPE FAST Tuning")
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

    private func durationBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                let values = store.config.difficultyAnchorDurations
                guard values.indices.contains(index) else { return 1 }
                return values[index]
            },
            set: { value in
                var durations = store.config.difficultyAnchorDurations
                while durations.count <= index { durations.append(durations.last ?? 1) }
                durations[index] = value
                store.config.difficultyAnchorDurations = durations
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
