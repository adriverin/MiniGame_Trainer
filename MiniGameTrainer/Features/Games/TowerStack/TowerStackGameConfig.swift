import CoreGraphics
import Foundation

/// All Tower Stack calibration constants. World units are "block widths": the first block is
/// 1 × 1 wide, so every distance/speed below is relative to that footprint and scales with the
/// scene automatically through `TowerStackProjection`.
///
/// Reference values come from `Documentation/TOWER_STACK_GAME_ANALYSIS.md`.
struct TowerStackGameConfig: Equatable {
    // MARK: Blocks

    /// Footprint of the first block along world X, in world units (defines the unit).
    var initialWidth: CGFloat = 1.0
    /// Footprint of the first block along world Z.
    var initialDepth: CGFloat = 1.0
    /// Layer thickness; the reference measures ≈ 0.22 of the block width.
    var blockHeight: CGFloat = 0.22
    /// How far the grey pedestal extends below the first block.
    var pedestalHeight: CGFloat = 3.5

    // MARK: Projection (pinhole camera fitted to the reference)

    /// Elevation of the camera above the horizontal plane.
    var cameraPitchDegrees: CGFloat = 36
    /// Rotation of the camera around the vertical axis. −45° places the camera on the −X/+Z side,
    /// so the far end of the X axis is upper-right on screen (first block in the reference).
    var cameraAzimuthDegrees: CGFloat = -45
    /// Distance from the framed tower-top centre to the camera. Controls perspective strength.
    var cameraDistance: CGFloat = 5.0
    /// Screen width fraction covered by the top-face diamond of a unit block at the framed height.
    var topFaceWidthRatio: CGFloat = 0.67
    /// Screen position (fraction from the top) where the framed tower-top centre is drawn.
    var activeTopYRatio: CGFloat = 0.445

    // MARK: Movement

    /// Speed of the first block, in block widths per second.
    var initialSpeed: CGFloat = 1.4
    /// Linear growth per score point: speed = initialSpeed × (1 + growth × score).
    var speedGrowthPerPoint: CGFloat = 0.007
    /// Safety cap (≈ score 300 with the defaults); never reached in the reference run.
    var maximumSpeed: CGFloat = 4.0
    /// Half-length of the sliding path, centred on the tower top. Blocks spawn at the far end.
    var movementRange: CGFloat = 1.3
    var firstAxis: TowerStackAxis = .x
    /// When true (reference), each block spawns at the far end of its axis and travels toward the camera.
    var spawnFromFarEnd = true

    // MARK: Camera follow

    /// Camera catch-up duration as a multiple of the incoming block's spawn→centre travel time.
    var cameraStepDurationMultiplier: CGFloat = 1.0
    var minimumCameraStepDuration: TimeInterval = 0.15

    // MARK: Placement

    /// Overlaps at or below this length count as a miss (absorbs floating-point noise only).
    var overlapTolerance: CGFloat = 0.0005
    /// Dimensions below this are treated as a miss to avoid degenerate polygons.
    var minimumViableDimension: CGFloat = 0.002
    /// Normalised offset (|offset| / target dimension) counted as "near perfect" in metrics only.
    var perfectPlacementTolerance: CGFloat = 0.02
    var pointsPerPlacement = 1

    // MARK: Feedback timing

    var squashDuration: TimeInterval = 0.25
    var spawnFadeDuration: TimeInterval = 0.10
    var gameOverHoldDuration: TimeInterval = 0.6

    // MARK: Cut-piece debris (visual only; the reference removes the overhang instantly)

    var debrisEnabled = true
    /// Downward acceleration in block widths per second².
    var debrisGravity: CGFloat = 6.0
    var debrisRotationDegreesPerSecond: CGFloat = 60
    var debrisLifetime: TimeInterval = 0.7

    // MARK: Colours (procedural; hue advances per placed block)

    var initialHueDegrees: CGFloat = 17
    var hueStepDegrees: CGFloat = 5
    var saturation: CGFloat = 0.70
    var brightness: CGFloat = 0.84
    /// Brightness multiplier of the darker (screen-left) side face.
    var leftFaceShade: CGFloat = 0.45
    /// Brightness multiplier of the lighter (screen-right) side face.
    var rightFaceShade: CGFloat = 0.76

    // MARK: HUD

    var scoreYRatio: CGFloat = 0.266
    var scoreFontSizeRatio: CGFloat = 0.055

    // MARK: Simulation / rendering budgets

    /// Frame deltas above this (app switch, debugger) are clamped so the block cannot teleport.
    var maximumDeltaTime: TimeInterval = 0.1
    /// Placed blocks further below the tower top than this are removed from the scene.
    var visibleLayersBelowTop = 18
    var maximumDebrisNodes = 8

    static let reference = TowerStackGameConfig()

    var initialFootprint: TowerStackFootprint {
        TowerStackFootprint(centerX: 0, centerZ: 0, width: initialWidth, depth: initialDepth)
    }
}
