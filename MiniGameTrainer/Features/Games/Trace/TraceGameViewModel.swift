import Combine
import CoreGraphics
import Foundation

@MainActor
final class TraceGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: TraceGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TraceGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TraceDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TraceGameConfig, debugOptions: TraceDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TraceGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TraceGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension TraceGameViewModel: TraceGameSceneDelegate {
    func traceSceneDidAcceptNode(_ scene: TraceGameScene) { feedback.tapSucceeded() }
    func traceSceneDidFail(_ scene: TraceGameScene) { feedback.gameFailed() }
    func traceSceneDidCompletePattern(_ scene: TraceGameScene) { feedback.tapSucceeded() }

    func traceScene(_ scene: TraceGameScene, didEndWith summary: TraceSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(TraceResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum TraceResultBuilder {
    static func makeResult(from summary: TraceSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "patternsCompleted", label: "Patterns completed", value: "\(summary.patternsCompleted)"),
            GameMetric(key: "patternsFailed", label: "Patterns failed", value: "\(summary.patternsFailed)"),
            GameMetric(key: "segments", label: "Correct segments", value: "\(summary.segmentsScored)"),
            GameMetric(key: "accuracy", label: "Pattern accuracy", value: MetricFormatter.percent(summary.accuracy)),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        metrics.removeAll { $0.value == "–" }
        return GameResult(
            gameID: TraceGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.accuracy,
            metrics: metrics
        )
    }
}
