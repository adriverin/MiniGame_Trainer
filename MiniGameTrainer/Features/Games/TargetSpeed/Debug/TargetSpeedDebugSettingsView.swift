#if DEBUG
import SwiftUI

struct TargetSpeedDebugSettingsView: View {
    @ObservedObject var store: TargetSpeedTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Difficulty") {
                    slider("Score 0 lifetime", value: lifetimeBinding(0), in: 0.6...2.4, format: "%.2f s")
                    slider("Score 700 lifetime", value: lifetimeBinding(7), in: 0.6...2.0, format: "%.2f s")
                    slider("Score 0 spawn", value: spawnBinding(0), in: 0.12...0.8, format: "%.2f s")
                    slider("Score 700 spawn", value: spawnBinding(7), in: 0.12...0.6, format: "%.2f s")
                    Stepper("Max active cap: \(store.config.maximumActiveTargets)", value: $store.config.maximumActiveTargets, in: 1...8)
                    LabeledContent("Preview at 350") {
                        let model = TargetSpeedDifficultyModel(config: store.config)
                        Text("L \(String(format: "%.2f", model.lifetime(forScore: 350)))  S \(String(format: "%.2f", model.spawnInterval(forScore: 350)))  A \(model.maxActive(forScore: 350))")
                            .font(.caption.monospacedDigit())
                    }
                }

                Section("Geometry") {
                    slider("Play min Y", value: $store.config.playMinYRatio, in: 0.04...0.24, format: "%.3f")
                    slider("Play max Y", value: $store.config.playMaxYRatio, in: 0.50...0.80, format: "%.3f")
                    slider("Min hit radius / width", value: $store.config.minimumHitRadiusRatio, in: 0.010...0.060, format: "%.3f")
                }

                Section("Diagnostics") {
                    Toggle("Debug overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Show hitboxes", isOn: $store.debugOptions.showHitboxes)
                    Toggle("Auto-hit", isOn: $store.debugOptions.autoHit)
                    Toggle("Auto-miss", isOn: $store.debugOptions.autoMiss)
                    slider("Auto-hit delay", value: $store.debugOptions.autoPlayReactionDelay, in: 0...0.6, format: "%.2f s")
                    Stepper(
                        "Forced score: \(store.debugOptions.forcedScore.map(String.init) ?? "off")",
                        value: forcedScoreBinding,
                        in: 0...800
                    )
                    Stepper(
                        "Forced lives: \(store.debugOptions.forcedLives.map(String.init) ?? "off")",
                        value: forcedLivesBinding,
                        in: 0...3
                    )
                    Toggle("Require tap to start", isOn: $store.config.requiresTapToStart)
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("TARGET SPEED Tuning")
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

    private var forcedLivesBinding: Binding<Int> {
        Binding(
            get: { store.debugOptions.forcedLives ?? 0 },
            set: { store.debugOptions.forcedLives = $0 == 0 ? nil : $0 }
        )
    }

    private func lifetimeBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard store.config.difficultyAnchorLifetimes.indices.contains(index) else { return 1.1 }
                return store.config.difficultyAnchorLifetimes[index]
            },
            set: { value in
                guard store.config.difficultyAnchorLifetimes.indices.contains(index) else { return }
                store.config.difficultyAnchorLifetimes[index] = value
            }
        )
    }

    private func spawnBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard store.config.difficultyAnchorSpawnIntervals.indices.contains(index) else { return 0.2 }
                return store.config.difficultyAnchorSpawnIntervals[index]
            },
            set: { value in
                guard store.config.difficultyAnchorSpawnIntervals.indices.contains(index) else { return }
                store.config.difficultyAnchorSpawnIntervals[index] = value
            }
        )
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue)).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func slider(_ title: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        slider(title, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) }), in: Double(range.lowerBound)...Double(range.upperBound), format: format)
    }
}
#endif
