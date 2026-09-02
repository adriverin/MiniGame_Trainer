import CoreGraphics
import Foundation

/// Every gameplay constant of the Piano game. Values marked "measured" come from
/// `Documentation/GAME_ANALYSIS.md`; the others are defensible assumptions kept here so they can
/// be tuned against the reference recording (see the DEBUG tuning panel).
///
/// Unit conventions:
/// - "scene height" ratios are fractions of the full-screen SpriteKit scene height.
/// - speeds are in scene heights per second, converted to points by `PianoGeometry`.
struct PianoGameConfig: Equatable, Codable {

    // MARK: Layout (measured)

    var laneCount: Int = 4
    /// Vertical distance from one row's top to the next row's top (rows are contiguous).
    var rowHeightRatio: CGFloat = 0.191
    /// Tile width as a fraction of the lane width, before the seam is subtracted.
    var tileWidthRatio: CGFloat = 1.0
    /// Thin gap between neighbouring tiles, as a fraction of lane width, applied on both axes.
    var tileSeamRatio: CGFloat = 0.023
    /// Top edge of the clipped playfield. Tiles are not drawn above this line.
    var playfieldTopRatio: CGFloat = 0.184
    /// Line whose crossing by an active tile counts as a miss (see `missRule`).
    var missLineRatio: CGFloat = 0.833

    // MARK: Movement (measured, scene heights / second)

    var initialSpeed: CGFloat = 0.343
    var speedIncreasePerPoint: CGFloat = 0.006
    /// Not observed in the recording (no plateau up to score 157); generous cap for safety.
    var maximumSpeed: CGFloat = 2.0

    // MARK: Spawning

    /// Rows present and stationary before the first tap (measured: 2).
    var initialRowCount: Int = 2
    /// Top of the lowest initial row, in row heights below the playfield top (measured ≈ 0.86).
    var initialLowestRowTopOffset: CGFloat = 0.86
    /// Rows with two tiles never appeared before roughly the 15th row / 15 points.
    var doubleTileUnlockScore: Int = 15
    /// Fraction of rows (after unlock) that carry two tiles (measured ≈ 0.15).
    var doubleTileProbability: Double = 0.15
    /// Whether a single tile may reuse the previous row's primary lane (never observed).
    var allowSameLaneAsPrevious: Bool = false
    /// Fixed seed for reproducible lane sequences; `nil` uses the system generator.
    var randomSeed: UInt64? = nil

    // MARK: Rules

    var pointsPerTile: Int = 1
    var endCondition: PianoEndCondition = .firstMistake
    var missRule: PianoMissRule = .bottomEdgeCrossesMissLine
    /// "If you tap the empty space, it's over" (reference intro text).
    var emptyTapEndsGame: Bool = true
    /// Whether tapping an already-consumed (ghost) tile counts as empty space.
    var consumedTileTapEndsGame: Bool = true
    /// Taps above the playfield (header / score area) are ignored rather than punished.
    var ignoreTapsOutsidePlayfield: Bool = true
    /// Enforce tapping rows bottom-up. Not observable in the reference; off by default.
    var requireLowestRowFirst: Bool = false
    /// The reference waits for a first tap before tiles start moving.
    var requiresTapToStart: Bool = true
    /// Whether that starting tap may also consume a tile it lands on.
    var startTapConsumesTile: Bool = false

    // MARK: Visual timing (measured)

    var hitTileInitialOpacity: CGFloat = 0.11
    var hitTileRestingOpacity: CGFloat = 0.04
    var hitTileFadeDuration: TimeInterval = 0.20
    var gameOverFlashPeakOpacity: CGFloat = 0.45
    var gameOverFlashDuration: TimeInterval = 0.60
    /// Time the frozen scene stays visible before the results screen is presented.
    var gameOverHoldDuration: TimeInterval = 0.80
    var scoreCenterYRatio: CGFloat = 0.2375
    var scoreFontSizeRatio: CGFloat = 0.064

    // MARK: Session flow

    /// Seconds per countdown step ("3", "2", "1"); "GO" is shown for half a step.
    var countdownStepDuration: TimeInterval = 0.6
    var countdownSteps: Int = 3
    /// Frame deltas above this are clamped (after backgrounding, debugger pauses, hitches).
    var maximumFrameDelta: TimeInterval = 1.0 / 20.0

    // MARK: Presets

    /// Values inferred from the reference recording.
    static let reference = PianoGameConfig()

    /// Deterministic variant for tests and replay comparisons.
    static func deterministic(seed: UInt64 = 12_345) -> PianoGameConfig {
        var config = PianoGameConfig()
        config.randomSeed = seed
        return config
    }
}

enum PianoEndCondition: Equatable, Codable {
    /// Any miss or wrong tap ends the game (reference behaviour).
    case firstMistake
    /// Fixed duration; mistakes still count as failures unless combined with lives (not implemented).
    case timer(TimeInterval)
    /// Ends successfully when the score reaches the target.
    case targetScore(Int)
}

enum PianoMissRule: String, Equatable, Codable, CaseIterable {
    /// Tile is missed as soon as its bottom edge passes the miss line (best reading of the recording).
    case bottomEdgeCrossesMissLine
    /// Tile is missed only when it has fully passed the miss line.
    case topEdgeCrossesMissLine

    var displayName: String {
        switch self {
        case .bottomEdgeCrossesMissLine: "Bottom edge"
        case .topEdgeCrossesMissLine: "Top edge (fully out)"
        }
    }
}
