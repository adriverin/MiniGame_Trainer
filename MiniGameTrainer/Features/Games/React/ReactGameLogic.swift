import Foundation

enum ReactGameState: String, Equatable {
    case ready
    case waiting
    case targetVisible
    case roundFeedback
    case finished
    case paused
}

enum ReactRoundFeedback: Equatable {
    case reaction(TimeInterval)
    case tooSoon
    case wrongTarget
}

enum ReactTapOutcome: Equatable {
    case ignored
    case started
    case premature
    case wrongTarget
    case correct(TimeInterval)
    case penaltyRecorded(TimeInterval)
}

/// Timestamp-driven state machine. It has no SpriteKit dependency and never counts frames.
final class ReactGameLogic {
    let config: ReactGameConfig

    private(set) var state: ReactGameState = .ready
    private(set) var activeTargetIndex: Int?
    private(set) var lastTargetIndex: Int?
    private(set) var stimulusPresentedTime: TimeInterval?
    private(set) var nextStimulusTime: TimeInterval?
    private(set) var scheduledDelay: TimeInterval?
    private(set) var lastFeedback: ReactRoundFeedback?
    private(set) var reactionTimes: [TimeInterval] = []
    private(set) var validReactionTimes: [TimeInterval] = []
    private(set) var prematureTapCount = 0
    private(set) var wrongTargetTapCount = 0

    private var randomizer: ReactRandomizer
    private var feedbackEndTime: TimeInterval?
    private var sessionStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var stateBeforePause: ReactGameState?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0

    init(config: ReactGameConfig) {
        self.config = config
        randomizer = ReactRandomizer(config: config)
    }

    var completedRoundCount: Int { reactionTimes.count }
    var currentRoundNumber: Int { min(completedRoundCount + 1, max(config.roundCount, 1)) }

    func start(at time: TimeInterval) {
        guard state == .ready else { return }
        sessionStartTime = time
        scheduleWaiting(from: time)
    }

    func update(at time: TimeInterval) {
        switch state {
        case .roundFeedback:
            if let feedbackEndTime, time >= feedbackEndTime {
                state = .waiting
                self.feedbackEndTime = nil
            }
            if state == .waiting { presentStimulusIfDue(at: time) }
        case .waiting:
            presentStimulusIfDue(at: time)
        default:
            break
        }
    }

    @discardableResult
    func handleTap(targetIndex: Int?, at time: TimeInterval) -> ReactTapOutcome {
        switch state {
        case .ready:
            start(at: time)
            return .started
        case .waiting, .roundFeedback:
            prematureTapCount += 1
            return handleInvalidTap(rule: config.earlyTapRule, feedback: .tooSoon, at: time, outcome: .premature)
        case .targetVisible:
            guard targetIndex == activeTargetIndex else {
                wrongTargetTapCount += 1
                return handleInvalidTap(rule: config.wrongTapRule, feedback: .wrongTarget, at: time, outcome: .wrongTarget)
            }
            guard let stimulusPresentedTime else { return .ignored }
            let reaction = max(0, time - stimulusPresentedTime)
            validReactionTimes.append(reaction)
            completeRound(with: reaction, feedback: .reaction(reaction), at: time)
            return .correct(reaction)
        case .finished, .paused:
            return .ignored
        }
    }

    func pause(at time: TimeInterval) {
        guard state != .paused, state != .finished else { return }
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
        activeTargetIndex = nil
        stimulusPresentedTime = nil
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pauseStartTime { accumulatedPausedTime += max(0, time - pauseStartTime) }
        let previous = stateBeforePause
        pauseStartTime = nil
        stateBeforePause = nil
        if previous == .ready {
            state = .ready
        } else {
            scheduleWaiting(from: time)
        }
    }

    func reset() {
        state = .ready
        activeTargetIndex = nil
        lastTargetIndex = nil
        stimulusPresentedTime = nil
        nextStimulusTime = nil
        scheduledDelay = nil
        lastFeedback = nil
        reactionTimes = []
        validReactionTimes = []
        prematureTapCount = 0
        wrongTargetTapCount = 0
        feedbackEndTime = nil
        sessionStartTime = nil
        finishTime = nil
        stateBeforePause = nil
        pauseStartTime = nil
        accumulatedPausedTime = 0
        randomizer = ReactRandomizer(config: config)
    }

    func makeSummary(at time: TimeInterval) -> ReactSessionSummary {
        let end = finishTime ?? time
        let duration = max(0, end - (sessionStartTime ?? end) - accumulatedPausedTime)
        return ReactSessionSummary(
            reactionTimes: reactionTimes,
            validReactionTimes: validReactionTimes,
            prematureTaps: prematureTapCount,
            wrongTargetTaps: wrongTargetTapCount,
            duration: duration
        )
    }

    private func presentStimulusIfDue(at time: TimeInterval) {
        guard let nextStimulusTime, time >= nextStimulusTime else { return }
        let target = randomizer.nextTarget(after: lastTargetIndex)
        activeTargetIndex = target
        lastTargetIndex = target
        stimulusPresentedTime = time
        self.nextStimulusTime = nil
        scheduledDelay = nil
        lastFeedback = nil
        state = .targetVisible
    }

    private func handleInvalidTap(
        rule: ReactInvalidTapRule,
        feedback: ReactRoundFeedback,
        at time: TimeInterval,
        outcome: ReactTapOutcome
    ) -> ReactTapOutcome {
        activeTargetIndex = nil
        stimulusPresentedTime = nil
        switch rule {
        case .restartWaiting:
            beginFeedback(feedback, at: time)
            return outcome
        case .recordPenalty:
            let penalty = max(0, config.invalidTapPenalty)
            completeRound(with: penalty, feedback: feedback, at: time)
            return .penaltyRecorded(penalty)
        }
    }

    private func completeRound(with reaction: TimeInterval, feedback: ReactRoundFeedback, at time: TimeInterval) {
        activeTargetIndex = nil
        stimulusPresentedTime = nil
        reactionTimes.append(reaction)
        if completedRoundCount >= max(config.roundCount, 1) {
            lastFeedback = feedback
            state = .finished
            finishTime = time
            nextStimulusTime = nil
            scheduledDelay = nil
        } else {
            beginFeedback(feedback, at: time)
        }
    }

    private func beginFeedback(_ feedback: ReactRoundFeedback, at time: TimeInterval) {
        lastFeedback = feedback
        state = .roundFeedback
        feedbackEndTime = time + max(0, config.feedbackDuration)
        scheduleNextStimulus(from: time)
    }

    private func scheduleWaiting(from time: TimeInterval) {
        state = .waiting
        lastFeedback = nil
        scheduleNextStimulus(from: time)
    }

    private func scheduleNextStimulus(from time: TimeInterval) {
        let delay = randomizer.nextDelay()
        scheduledDelay = delay
        nextStimulusTime = time + delay
    }
}
