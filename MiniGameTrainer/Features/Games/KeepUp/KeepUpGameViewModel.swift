import Combine
import CoreGraphics
import Foundation

@MainActor
final class KeepUpGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: KeepUpGameConfig
    private let feedback: FeedbackService
    private(set) var scene: KeepUpGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: KeepUpDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: KeepUpGameConfig, debugOptions: KeepUpDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> KeepUpGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = KeepUpGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension KeepUpGameViewModel: KeepUpGameSceneDelegate {
    func keepUpSceneDidBounce(_ scene: KeepUpGameScene) { feedback.tapSucceeded() }
    func keepUpSceneDidFail(_ scene: KeepUpGameScene) { feedback.gameFailed() }

    func keepUpScene(_ scene: KeepUpGameScene, didEndWith summary: KeepUpSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(KeepUpResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum KeepUpResultBuilder {
    static func makeResult(from summary: KeepUpSessionSummary) -> GameResult {
        var metrics = [
            GameMetric(key: "averageCatchError", label: "Average catch error", value: percent(summary.averageCatchError)),
            GameMetric(key: "bestCatch", label: "Best catch", value: percent(summary.bestCatchError)),
            GameMetric(key: "closestSave", label: "Closest edge save", value: percent(summary.closestSaveError)),
            GameMetric(key: "peakSpeed", label: "Peak ball speed", value: String(format: "%.0f pt/s", summary.peakBallSpeed)),
            GameMetric(key: "platformTravel", label: "Platform travel", value: String(format: "%.0f pt", summary.platformTravel)),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        metrics.removeAll { $0.value == "–" }
        return GameResult(
            gameID: KeepUpGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.averageCatchError.map { max(0, 1 - Double($0)) },
            metrics: metrics
        )
    }

    private static func percent(_ value: CGFloat?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f%%", Double(value * 100))
    }
}
