import Combine
import CoreGraphics
import Foundation

@MainActor
final class JumpyGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }
    @Published private(set) var phase: Phase = .running
    let config: JumpyGameConfig
    private let feedback: FeedbackService
    private(set) var scene: JumpyGameScene?
    var onFinish: ((GameResult) -> Void)?
    var debugOptions: JumpyDebugOptions { didSet { scene?.debugOptions = debugOptions } }

    init(config: JumpyGameConfig, debugOptions: JumpyDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> JumpyGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = JumpyGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene else { return }
        scene.pauseGame()
        phase = .paused
    }
    func resume() { guard phase == .paused else { return }; scene?.resumeGame(); phase = .running }
    func restart() { scene?.startSession(); phase = .running }
    func tearDown() { feedback.stop() }
}

@MainActor
extension JumpyGameViewModel: JumpyGameSceneDelegate {
    func jumpySceneDidHop(_ scene: JumpyGameScene) { feedback.tapSucceeded() }
    func jumpySceneDidCollide(_ scene: JumpyGameScene) { feedback.gameFailed() }
    func jumpyScene(_ scene: JumpyGameScene, didEndWith summary: JumpySessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(JumpyResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum JumpyResultBuilder {
    static func makeResult(from summary: JumpySessionSummary) -> GameResult {
        GameResult(
            gameID: JumpyGameModule.descriptor.id,
            score: summary.score,
            scorePresentation: JumpyGameModule.descriptor.scorePresentation,
            duration: summary.duration,
            metrics: [
                GameMetric(key: "distance", label: "Maximum distance", value: "\(summary.score)"),
                GameMetric(key: "jumps", label: "Total jumps", value: "\(summary.totalJumps)"),
                GameMetric(key: "forward", label: "Forward jumps", value: "\(summary.forwardJumps)"),
                GameMetric(key: "sideways", label: "Sideways jumps", value: "\(summary.sidewaysJumps)"),
                GameMetric(key: "backward", label: "Backward jumps", value: "\(summary.backwardJumps)"),
                GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
            ]
        )
    }
}
