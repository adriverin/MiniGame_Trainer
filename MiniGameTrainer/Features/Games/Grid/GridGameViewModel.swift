import Combine
import CoreGraphics
import Foundation

@MainActor
final class GridGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: GridGameConfig
    private let feedback: FeedbackService
    private(set) var scene: GridGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: GridDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: GridGameConfig, debugOptions: GridDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> GridGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = GridGameScene(size: size, config: config, debugOptions: debugOptions)
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

    func handleInterruption() {
        guard phase == .running, let scene, !scene.logic.isFinished else { return }
        scene.handleInterruption()
    }

    func tearDown() { feedback.stop() }
}

@MainActor
extension GridGameViewModel: GridGameSceneDelegate {
    func gridSceneDidToggle(_ scene: GridGameScene) { feedback.tapSucceeded() }
    func gridSceneDidSubmit(_ scene: GridGameScene, correct: Bool) { if correct { feedback.tapSucceeded() } }
    func gridSceneDidFail(_ scene: GridGameScene) { feedback.gameFailed() }

    func gridScene(_ scene: GridGameScene, didEndWith summary: GridSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(GridResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum GridResultBuilder {
    static func makeResult(from summary: GridSessionSummary) -> GameResult {
        let metrics = [
            GameMetric(key: "levelReached", label: "Level reached", value: "\(summary.levelReached)"),
            GameMetric(key: "roundsCompleted", label: "Patterns completed", value: "\(summary.roundsCompleted)"),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        return GameResult(
            gameID: GridGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.rounds.isEmpty
                ? nil
                : Double(summary.roundsCompleted) / Double(summary.rounds.count),
            metrics: metrics
        )
    }
}
