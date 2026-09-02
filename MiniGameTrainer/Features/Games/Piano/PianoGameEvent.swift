import CoreGraphics
import Foundation

enum PianoGameState: Equatable {
    /// Rows laid out, nothing moving, waiting for the scene to run the countdown.
    case ready
    case countdown
    /// Countdown finished; waiting for the first tap when `requiresTapToStart` is on.
    case waitingForStart
    case playing
    case paused
    case gameOver(PianoGameOverReason)

    var acceptsGameplayInput: Bool {
        switch self {
        case .playing, .waitingForStart: true
        default: false
        }
    }

    var isGameOver: Bool {
        if case .gameOver = self { return true }
        return false
    }
}

enum PianoGameOverReason: Equatable {
    case missedTile
    case wrongTap
    case timerExpired
    case targetReached
    case aborted

    var isFailure: Bool {
        switch self {
        case .missedTile, .wrongTap: true
        case .timerExpired, .targetReached, .aborted: false
        }
    }
}

/// Discrete gameplay events emitted by `PianoGameLogic` and consumed by the scene / statistics.
enum PianoGameEvent: Equatable {
    case stateChanged(PianoGameState)
    case tileSpawned(PianoTile)
    case tileHit(PianoTile)
    case tileMissed(PianoTile)
    case wrongTap(CGPoint)
    case scoreChanged(Int)
    case gameEnded(PianoGameOverReason)
}

/// What a single touch produced. Returned synchronously so the scene can react without latency.
enum PianoTapOutcome: Equatable {
    case hit(PianoTile)
    case wrongTap
    case started
    case ignored
}
