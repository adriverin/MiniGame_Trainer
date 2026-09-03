import Combine
import CoreGraphics
import Foundation

@MainActor
final class DirectionsGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: DirectionsGameConfig
    private let feedback: FeedbackService
    private(set) var scene: DirectionsGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: DirectionsDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: DirectionsGameConfig, debugOptions: DirectionsDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> DirectionsGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = DirectionsGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension DirectionsGameViewModel: DirectionsGameSceneDelegate {
    func directionsSceneDidAcceptInput(_ scene: DirectionsGameScene) { feedback.tapSucceeded() }
    func directionsSceneDidCompleteRound(_ scene: DirectionsGameScene) { feedback.tapSucceeded() }
    func directionsSceneDidFail(_ scene: DirectionsGameScene) { feedback.gameFailed() }

    func directionsScene(_ scene: DirectionsGameScene, didEndWith summary: DirectionsSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(DirectionsResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum DirectionsResultBuilder {
    static func makeResult(from summary: DirectionsSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "levelReached", label: "Level reached", value: "\(summary.levelReached)"),
            GameMetric(key: "roundsCompleted", label: "Sequences completed", value: "\(summary.roundsCompleted)"),
            GameMetric(key: "correctInputs", label: "Correct directions", value: "\(summary.correctInputs)"),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        metrics.removeAll { $0.value == "–" }
        return GameResult(
            gameID: DirectionsGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.correctInputs == 0 ? nil : 1,
            metrics: metrics
        )
    }
}
