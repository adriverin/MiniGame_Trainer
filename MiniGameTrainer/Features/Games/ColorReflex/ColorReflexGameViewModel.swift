import Combine
import Foundation

@MainActor
final class ColorReflexGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: ColorReflexGameConfig
    private let feedback: FeedbackService
    private(set) var scene: ColorReflexGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: ColorReflexDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: ColorReflexGameConfig, debugOptions: ColorReflexDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> ColorReflexGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = ColorReflexGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension ColorReflexGameViewModel: ColorReflexGameSceneDelegate {
    func colorReflexSceneDidScore(_ scene: ColorReflexGameScene) { feedback.tapSucceeded() }
    func colorReflexSceneDidPrematureTap(_ scene: ColorReflexGameScene) { feedback.gameFailed() }

    func colorReflexScene(_ scene: ColorReflexGameScene, didEndWith summary: ColorReflexSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(ColorReflexResultBuilder.makeResult(from: summary))
    }
}

enum ColorReflexResultBuilder {
    static func makeResult(from summary: ColorReflexSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "points", label: "Points", value: "\(summary.score)"),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
            GameMetric(key: "premature", label: "Premature taps", value: "\(summary.prematureTapCount)"),
        ]
        if let average = summary.averageReactionTime {
            metrics.append(GameMetric(key: "averageReaction", label: "Average reaction", value: MetricFormatter.milliseconds(average)))
        }
        if let best = summary.bestReactionTime {
            metrics.append(GameMetric(key: "bestReaction", label: "Best reaction", value: MetricFormatter.milliseconds(best)))
        }
        return GameResult(
            gameID: "colorReflex",
            score: summary.score,
            duration: summary.duration,
            averageReactionTime: summary.averageReactionTime,
            bestReactionTime: summary.bestReactionTime,
            metrics: metrics
        )
    }
}
