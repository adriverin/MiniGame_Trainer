#if DEBUG
import SwiftUI

struct TowerStackDebugSettingsView: View {
    @ObservedObject var store: TowerStackTuningStore
    @Environment(\.dismiss) private var dismiss

    private var difficulty: TowerStackDifficultyModel { TowerStackDifficultyModel(config: store.config) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debug") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showPerformanceOverlay)
                    Toggle("Logical geometry", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip hint", isOn: $store.debugOptions.skipHint)
                }

                Section("Deterministic test mode") {
                    Toggle("Auto-place", isOn: Binding(
                        get: { store.debugOptions.autoPlaceOffsetFraction != nil },
                        set: { store.debugOptions.autoPlaceOffsetFraction = $0 ? 0 : nil }
                    ))
                    if let fraction = store.debugOptions.autoPlaceOffsetFraction {
                        slider(
                            "Offset (fraction of target)",
                            value: Binding(get: { fraction }, set: { store.debugOptions.autoPlaceOffsetFraction = $0 }),
                            in: -0.5...0.5,
                            format: "%.3f"
                        )
                        Stepper(
                            "Miss at score: \(store.debugOptions.autoMissAtScore.map(String.init) ?? "never")",
                            value: Binding(
                                get: { store.debugOptions.autoMissAtScore ?? 0 },
                                set: { store.debugOptions.autoMissAtScore = $0 > 0 ? $0 : nil }
                            ),
                            in: 0...500,
                            step: 10
                        )
                    }
                    Stepper(
                        "Pause at score: \(store.debugOptions.pauseAtScore.map(String.init) ?? "never")",
                        value: Binding(
                            get: { store.debugOptions.pauseAtScore ?? 0 },
                            set: { store.debugOptions.pauseAtScore = $0 > 0 ? $0 : nil }
                        ),
                        in: 0...500,
                        step: 5
                    )
                }

                Section("Blocks") {
                    slider("Initial width", value: $store.config.initialWidth, in: 0.5...1.5, format: "%.2f")
                    slider("Initial depth", value: $store.config.initialDepth, in: 0.5...1.5, format: "%.2f")
                    slider("Block height / width", value: $store.config.blockHeight, in: 0.10...0.40, format: "%.3f")
                    slider("Pedestal height", value: $store.config.pedestalHeight, in: 1...8, format: "%.1f")
                }

                Section("Movement") {
                    slider("Initial speed (widths/s)", value: $store.config.initialSpeed, in: 0.5...3.0, format: "%.2f")
                    slider("Growth / point", value: $store.config.speedGrowthPerPoint, in: 0...0.02, format: "%.4f")
                    slider("Speed cap", value: $store.config.maximumSpeed, in: 2...8, format: "%.2f")
                    slider("Movement range (±)", value: $store.config.movementRange, in: 0.8...2.0, format: "%.2f")
                    Picker("First axis", selection: $store.config.firstAxis) {
                        ForEach(TowerStackAxis.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Spawn from far end", isOn: $store.config.spawnFromFarEnd)
                    LabeledContent("Speed @0 / @50 / @100 / @170") {
                        Text(String(
                            format: "%.2f / %.2f / %.2f / %.2f",
                            difficulty.speed(forScore: 0), difficulty.speed(forScore: 50),
                            difficulty.speed(forScore: 100), difficulty.speed(forScore: 170)
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Travel time @0 / @170") {
                        Text(String(format: "%.2f / %.2f s", difficulty.travelTime(forScore: 0), difficulty.travelTime(forScore: 170)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Projection") {
                    slider("Camera pitch", value: $store.config.cameraPitchDegrees, in: 20...60, format: "%.0f°")
                    slider("Camera azimuth", value: $store.config.cameraAzimuthDegrees, in: -90...90, format: "%.0f°")
                    slider("Camera distance", value: $store.config.cameraDistance, in: 2.5...12, format: "%.1f")
                    slider("Top-face width / screen", value: $store.config.topFaceWidthRatio, in: 0.4...0.9, format: "%.3f")
                    slider("Active top Y (from top)", value: $store.config.activeTopYRatio, in: 0.3...0.6, format: "%.3f")
                }

                Section("Camera follow") {
                    slider("Step duration × travel time", value: $store.config.cameraStepDurationMultiplier, in: 0.2...2.0, format: "%.2f")
                    slider("Minimum step duration", value: $store.config.minimumCameraStepDuration, in: 0.05...0.6, format: "%.2f s")
                }

                Section("Placement") {
                    slider("Overlap tolerance", value: $store.config.overlapTolerance, in: 0...0.01, format: "%.4f")
                    slider("Minimum viable dimension", value: $store.config.minimumViableDimension, in: 0...0.05, format: "%.4f")
                    slider("Near-perfect tolerance", value: $store.config.perfectPlacementTolerance, in: 0...0.1, format: "%.3f")
                }

                Section("Cut pieces") {
                    Toggle("Show falling debris", isOn: $store.config.debrisEnabled)
                    slider("Gravity (widths/s²)", value: $store.config.debrisGravity, in: 1...20, format: "%.1f")
                    slider("Rotation", value: $store.config.debrisRotationDegreesPerSecond, in: 0...360, format: "%.0f°/s")
                    slider("Lifetime", value: $store.config.debrisLifetime, in: 0.2...2.0, format: "%.2f s")
                }

                Section("Feedback timing") {
                    slider("Squash duration", value: $store.config.squashDuration, in: 0.05...0.6, format: "%.2f s")
                    slider("Spawn fade", value: $store.config.spawnFadeDuration, in: 0...0.5, format: "%.2f s")
                    slider("Game-over hold", value: $store.config.gameOverHoldDuration, in: 0...2.0, format: "%.2f s")
                }

                Section("Colours") {
                    slider("Initial hue", value: $store.config.initialHueDegrees, in: 0...360, format: "%.0f°")
                    slider("Hue step / block", value: $store.config.hueStepDegrees, in: 0...30, format: "%.1f°")
                    slider("Saturation", value: $store.config.saturation, in: 0.3...1.0, format: "%.2f")
                    slider("Brightness", value: $store.config.brightness, in: 0.4...1.0, format: "%.2f")
                    slider("Left face shade", value: $store.config.leftFaceShade, in: 0.2...1.0, format: "%.2f")
                    slider("Right face shade", value: $store.config.rightFaceShade, in: 0.2...1.0, format: "%.2f")
                }

                Section {
                    Button("Reset to reference values", role: .destructive) {
                        store.resetToReference()
                    }
                }
            }
            .navigationTitle("Tower Stack Tuning")
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
