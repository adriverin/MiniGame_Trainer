import Combine
import CoreGraphics
import Foundation

@MainActor
final class CenterHitGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    let config: CenterHitGameConfig
    private let feedback: FeedbackService
    private(set) var scene: CenterHitGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: CenterHitDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: CenterHitGameConfig, debugOptions: CenterHitDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> CenterHitGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = CenterHitGameScene(size: size, config: config, debugOptions: debugOptions)
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
extension CenterHitGameViewModel: CenterHitGameSceneDelegate {
    func centerHitSceneDidRecordTap(_ scene: CenterHitGameScene) {
        feedback.tapSucceeded()
    }

    func centerHitScene(_ scene: CenterHitGameScene, didEndWith summary: CenterHitSessionSummary) {
        guard phase != .finished else { return }
        phase = .finished
        onFinish?(CenterHitResultBuilder.makeResult(from: summary))
    }
}

@MainActor
enum CenterHitResultBuilder {
    static func makeResult(from summary: CenterHitSessionSummary) -> GameResult {
        let metrics = [
            GameMetric(key: "bestTap", label: "Best tap", value: CenterHitFormatter.percent(summary.bestPrecision)),
            GameMetric(key: "worstTap", label: "Worst tap", value: CenterHitFormatter.percent(summary.worstPrecision)),
            GameMetric(key: "averageError", label: "Average error", value: CenterHitFormatter.points(summary.averageCenterError)),
            GameMetric(key: "bestError", label: "Best error", value: CenterHitFormatter.points(summary.bestCenterError)),
            GameMetric(key: "consistency", label: "Precision variation", value: summary.precisionStandardDeviation.map { String(format: "%.2f pp SD", $0) } ?? "–"),
            GameMetric(key: "attempts", label: "Attempts", value: "\(summary.attempts.count)"),
        ]
        return GameResult(
            gameID: CenterHitGameModule.descriptor.id,
            score: summary.scoreBasisPoints,
            scorePresentation: .precisionPercent,
            duration: summary.duration,
            accuracy: summary.averagePrecision.map { $0 / 100 },
            metrics: metrics
        )
    }
}
