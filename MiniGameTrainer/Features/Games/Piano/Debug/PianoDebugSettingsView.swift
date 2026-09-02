#if DEBUG
import SwiftUI

/// DEBUG-only calibration panel. Edits apply to the next session started from the intro screen.
struct PianoDebugSettingsView: View {
    @ObservedObject var store: PianoTuningStore
    @Environment(\.dismiss) private var dismiss
    @State private var seedText = ""

    private var previewGeometry: PianoGeometry {
        PianoGeometry(sceneSize: UIScreen.main.bounds.size, config: store.config)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debug overlays") {
                    Toggle("Performance overlay", isOn: $store.debugOptions.showPerformanceOverlay)
                    Toggle("Show hitboxes", isOn: $store.debugOptions.showHitboxes)
                    Toggle("Show miss line", isOn: $store.debugOptions.showMissLine)
                    Toggle("Skip countdown", isOn: $store.debugOptions.skipCountdown)
                }

                Section("Layout (ratios)") {
                    Stepper("Lanes: \(store.config.laneCount)", value: $store.config.laneCount, in: 2...6)
                    slider("Row height", value: $store.config.rowHeightRatio, in: 0.08...0.35, format: "%.3f")
                    slider("Tile width", value: $store.config.tileWidthRatio, in: 0.5...1.0, format: "%.3f")
                    slider("Tile seam", value: $store.config.tileSeamRatio, in: 0...0.1, format: "%.3f")
                    slider("Playfield top", value: $store.config.playfieldTopRatio, in: 0...0.4, format: "%.3f")
                    slider("Miss line", value: $store.config.missLineRatio, in: 0.5...1.0, format: "%.3f")
                    Picker("Miss rule", selection: $store.config.missRule) {
                        ForEach(PianoMissRule.allCases, id: \.self) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                    LabeledContent("Resolved on this device") {
                        Text(String(format: "row %.0f pt · tile %.0f×%.0f pt", previewGeometry.rowHeight, previewGeometry.tileSize.width, previewGeometry.tileSize.height))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Movement (scene heights / s)") {
                    slider("Initial speed", value: $store.config.initialSpeed, in: 0.1...1.0, format: "%.3f")
                    slider("Speed growth / point", value: $store.config.speedIncreasePerPoint, in: 0...0.02, format: "%.4f")
                    slider("Maximum speed", value: $store.config.maximumSpeed, in: 0.5...3.0, format: "%.2f")
                    let difficulty = PianoDifficultyModel(config: store.config)
                    LabeledContent("Spawn interval @0 / @50 / @150") {
                        Text(String(
                            format: "%.2f / %.2f / %.2f s",
                            difficulty.spawnInterval(forScore: 0, geometry: previewGeometry),
                            difficulty.spawnInterval(forScore: 50, geometry: previewGeometry),
                            difficulty.spawnInterval(forScore: 150, geometry: previewGeometry)
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Spawning") {
                    Stepper("Initial rows: \(store.config.initialRowCount)", value: $store.config.initialRowCount, in: 1...4)
                    slider("Lowest row offset (rows)", value: $store.config.initialLowestRowTopOffset, in: 0...2, format: "%.2f")
                    Stepper("Double tiles from score: \(store.config.doubleTileUnlockScore)", value: $store.config.doubleTileUnlockScore, in: 0...100, step: 5)
                    slider("Double tile probability", value: $store.config.doubleTileProbability, in: 0...0.6, format: "%.2f")
                    Toggle("Allow same lane as previous", isOn: $store.config.allowSameLaneAsPrevious)
                    HStack {
                        TextField("Seed (blank = random)", text: $seedText)
                            .keyboardType(.numberPad)
                            .onChange(of: seedText) { _, text in
                                store.config.randomSeed = UInt64(text)
                            }
                        if store.config.randomSeed != nil {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                    }
                }

                Section("Rules") {
                    Stepper("Points per tile: \(store.config.pointsPerTile)", value: $store.config.pointsPerTile, in: 1...10)
                    Toggle("Empty tap ends game", isOn: $store.config.emptyTapEndsGame)
                    Toggle("Ghost tile tap ends game", isOn: $store.config.consumedTileTapEndsGame)
                    Toggle("Ignore taps above playfield", isOn: $store.config.ignoreTapsOutsidePlayfield)
                    Toggle("Require lowest row first", isOn: $store.config.requireLowestRowFirst)
                    Toggle("Tap to start", isOn: $store.config.requiresTapToStart)
                    Toggle("Start tap consumes tile", isOn: $store.config.startTapConsumesTile)
                }

                Section("Visuals") {
                    slider("Hit opacity (initial)", value: $store.config.hitTileInitialOpacity, in: 0...0.5, format: "%.2f")
                    slider("Hit opacity (resting)", value: $store.config.hitTileRestingOpacity, in: 0...0.3, format: "%.2f")
                    slider("Hit fade duration", value: $store.config.hitTileFadeDuration, in: 0...1, format: "%.2f s")
                    slider("Score center Y", value: $store.config.scoreCenterYRatio, in: 0.05...0.4, format: "%.3f")
                    slider("Score font size", value: $store.config.scoreFontSizeRatio, in: 0.03...0.12, format: "%.3f")
                    slider("Game over hold", value: $store.config.gameOverHoldDuration, in: 0...2, format: "%.2f s")
                }

                Section {
                    Button("Reset to reference values", role: .destructive) {
                        store.resetToReference()
                        seedText = ""
                    }
                }
            }
            .navigationTitle("Piano Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                seedText = store.config.randomSeed.map(String.init) ?? ""
            }
        }
    }

    private func slider(_ title: String, value: Binding<CGFloat>, in range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, Double(value.wrappedValue)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
#endif
