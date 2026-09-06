import Combine
import CoreGraphics
import Foundation

@MainActor
final class ZigGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }
    @Published private(set) var phase: Phase = .running
    let config: ZigGameConfig
    private let feedback: FeedbackService
    private(set) var scene: ZigGameScene?
    var onFinish: ((GameResult) -> Void)?
    var debugOptions: ZigDebugOptions { didSet { scene?.debugOptions = debugOptions } }

    init(config: ZigGameConfig, debugOptions: ZigDebugOptions, feedback: FeedbackService) {
        self.config = config; self.debugOptions = debugOptions; self.feedback = feedback
    }

    func scene(for size: CGSize) -> ZigGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = ZigGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() { guard phase == .running else { return }; scene?.pauseGame(); phase = .paused }
    func resume() { guard phase == .paused else { return }; scene?.resumeGame(); phase = .running }
    func restart() { scene?.startSession(); phase = .running }
    func tearDown() { feedback.stop() }
}

@MainActor
extension ZigGameViewModel: ZigGameSceneDelegate {
    func zigSceneDidTurn(_ scene: ZigGameScene) { feedback.tapSucceeded() }
    func zigSceneDidFall(_ scene: ZigGameScene) { feedback.gameFailed() }
    func zigScene(_ scene: ZigGameScene, didEndWith summary: ZigSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(ZigResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum ZigResultBuilder {
    static func makeResult(from summary: ZigSessionSummary) -> GameResult {
        GameResult(
            gameID: ZigGameModule.descriptor.id,
            score: summary.score,
            scorePresentation: ZigGameModule.descriptor.scorePresentation,
            duration: summary.duration,
            metrics: [
                GameMetric(key: "distance", label: "Distance", value: "\(summary.score)"),
                GameMetric(key: "turns", label: "Turns", value: "\(summary.turns)"),
                GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
                GameMetric(key: "maximumSpeed", label: "Maximum speed", value: String(format: "%.2f units/s", summary.maximumSpeed)),
            ]
        )
    }
}
