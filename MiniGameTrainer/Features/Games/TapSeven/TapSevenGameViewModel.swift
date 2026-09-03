import Combine
import Foundation

@MainActor
final class TapSevenGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running

    let config: TapSevenGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TapSevenGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TapSevenDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TapSevenGameConfig, debugOptions: TapSevenDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TapSevenGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TapSevenGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension TapSevenGameViewModel: TapSevenGameSceneDelegate {
    func tapSevenSceneDidRecordTap(_ scene: TapSevenGameScene) {
        feedback.tapSucceeded()
    }

    func tapSevenScene(_ scene: TapSevenGameScene, didEndWith summary: TapSevenSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(TapSevenResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum TapSevenResultBuilder {
    static func makeResult(from summary: TapSevenSessionSummary) -> GameResult {
        let result = summary.result
        let metrics = [
            GameMetric(key: "elapsed", label: "Elapsed", value: TapSevenFormatter.exactElapsed(result.actualElapsed) + " s"),
            GameMetric(key: "target", label: "Target", value: String(format: "%.3f s", result.targetDuration)),
            GameMetric(key: "error", label: "Absolute error", value: TapSevenFormatter.seconds(result.absoluteError)),
            GameMetric(
                key: "direction",
                label: "Direction",
                value: TapSevenFormatter.bias(result.signedError)
            ),
            GameMetric(key: "rating", label: "Rating", value: TapSevenFormatter.directionCopy(result.direction)),
        ]
        return GameResult(
            gameID: TapSevenGameModule.descriptor.id,
            score: summary.scoreMilliseconds,
            scorePresentation: TapSevenGameConfig.scorePresentation,
            duration: summary.duration,
            averageReactionTime: result.absoluteError,
            bestReactionTime: result.absoluteError,
            metrics: metrics
        )
    }
}
