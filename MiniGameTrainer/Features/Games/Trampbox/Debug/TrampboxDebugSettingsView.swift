#if DEBUG
import SwiftUI

struct TrampboxDebugSettingsView: View {
    @ObservedObject var store: TrampboxTuningStore
    @Environment(\.dismiss) private var dismiss
    @State private var seedText = ""

    private var previewGeometry: TrampboxGeometry {
        TrampboxGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debug") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showPerformanceOverlay)
                    Toggle("Geometry and reach", isOn: $store.debugOptions.showGeometry)
                    Toggle("Skip countdown", isOn: $store.debugOptions.skipCountdown)
                }

                Section("Ball") {
                    slider("Radius / width", value: $store.config.ballRadiusRatio, in: 0.02...0.07, format: "%.3f")
                    slider("Starting X", value: $store.config.startingXRatio, in: 0.1...0.9, format: "%.2f")
                    LabeledContent("Resolved radius") { Text(String(format: "%.1f pt", previewGeometry.ballRadius)) }
                }

                Section("Horizontal movement") {
                    slider("Drag sensitivity", value: $store.config.horizontalControlSensitivity, in: 0.2...2.2, format: "%.2f")
                    slider("Maximum speed (widths/s)", value: $store.config.maximumHorizontalSpeedRatio, in: 0.4...3.0, format: "%.2f")
                }

                Section("Bounce") {
                    slider("Initial duration", value: $store.config.initialBounceDuration, in: 0.3...1.2, format: "%.3f s")
                    slider("Minimum duration", value: $store.config.minimumBounceDuration, in: 0.15...0.7, format: "%.3f s")
                    slider("Reduction / point", value: $store.config.bounceDurationReductionPerPoint, in: 0...0.008, format: "%.4f s")
                    slider("Height / screen", value: $store.config.bounceHeightRatio, in: 0.08...0.38, format: "%.3f")
                    let difficulty = TrampboxDifficultyModel(config: store.config)
                    LabeledContent("Duration @0 / @80 / @160") {
                        Text(String(format: "%.3f / %.3f / %.3f s", difficulty.bounceDuration(for: 0), difficulty.bounceDuration(for: 80), difficulty.bounceDuration(for: 160)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Platforms") {
                    slider("Initial width", value: $store.config.initialPlatformWidthRatio, in: 0.10...0.42, format: "%.3f")
                    slider("Minimum width", value: $store.config.minimumPlatformWidthRatio, in: 0.05...0.25, format: "%.3f")
                    slider("Narrowing / point", value: $store.config.platformWidthReductionPerPoint, in: 0...0.002, format: "%.4f")
                    slider("Far top depth / width", value: $store.config.farTopDepthToWidthRatio, in: 0.04...0.45, format: "%.3f")
                    slider("Near top depth / width", value: $store.config.nearTopDepthToWidthRatio, in: 0.15...0.90, format: "%.3f")
                    slider("Far side depth / width", value: $store.config.farSideDepthToWidthRatio, in: 0.01...0.20, format: "%.3f")
                    slider("Near side depth / width", value: $store.config.nearSideDepthToWidthRatio, in: 0.03...0.35, format: "%.3f")
                    slider("Vertical spacing", value: $store.config.platformSpacingRatio, in: 0.06...0.20, format: "%.3f")
                }

                Section("Generation") {
                    slider("Minimum shift", value: $store.config.minimumHorizontalOffsetRatio, in: 0...0.30, format: "%.3f")
                    slider("Maximum shift", value: $store.config.maximumHorizontalOffsetRatio, in: 0.1...0.8, format: "%.3f")
                    slider("Reach multiplier", value: $store.config.reachabilityMultiplier, in: 0.4...1.0, format: "%.2f")
                    Stepper("Visible platforms: \(store.config.visiblePlatformCount)", value: $store.config.visiblePlatformCount, in: 4...12)
                    TextField("Seed (blank = random)", text: $seedText)
                        .keyboardType(.numberPad)
                        .onChange(of: seedText) { _, value in store.config.randomSeed = UInt64(value) }
                }

                Section("Perspective") {
                    slider("Horizon Y", value: $store.config.horizonYRatio, in: 0.10...0.40, format: "%.3f")
                    slider("Landing Y", value: $store.config.landingYRatio, in: 0.55...0.82, format: "%.3f")
                    slider("Far scale", value: $store.config.farScale, in: 0.15...0.65, format: "%.2f")
                    slider("Near scale", value: $store.config.nearScale, in: 0.7...1.3, format: "%.2f")
                    slider("Width exponent", value: $store.config.perspectiveExponent, in: 0.5...2.5, format: "%.2f")
                    slider("Top-depth exponent", value: $store.config.depthProjectionExponent, in: 0.4...2.5, format: "%.2f")
                    slider("Approach rotation", value: $store.config.approachRotationDegrees, in: 0...10, format: "%.1f°")
                }

                Section("Foreground departure") {
                    slider("Duration multiplier", value: $store.config.departureDurationMultiplier, in: 0.4...2.0, format: "%.2f")
                    slider("Downward travel", value: $store.config.departureDownwardDistanceRatio, in: 0.15...0.8, format: "%.2f")
                    slider("Lateral drift", value: $store.config.departureLateralDriftRatio, in: 0...0.5, format: "%.2f")
                    slider("Tumble rotation", value: $store.config.departureRotationDegrees, in: 20...180, format: "%.0f°")
                    slider("Foreground scale", value: $store.config.foregroundScaleMultiplier, in: 1...3, format: "%.2f×")
                }

                Section("Collision and failure") {
                    Picker("Landing rule", selection: $store.config.landingRule) {
                        ForEach(TrampboxLandingRule.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    slider("Landing tolerance", value: $store.config.landingTolerance, in: 0...1.5, format: "%.2f")
                    slider("Failure Y", value: $store.config.failureYRatio, in: 0.75...1.1, format: "%.3f")
                    slider("Initial fall speed", value: $store.config.fallInitialSpeedRatio, in: 0...1.0, format: "%.2f")
                    slider("Fall gravity", value: $store.config.fallGravityRatio, in: 0.5...6.0, format: "%.2f")
                }

                Section {
                    Button("Reset to reference values", role: .destructive) {
                        store.resetToReference()
                        seedText = ""
                    }
                }
            }
            .navigationTitle("Trampbox Tuning")
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
