import Combine
import Foundation

@MainActor
final class SwipeFastGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: SwipeFastGameConfig
    private let feedback: FeedbackService
    private(set) var scene: SwipeFastGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: SwipeFastDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: SwipeFastGameConfig, debugOptions: SwipeFastDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> SwipeFastGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = SwipeFastGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension SwipeFastGameViewModel: SwipeFastGameSceneDelegate {
    func swipeFastSceneDidScore(_ scene: SwipeFastGameScene) { feedback.tapSucceeded() }
    func swipeFastSceneDidFail(_ scene: SwipeFastGameScene) { feedback.gameFailed() }

    func swipeFastScene(_ scene: SwipeFastGameScene, didEndWith summary: SwipeFastSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(SwipeFastResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum SwipeFastResultBuilder {
    static func makeResult(from summary: SwipeFastSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "correct", label: "Correct swipes", value: "\(summary.correctSwipes)"),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        if let average = summary.averageReactionTime {
            metrics.append(GameMetric(key: "averageReaction", label: "Average reaction", value: MetricFormatter.milliseconds(average)))
        }
        if let best = summary.bestReactionTime {
            metrics.append(GameMetric(key: "bestReaction", label: "Best reaction", value: MetricFormatter.milliseconds(best)))
        }
        if let box = summary.expiredBox {
            metrics.append(GameMetric(key: "expiredBox", label: "Expired box", value: box.label))
        }
        if let reason = summary.endReason {
            metrics.append(GameMetric(key: "endReason", label: "Ended by", value: reason == .expired ? "Timer" : "Wrong swipe"))
        }
        return GameResult(
            gameID: SwipeFastGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.correctSwipes + summary.wrongSwipes == 0
                ? nil
                : Double(summary.correctSwipes) / Double(summary.correctSwipes + summary.wrongSwipes),
            averageReactionTime: summary.averageReactionTime,
            bestReactionTime: summary.bestReactionTime,
            metrics: metrics
        )
    }
}
