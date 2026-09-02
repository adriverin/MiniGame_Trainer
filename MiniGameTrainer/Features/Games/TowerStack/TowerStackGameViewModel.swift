import Combine
import CoreGraphics
import Foundation

@MainActor
final class TowerStackGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: TowerStackGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TowerStackGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TowerStackDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TowerStackGameConfig, debugOptions: TowerStackDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TowerStackGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TowerStackGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene, scene.logic.state != .gameOver else { return }
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

extension TowerStackGameViewModel: TowerStackGameSceneDelegate {
    func towerStackSceneDidPlace(_ scene: TowerStackGameScene, placement: TowerStackPlacement) {
        if !placement.isMiss { feedback.tapSucceeded() }
    }

    func towerStackSceneDidFail(_ scene: TowerStackGameScene) { feedback.gameFailed() }

    func towerStackScene(_ scene: TowerStackGameScene, didEndWith summary: TowerStackSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(TowerStackResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum TowerStackResultBuilder {
    static func makeResult(from summary: TowerStackSessionSummary) -> GameResult {
        var metrics: [GameMetric] = [
            GameMetric(key: "averageOverlap", label: "Average overlap", value: MetricFormatter.percent(summary.averageOverlapRatio)),
            GameMetric(key: "bestPlacement", label: "Best placement", value: MetricFormatter.percent(summary.bestOverlapRatio)),
            GameMetric(key: "worstPlacement", label: "Worst placement", value: MetricFormatter.percent(summary.worstOverlapRatio)),
            GameMetric(key: "alignmentError", label: "Average alignment error", value: MetricFormatter.percent(summary.averageNormalizedOffset)),
            GameMetric(
                key: "finalFootprint",
                label: "Final footprint",
                value: "\(MetricFormatter.percent(summary.finalWidthRatio)) × \(MetricFormatter.percent(summary.finalDepthRatio))"
            ),
            GameMetric(key: "highestSpeed", label: "Highest speed", value: String(format: "%.2f widths/s", summary.highestSpeed)),
        ]
        metrics.removeAll { $0.value == "–" }
        return GameResult(
            gameID: TowerStackGameModule.descriptor.id,
            score: summary.score,
            duration: summary.duration,
            accuracy: summary.averageOverlapRatio,
            metrics: metrics
        )
    }
}
