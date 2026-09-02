import Combine
import CoreGraphics
import Foundation

@MainActor
final class TrampboxGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: TrampboxGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TrampboxGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TrampboxDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TrampboxGameConfig, debugOptions: TrampboxDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TrampboxGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TrampboxGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene else { return }
        switch scene.logic.state {
        case .gameOver: return
        default: break
        }
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

    func tearDown() { feedback.stop() }
}

extension TrampboxGameViewModel: TrampboxGameSceneDelegate {
    func trampboxSceneDidLand(_ scene: TrampboxGameScene) { feedback.tapSucceeded() }
    func trampboxSceneDidFail(_ scene: TrampboxGameScene) { feedback.gameFailed() }
    func trampboxSceneCountdownDidTick(_ scene: TrampboxGameScene) { feedback.countdownTick() }

    func trampboxScene(_ scene: TrampboxGameScene, didEndWith summary: TrampboxSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(TrampboxResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum TrampboxResultBuilder {
    static func makeResult(from summary: TrampboxSessionSummary) -> GameResult {
        var metrics: [GameMetric] = [
            GameMetric(key: "landings", label: "Landings", value: "\(summary.landings)"),
            GameMetric(key: "precision", label: "Landing precision", value: MetricFormatter.percent(summary.averagePrecision)),
            GameMetric(key: "medianError", label: "Median landing error", value: points(summary.medianLandingError)),
            GameMetric(key: "bestPrecision", label: "Best landing precision", value: MetricFormatter.percent(summary.bestPrecision)),
            GameMetric(key: "closestSave", label: "Closest edge save", value: points(summary.closestEdgeSave)),
            GameMetric(key: "averageWidth", label: "Average platform width", value: points(summary.averagePlatformWidth)),
            GameMetric(key: "finalBounce", label: "Final bounce duration", value: String(format: "%.3f s", summary.finalBounceDuration)),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
            GameMetric(key: "reason", label: "Ended by", value: summary.reason == .missedPlatform ? "Missed platform" : "Quit"),
        ]
        metrics.removeAll { $0.value == "–" }
        return GameResult(
            gameID: TrampboxGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.averagePrecision,
            metrics: metrics
        )
    }

    private static func points(_ value: CGFloat?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f pt", value)
    }
}
