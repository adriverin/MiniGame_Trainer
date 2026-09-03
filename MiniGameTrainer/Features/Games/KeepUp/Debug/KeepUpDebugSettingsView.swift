#if DEBUG
import SwiftUI

struct KeepUpDebugSettingsView: View {
    @ObservedObject var store: KeepUpTuningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Platform") {
                    slider("Diameter / width", value: $store.config.platformDiameterRatio, in: 0.15...0.40, format: "%.3f")
                    slider("Starting X", value: $store.config.startingPlatformXRatio, in: 0...1, format: "%.3f")
                    slider("Starting Y", value: $store.config.startingPlatformYRatio, in: 0...0.55, format: "%.3f")
                    slider("Minimum center X", value: $store.config.minimumPlatformCenterXRatio, in: -0.25...0.5, format: "%.3f")
                    slider("Maximum center X", value: $store.config.maximumPlatformCenterXRatio, in: 0.5...1.25, format: "%.3f")
                    slider("Minimum center Y", value: $store.config.minimumPlatformCenterYRatio, in: -0.25...0.3, format: "%.3f")
                    slider("Maximum center Y", value: $store.config.maximumPlatformCenterYRatio, in: 0.3...0.8, format: "%.3f")
                    Text("Control model: absolute two-axis touch tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Ceiling") {
                    slider("Y / height", value: $store.config.upperLineYRatio, in: 0.65...0.95, format: "%.3f")
                    slider("Horizontal inset", value: $store.config.upperLineHorizontalInsetRatio, in: 0...0.2, format: "%.3f")
                    slider("Thickness / width", value: $store.config.upperLineThicknessWidthRatio, in: 0.001...0.015, format: "%.3f")
                    slider("Opacity", value: $store.config.upperLineOpacity, in: 0.1...1, format: "%.2f")
                    slider("Restitution", value: $store.config.ceilingRestitution, in: 0...1, format: "%.3f")
                    Toggle("Reflect at ceiling", isOn: $store.config.reflectsAtCeiling)
                    Text("Visible line and collision Y are the same geometry value.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Ball and initial state") {
                    slider("Ball diameter / width", value: $store.config.ballDiameterRatio, in: 0.025...0.10, format: "%.3f")
                    slider("Starting X", value: $store.config.startingBallXRatio, in: 0...1, format: "%.3f")
                    slider("Starting Y", value: $store.config.startingBallYRatio, in: 0.35...0.95, format: "%.3f")
                    slider("Starting VX / width", value: $store.config.startingHorizontalVelocityWidthRatio, in: -1...1, format: "%.3f")
                    slider("Starting VY / height", value: $store.config.startingVerticalVelocityHeightRatio, in: -2...2, format: "%.3f")
                }

                Section("Physics") {
                    slider("Gravity / height", value: $store.config.gravityHeightRatio, in: 0.5...8, format: "%.3f")
                    slider("Bounce impulse / height", value: $store.config.bounceImpulseHeightRatio, in: 0.5...4, format: "%.3f")
                    slider("Maximum VX / width", value: $store.config.maximumHorizontalBounceSpeedWidthRatio, in: 0.25...4, format: "%.3f")
                    slider("Impact exponent", value: $store.config.impactResponseExponent, in: 0.25...3, format: "%.3f")
                    slider("Platform VX transfer", value: $store.config.platformHorizontalVelocityTransferCoefficient, in: 0...1, format: "%.3f")
                    slider("Platform VY transfer", value: $store.config.platformVerticalVelocityTransferCoefficient, in: 0...1, format: "%.3f")
                }

                Section("Collision and boundaries") {
                    slider("Effective catch radius", value: $store.config.effectiveCatchRadiusRatio, in: 0.40...1, format: "%.3f")
                    slider("Landing tolerance / width", value: $store.config.landingToleranceWidthRatio, in: 0...0.025, format: "%.4f")
                    slider("Minimum catch normal Y", value: $store.config.minimumCatchNormalY, in: 0...1, format: "%.3f")
                    Toggle("Reflect at side walls", isOn: $store.config.reflectsAtSideWalls)
                    slider("Failure Y / height", value: $store.config.failureYRatio, in: -0.10...0.15, format: "%.3f")
                }

                Section("Trail") {
                    slider("Sample interval", value: $store.config.trailSampleInterval, in: 0.015...0.15, format: "%.3f s")
                    slider("Lifetime", value: $store.config.trailLifetime, in: 0.1...1.5, format: "%.2f s")
                    Stepper("Maximum dots: \(store.config.trailMaximumCount)", value: $store.config.trailMaximumCount, in: 2...40)
                    slider("Oldest scale", value: $store.config.trailMinimumScale, in: 0.05...0.5, format: "%.2f")
                    slider("Newest scale", value: $store.config.trailMaximumScale, in: 0.15...0.8, format: "%.2f")
                    slider("Minimum opacity", value: $store.config.trailMinimumOpacity, in: 0...0.6, format: "%.2f")
                    slider("Maximum opacity", value: $store.config.trailMaximumOpacity, in: 0.05...1, format: "%.2f")
                }

                Section("Lifecycle") {
                    slider("Result hold", value: $store.config.resultHoldDuration, in: 0...1.5, format: "%.2f s")
                    slider("Maximum frame delta", value: $store.config.maximumFrameDelta, in: 0.02...0.25, format: "%.3f s")
                }

                Section("Difficulty") {
                    let anchors = zip(store.config.difficultyAnchorScores, store.config.difficultyAnchorScales)
                    ForEach(Array(anchors.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text("Score \(pair.0)")
                            Spacer()
                            Text(String(format: "× %.2f", Double(pair.1)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Text("Time scale: velocity × s, gravity × s², max VX × s. Capped at the last anchor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Physics preview score", selection: Binding(
                        get: { store.debugOptions.physicsScoreOverride ?? -1 },
                        set: { store.debugOptions.physicsScoreOverride = $0 < 0 ? nil : $0 }
                    )) {
                        Text("Live").tag(-1)
                        Text("0").tag(0)
                        Text("10").tag(10)
                        Text("20").tag(20)
                        Text("30").tag(30)
                        Text("40").tag(40)
                    }
                    Toggle("Lock auto-catch platform Y", isOn: Binding(
                        get: { store.debugOptions.autoCatchPlatformYRatio != nil },
                        set: { store.debugOptions.autoCatchPlatformYRatio = $0 ? store.config.startingPlatformYRatio : nil }
                    ))
                }

                Section("Deterministic QA") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showOverlay)
                    Toggle("Geometry + trajectory", isOn: $store.debugOptions.showGeometry)
                    Toggle("Show trail", isOn: $store.debugOptions.showTrail)
                    Toggle("Auto-catch", isOn: $store.debugOptions.autoCatch)
                    slider("Auto-catch offset", value: $store.debugOptions.autoCatchOffset, in: -0.9...0.9, format: "%.2f")
                    Stepper(
                        "Intentional miss: \(store.debugOptions.intentionalMissAtScore.map(String.init) ?? "Off")",
                        value: Binding(
                            get: { store.debugOptions.intentionalMissAtScore ?? -1 },
                            set: { store.debugOptions.intentionalMissAtScore = $0 < 0 ? nil : $0 }
                        ),
                        in: -1...200
                    )
                }

                Section {
                    Button("Reset to reference values", role: .destructive) { store.resetToReference() }
                }
            }
            .navigationTitle("Keep Up Tuning")
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
