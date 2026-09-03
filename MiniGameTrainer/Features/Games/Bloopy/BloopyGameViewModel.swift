import Combine
import CoreGraphics
import Foundation

@MainActor
final class BloopyGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: BloopyGameConfig
    private let feedback: FeedbackService
    private(set) var scene: BloopyGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: BloopyDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: BloopyGameConfig, debugOptions: BloopyDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> BloopyGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = BloopyGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension BloopyGameViewModel: BloopyGameSceneDelegate {
    func bloopySceneDidBounce(_ scene: BloopyGameScene) { feedback.tapSucceeded() }
    func bloopySceneDidFail(_ scene: BloopyGameScene) { feedback.gameFailed() }

    func bloopyScene(_ scene: BloopyGameScene, didEndWith summary: BloopySessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(BloopyResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum BloopyResultBuilder {
    static func makeResult(from summary: BloopySessionSummary) -> GameResult {
        GameResult(
            gameID: BloopyGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            metrics: [
                GameMetric(key: "landings", label: "Landings", value: "\(summary.landings)"),
                GameMetric(key: "wraps", label: "Wraps", value: "\(summary.wrapCount)"),
                GameMetric(key: "height", label: "Max height", value: String(format: "%.0f", summary.maxWorldY)),
                GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
            ]
        )
    }
}
