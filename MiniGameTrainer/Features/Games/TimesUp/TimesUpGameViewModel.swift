import Combine
import Foundation

@MainActor
final class TimesUpGameViewModel: ObservableObject {
    enum Phase: Equatable { case running, paused, finished }

    @Published private(set) var phase: Phase = .running
    @Published private(set) var levelFeedback: TimesUpLevelResult?
    @Published private(set) var sessionSummary: TimesUpSessionSummary?

    let config: TimesUpGameConfig
    private let feedback: FeedbackService
    private(set) var scene: TimesUpGameScene?
    var onFinish: ((GameResult) -> Void)?

    var debugOptions: TimesUpDebugOptions {
        didSet { scene?.debugOptions = debugOptions }
    }

    init(config: TimesUpGameConfig, debugOptions: TimesUpDebugOptions, feedback: FeedbackService) {
        self.config = config
        self.debugOptions = debugOptions
        self.feedback = feedback
    }

    func scene(for size: CGSize) -> TimesUpGameScene? {
        if let scene { return scene }
        guard size.width >= 50, size.height >= 50 else { return nil }
        let scene = TimesUpGameScene(size: size, config: config, debugOptions: debugOptions)
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
        levelFeedback = nil
        sessionSummary = nil
        phase = .running
        scene.startSession()
    }

    func startNextLevel() {
        levelFeedback = nil
        scene?.startNextLevel()
    }

    func confirmSessionResults() {
        guard phase != .finished, let sessionSummary else { return }
        phase = .finished
        onFinish?(TimesUpResultBuilder.makeResult(from: sessionSummary))
    }

    func tearDown() { feedback.stop() }
}

@MainActor
extension TimesUpGameViewModel: TimesUpGameSceneDelegate {
    func timesUpSceneDidRecordEstimate(_ scene: TimesUpGameScene) {
        feedback.tapSucceeded()
    }

    func timesUpScene(_ scene: TimesUpGameScene, didScore result: TimesUpLevelResult) {
        levelFeedback = result
        scheduleAutoAdvanceIfNeeded()
    }

    func timesUpScene(_ scene: TimesUpGameScene, didEndWith summary: TimesUpSessionSummary) {
        sessionSummary = summary
        if let last = summary.results.last {
            levelFeedback = last
        }
        scheduleAutoAdvanceIfNeeded()
    }

    private func scheduleAutoAdvanceIfNeeded() {
        #if DEBUG
        guard debugOptions.autoPlay != .off else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.phase == .running else { return }
            if self.sessionSummary != nil {
                self.confirmSessionResults()
            } else if self.levelFeedback != nil {
                self.startNextLevel()
            }
        }
        #endif
    }
}

@MainActor
enum TimesUpResultBuilder {
    static func makeResult(from summary: TimesUpSessionSummary) -> GameResult {
        let bias = TimesUpFormatter.bias(summary.meanSignedError)
        var metrics: [GameMetric] = [
            GameMetric(key: "best", label: "Best estimate", value: TimesUpFormatter.seconds(summary.bestAbsoluteError ?? 0)),
            GameMetric(key: "worst", label: "Worst estimate", value: TimesUpFormatter.seconds(summary.worstAbsoluteError ?? 0)),
            GameMetric(key: "bias", label: "Bias", value: bias),
            GameMetric(key: "early", label: "Early estimates", value: "\(summary.earlyCount)"),
            GameMetric(key: "late", label: "Late estimates", value: "\(summary.lateCount)"),
        ]
        for result in summary.results {
            metrics.append(
                GameMetric(
                    key: "level-\(result.levelIndex)",
                    label: "Level \(result.levelIndex)",
                    value: "\(TimesUpFormatter.seconds(result.signedError, signed: result.direction == .late)) \(TimesUpFormatter.directionCopy(result.direction))"
                )
            )
        }
        return GameResult(
            gameID: TimesUpGameModule.descriptor.id,
            score: summary.scoreMilliseconds,
            scorePresentation: .timingErrorSeconds,
            duration: summary.duration,
            averageReactionTime: summary.averageAbsoluteError,
            bestReactionTime: summary.bestAbsoluteError,
            metrics: metrics
        )
    }
}
