import Combine
import Foundation

@MainActor
final class TargetSpeedGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: TargetSpeedGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TargetSpeedGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TargetSpeedDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TargetSpeedGameConfig, debugOptions: TargetSpeedDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TargetSpeedGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TargetSpeedGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene, !scene.logic.isFinished else { return }
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
        phase = .running
        scene.startSession()
    }

    func tearDown() { feedback.stop() }
}

@MainActor
extension TargetSpeedGameViewModel: TargetSpeedGameSceneDelegate {
    func targetSpeedSceneDidScore(_ scene: TargetSpeedGameScene) { feedback.tapSucceeded() }
    func targetSpeedSceneDidMiss(_ scene: TargetSpeedGameScene) { feedback.countdownTick() }
    func targetSpeedSceneDidFail(_ scene: TargetSpeedGameScene) { feedback.gameFailed() }

    func targetSpeedScene(_ scene: TargetSpeedGameScene, didEndWith summary: TargetSpeedSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(TargetSpeedResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum TargetSpeedResultBuilder {
    static func makeResult(from summary: TargetSpeedSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "hits", label: "Hits", value: "\(summary.hits)"),
            GameMetric(key: "misses", label: "Misses", value: "\(summary.misses)"),
            GameMetric(key: "lives", label: "Lives left", value: "\(summary.livesRemaining)"),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        if let average = summary.averageReactionTime {
            metrics.append(GameMetric(key: "averageReaction", label: "Average reaction", value: MetricFormatter.milliseconds(average)))
        }
        if let best = summary.bestReactionTime {
            metrics.append(GameMetric(key: "bestReaction", label: "Best reaction", value: MetricFormatter.milliseconds(best)))
        }
        return GameResult(
            gameID: TargetSpeedGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.hits + summary.misses == 0
                ? nil
                : Double(summary.hits) / Double(summary.hits + summary.misses),
            averageReactionTime: summary.averageReactionTime,
            bestReactionTime: summary.bestReactionTime,
            metrics: metrics
        )
    }
}
