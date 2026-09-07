import CoreGraphics
import Foundation

enum JellyCutRound: Int, CaseIterable, Equatable {
    case half, third, quarter

    var title: String {
        switch self {
        case .half: "Cut it in half!"
        case .third: "Cut one third!"
        case .quarter: "Cut one quarter!"
        }
    }

    var shortName: String {
        switch self {
        case .half: "Half"
        case .third: "Third"
        case .quarter: "Quarter"
        }
    }

    var targetFraction: Double {
        switch self {
        case .half: 0.5
        case .third: 1.0 / 3.0
        case .quarter: 0.25
        }
    }

    var displayTarget: String {
        switch self {
        case .half: "50%"
        case .third: "33%"
        case .quarter: "25%"
        }
    }
}

enum JellyCutScoring {
    static func achievedFraction(_ fractions: [Double], target: Double) -> (index: Int, value: Double) {
        fractions.enumerated().min {
            let left = abs($0.element - target)
            let right = abs($1.element - target)
            if abs(left - right) <= 1e-12 { return $0.element < $1.element }
            return left < right
        }.map { ($0.offset, $0.element) } ?? (0, 0)
    }

    static func accuracy(target: Double, achieved: Double) -> Double {
        guard target > 0 else { return achieved == 0 ? 100 : 0 }
        let relativeError = abs(achieved - target) / target
        return min(max(100 * (1 - relativeError), 0), 100)
    }

    static func displayedPercentages(_ fractions: [Double]) -> [Double] {
        guard fractions.count == 2 else { return fractions.map { ($0 * 1_000).rounded() / 10 } }
        let first = (fractions[0] * 1_000).rounded() / 10
        return [first, 100 - first]
    }
}

struct JellyCutRoundResult: Equatable {
    let round: JellyCutRound
    let line: JellyCutLine
    let pieces: [[CGPoint]]
    let fractions: [Double]
    let targetPieceIndex: Int
    let achievedFraction: Double
    let accuracy: Double
}

struct JellyCutSessionSummary: Equatable {
    let rounds: [JellyCutRoundResult]
    let duration: TimeInterval

    var averageAccuracy: Double {
        guard !rounds.isEmpty else { return 0 }
        return rounds.reduce(0) { $0 + $1.accuracy } / Double(rounds.count)
    }

    var averageAbsoluteFractionError: Double {
        guard !rounds.isEmpty else { return 0 }
        return rounds.reduce(0) {
            $0 + abs($1.achievedFraction - $1.round.targetFraction)
        } / Double(rounds.count)
    }

    var scoreBasisPoints: Int { Int((averageAccuracy * 100).rounded()) }
}

enum JellyCutGameState: Equatable {
    case active
    case resolving
    case summary
    case paused
    case finished
}

enum JellyCutCommitOutcome: Equatable {
    case invalid
    case scored(JellyCutRoundResult)
}

final class JellyCutGameLogic {
    let config: JellyCutConfig
    private(set) var shapes: [[CGPoint]]
    private(set) var currentRoundIndex = 0
    private(set) var state: JellyCutGameState = .active
    private(set) var results: [JellyCutRoundResult] = []

    private var sessionStartTime: TimeInterval
    private var finishTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var accumulatedPausedTime: TimeInterval = 0
    private var stateBeforePause: JellyCutGameState = .active

    init(shapes: [[CGPoint]], config: JellyCutConfig = JellyCutConfig(), startTime: TimeInterval = 0) {
        precondition(shapes.count >= JellyCutRound.allCases.count)
        self.shapes = shapes
        self.config = config
        sessionStartTime = startTime
    }

    var currentRound: JellyCutRound { JellyCutRound.allCases[currentRoundIndex] }
    var currentShape: [CGPoint] { shapes[currentRoundIndex] }
    var acceptsInput: Bool { state == .active }

    func commitCut(start: CGPoint, end: CGPoint, at time: TimeInterval) -> JellyCutCommitOutcome {
        guard state == .active,
              hypot(end.x - start.x, end.y - start.y) >= config.minimumGestureLength,
              let line = JellyCutLine(start: start, end: end, epsilon: config.geometryEpsilon),
              let split = JellyPolygonGeometry.split(currentShape, by: line, epsilon: config.geometryEpsilon),
              JellyPolygonGeometry.areaIsConserved(original: currentShape, split: split) else {
            return .invalid
        }
        let totalArea = JellyPolygonGeometry.area(of: currentShape)
        let areas = [
            JellyPolygonGeometry.area(of: split.negative),
            JellyPolygonGeometry.area(of: split.positive),
        ]
        guard totalArea > config.geometryEpsilon else { return .invalid }
        let fractions = areas.map { $0 / totalArea }
        guard fractions.allSatisfy({ $0.isFinite && $0 >= config.minimumPieceFraction }) else {
            return .invalid
        }
        let achieved = JellyCutScoring.achievedFraction(fractions, target: currentRound.targetFraction)
        let result = JellyCutRoundResult(
            round: currentRound,
            line: line,
            pieces: [split.negative, split.positive],
            fractions: fractions,
            targetPieceIndex: achieved.index,
            achievedFraction: achieved.value,
            accuracy: JellyCutScoring.accuracy(
                target: currentRound.targetFraction,
                achieved: achieved.value
            )
        )
        results.append(result)
        state = .resolving
        _ = time
        return .scored(result)
    }

    func advanceAfterResult() {
        guard state == .resolving else { return }
        if currentRoundIndex + 1 < JellyCutRound.allCases.count {
            currentRoundIndex += 1
            state = .active
        } else {
            state = .summary
        }
    }

    func finish(at time: TimeInterval) {
        guard state == .summary else { return }
        finishTime = time
        state = .finished
    }

    func pause(at time: TimeInterval) {
        guard state != .paused, state != .finished else { return }
        stateBeforePause = state
        pauseStartTime = time
        state = .paused
    }

    func resume(at time: TimeInterval) {
        guard state == .paused else { return }
        if let pauseStartTime { accumulatedPausedTime += max(0, time - pauseStartTime) }
        self.pauseStartTime = nil
        state = stateBeforePause
    }

    func summary(at time: TimeInterval) -> JellyCutSessionSummary {
        let end = finishTime ?? time
        return JellyCutSessionSummary(
            rounds: results,
            duration: max(0, end - sessionStartTime - accumulatedPausedTime)
        )
    }
}
