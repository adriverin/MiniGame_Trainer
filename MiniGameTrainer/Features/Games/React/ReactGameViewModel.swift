import Combine
import CoreGraphics
import Foundation

@MainActor
final class ReactGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: ReactGameConfig
    private let feedback: FeedbackService
    private(set) var scene: ReactGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: ReactDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: ReactGameConfig, debugOptions: ReactDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> ReactGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = ReactGameScene(size: size, config: config, debugOptions: debugOptions)
        scene.gameDelegate = self
        self.scene = scene
        feedback.prepare()
        return scene
    }

    func pause() {
        guard phase == .running, let scene, scene.logic.state != .finished else { return }
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
extension ReactGameViewModel: ReactGameSceneDelegate {
    func reactSceneDidRecordCorrectTap(_ scene: ReactGameScene) { feedback.tapSucceeded() }
    func reactSceneDidRecordInvalidTap(_ scene: ReactGameScene) { feedback.gameFailed() }

    func reactScene(_ scene: ReactGameScene, didEndWith summary: ReactSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(ReactResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum ReactResultBuilder {
    static func makeResult(from summary: ReactSessionSummary) -> GameResult {
        let metrics = [
            GameMetric(key: "fastest", label: "Fastest", value: MetricFormatter.milliseconds(summary.fastest)),
            GameMetric(key: "slowest", label: "Slowest", value: MetricFormatter.milliseconds(summary.slowest)),
            GameMetric(key: "median", label: "Median", value: MetricFormatter.milliseconds(summary.median)),
            GameMetric(key: "variation", label: "Reaction variation", value: standardDeviation(summary.standardDeviation)),
            GameMetric(key: "rounds", label: "Valid rounds", value: "\(summary.validRounds)"),
            GameMetric(key: "premature", label: "Premature taps", value: "\(summary.prematureTaps)"),
            GameMetric(key: "wrong", label: "Wrong-target taps", value: "\(summary.wrongTargetTaps)"),
        ]
        return GameResult(
            gameID: ReactGameModule.descriptor.id,
            score: summary.score,
            scorePresentation: .reactionMilliseconds,
            duration: summary.duration,
            averageReactionTime: summary.average,
            bestReactionTime: summary.fastest,
            metrics: metrics
        )
    }

    private static func standardDeviation(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "–" }
        return "\(Int((seconds * 1_000).rounded())) ms SD"
    }
}
