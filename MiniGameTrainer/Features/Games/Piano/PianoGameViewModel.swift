import Combine
import CoreGraphics
import Foundation

/// Bridges the SpriteKit scene to SwiftUI: owns the scene, exposes the session phase and turns a
/// `PianoSessionSummary` into the app-level `GameResult`.
@MainActor
final class PianoGameViewModel: ObservableObject {
    enum Phase: Equatable {
        case running
        case paused
        case finished
    }

    @Published private(set) var phase: Phase = .running

    let config: PianoGameConfig
    private let feedback: FeedbackService
    private(set) var scene: PianoGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: PianoDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: PianoGameConfig, debugOptions: PianoDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    /// The scene is sized once from the hosting view; portrait lock keeps the size stable.
    /// Returns `nil` until the host reports a usable size (GeometryReader can start at zero).
    func scene(for size: CGSize) -> PianoGameScene? {
        if let scene {
            return scene
        }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = PianoGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene, !scene.logic.state.isGameOver else { return }
        scene.pauseGame()
        phase = .paused
    }

    func resume() {
        guard phase == .paused, let scene else { return }
        scene.resumeGame()
        phase = .running
    }

    func restart() {
        guard let scene else { return }
        scene.isPaused = false
        phase = .running
        scene.startSession()
    }

    func tearDown() {
        feedback.stop()
    }
}

extension PianoGameViewModel: PianoGameSceneDelegate {
    func pianoSceneDidRegisterHit(_ scene: PianoGameScene) {
        feedback.tapSucceeded()
    }

    func pianoSceneDidFail(_ scene: PianoGameScene) {
        feedback.gameFailed()
    }

    func pianoSceneCountdownDidTick(_ scene: PianoGameScene) {
        feedback.countdownTick()
    }

    func pianoScene(_ scene: PianoGameScene, didEndWith summary: PianoSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(PianoResultBuilder.makeResult(from: summary, config: config))
    }
}

/// Maps Piano-specific metrics onto the generic `GameResult`.
@MainActor
enum PianoResultBuilder {
    static func makeResult(from summary: PianoSessionSummary, config: PianoGameConfig) -> GameResult {
        var metrics: [GameMetric] = [
            GameMetric(key: "correct", label: "Correct taps", value: "\(summary.correctTaps)"),
            GameMetric(key: "missed", label: "Missed tiles", value: "\(summary.missedTiles)"),
            GameMetric(key: "wrong", label: "Wrong taps", value: "\(summary.wrongTaps)"),
            GameMetric(key: "accuracy", label: "Accuracy", value: MetricFormatter.percent(summary.accuracy)),
            GameMetric(key: "avgReaction", label: "Average reaction", value: MetricFormatter.milliseconds(summary.averageReactionTime)),
            GameMetric(key: "medianReaction", label: "Median reaction", value: MetricFormatter.milliseconds(summary.medianReactionTime)),
            GameMetric(key: "bestReaction", label: "Best reaction", value: MetricFormatter.milliseconds(summary.bestReactionTime)),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        if let tps = summary.tapsPerSecond {
            metrics.append(GameMetric(key: "tps", label: "Taps per second", value: String(format: "%.2f", tps)))
        }
        if let depth = summary.averageTapDepth {
            metrics.append(GameMetric(key: "depth", label: "Average tap depth", value: MetricFormatter.percent(Double(depth))))
        }
        metrics.append(GameMetric(key: "peakSpeed", label: "Peak speed", value: String(format: "%.2f screens/s", summary.peakSpeed)))
        metrics.append(GameMetric(key: "reason", label: "Ended by", value: reasonText(summary.reason)))

        return GameResult(
            gameID: PianoGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.accuracy,
            averageReactionTime: summary.averageReactionTime,
            bestReactionTime: summary.bestReactionTime,
            metrics: metrics
        )
    }

    private static func reasonText(_ reason: PianoGameOverReason) -> String {
        switch reason {
        case .missedTile: "Missed tile"
        case .wrongTap: "Wrong tap"
        case .timerExpired: "Time up"
        case .targetReached: "Target reached"
        case .aborted: "Quit"
        }
    }
}
