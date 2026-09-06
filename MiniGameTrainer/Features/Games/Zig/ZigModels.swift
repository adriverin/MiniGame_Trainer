import CoreGraphics
import Foundation

enum ZigDirection: Int, Equatable {
    case positiveX
    case positiveY

    var vector: CGVector {
        switch self {
        case .positiveX: CGVector(dx: 1, dy: 0)
        case .positiveY: CGVector(dx: 0, dy: 1)
        }
    }

    var toggled: ZigDirection { self == .positiveX ? .positiveY : .positiveX }
}

struct ZigCell: Hashable {
    let x: Int
    let y: Int
    var progress: Int { x + y }
}

enum ZigGameState: Equatable { case running, paused, pausedFalling, falling, finished }
enum ZigEvent: Equatable { case turned, fell, finished }

struct ZigSessionSummary: Equatable {
    let score: Int
    let duration: TimeInterval
    let turns: Int
    let maximumSpeed: CGFloat
}

struct ZigRenderState {
    let ballPosition: CGPoint
    let direction: ZigDirection
    let cells: Set<ZigCell>
    let score: Int
    let cameraProgress: CGFloat
    let state: ZigGameState
    let fallProgress: CGFloat
}
