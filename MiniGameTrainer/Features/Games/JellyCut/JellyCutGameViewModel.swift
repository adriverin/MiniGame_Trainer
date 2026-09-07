import Combine
import CoreGraphics
import Foundation

@MainActor
final class JellyCutGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    private let feedback: FeedbackService
    let config: JellyCutConfig
    private(set) var scene: JellyCutGameScene?
    var onFinish: ((GameResult) -> Void)?

    init(config: JellyCutConfig = JellyCutConfig(), feedback: FeedbackService) {
        self.config = config
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> JellyCutGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = JellyCutGameScene(size: size, config: config)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, scene?.logic.state != .finished else { return }
        scene?.pauseGame()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        scene?.resumeGame()
        phase = .running
    }

    func restart() {
        scene?.startSession()
        phase = .running
    }

    func tearDown() { feedback.stop() }
}

@MainActor
extension JellyCutGameViewModel: JellyCutGameSceneDelegate {
    func jellyCutScene(_ scene: JellyCutGameScene, didCutWithAccuracy accuracy: Double) {
        feedback.tapSucceeded()
    }

    func jellyCutScene(_ scene: JellyCutGameScene, didEndWith summary: JellyCutSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(JellyCutResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum JellyCutResultBuilder {
    static func makeResult(from summary: JellyCutSessionSummary) -> GameResult {
        let rounds = summary.rounds.map { result in
            GameMetric(
                key: result.round.shortName.lowercased(),
                label: "\(result.round.shortName) accuracy",
                value: String(format: "%.1f%%", result.accuracy)
            )
        }
        let metrics = rounds + [
            GameMetric(
                key: "averageFractionError",
                label: "Average fraction error",
                value: String(format: "%.2f pp", summary.averageAbsoluteFractionError * 100)
            ),
            GameMetric(key: "duration", label: "Duration", value: MetricFormatter.seconds(summary.duration)),
        ]
        return GameResult(
            gameID: JellyCutGameModule.descriptor.id,
            score: summary.scoreBasisPoints,
            scorePresentation: .precisionPercent,
            duration: summary.duration,
            accuracy: summary.averageAccuracy / 100,
            metrics: metrics
        )
    }
}
