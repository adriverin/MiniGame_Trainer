import CoreGraphics
import Foundation

enum TowerStackGameState: Equatable {
    /// Block is already sliding; the "tap to place" hint is shown and the first tap only dismisses it.
    case ready
    case playing
    case paused
    case gameOver
}

enum TowerStackGameOverReason: Equatable {
    case missedTower
    case aborted
}

/// A block resting on the tower.
struct TowerStackBlock: Equatable, Identifiable {
    /// Layer index; 0 is the first block placed on the pedestal.
    let layer: Int
    let footprint: TowerStackFootprint
    /// Index used for the hue progression (equals `layer`).
    var colorIndex: Int { layer }
    var id: Int { layer }
}

/// A piece of a block cut away (or a whole missed block) for the decorative fall animation.
struct TowerStackCutPiece: Equatable {
    let footprint: TowerStackFootprint
    let layer: Int
    let colorIndex: Int
    /// Axis along which the piece was cut off; it falls away from the tower along this axis.
    let axis: TowerStackAxis
    /// +1 / −1: side of the tower the piece was hanging over.
    let side: CGFloat
}

/// Training record of one evaluated tap.
struct TowerStackPlacement: Equatable {
    let score: Int
    let axis: TowerStackAxis
    let incomingCenter: CGFloat
    let targetCenter: CGFloat
    /// Signed offset incoming − target along `axis`, in world units.
    let offset: CGFloat
    var absoluteOffset: CGFloat { abs(offset) }
    /// `absoluteOffset / target dimension`.
    let normalizedOffset: CGFloat
    /// Surviving length / target length along `axis` (0 on a miss).
    let overlapRatio: CGFloat
    let resultingWidth: CGFloat
    let resultingDepth: CGFloat
    let movementSpeed: CGFloat
    let direction: CGFloat
    let isMiss: Bool
}

struct TowerStackSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let reason: TowerStackGameOverReason
    let placements: Int
    let averageOverlapRatio: Double?
    let bestOverlapRatio: Double?
    let worstOverlapRatio: Double?
    let averageNormalizedOffset: Double?
    let nearPerfectPlacements: Int
    let finalWidthRatio: Double
    let finalDepthRatio: Double
    let highestSpeed: CGFloat
}

enum TowerStackGameEvent: Equatable {
    case stateChanged(TowerStackGameState)
    case scoreChanged(Int)
    case blockPlaced(TowerStackBlock)
    case pieceCut(TowerStackCutPiece)
    case blockSpawned
    case gameEnded(TowerStackGameOverReason)
}
