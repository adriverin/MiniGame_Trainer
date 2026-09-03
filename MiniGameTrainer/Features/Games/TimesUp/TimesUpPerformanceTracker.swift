import Foundation

struct TimesUpLevelResult: Equatable {
    let levelIndex: Int
    let targetDuration: TimeInterval
    let visibleDuration: TimeInterval
    let actualElapsed: TimeInterval
    let signedError: TimeInterval
    let absoluteError: TimeInterval
    let direction: TimesUpTimingDirection
    let tapTimestamp: TimeInterval
}

struct TimesUpSessionSummary: Equatable {
    let results: [TimesUpLevelResult]
    let duration: TimeInterval

    var averageAbsoluteError: TimeInterval { TimesUpScoring.averageAbsoluteError(results) }
    var meanSignedError: TimeInterval { TimesUpScoring.meanSignedError(results) }
    var bestAbsoluteError: TimeInterval? { results.map(\.absoluteError).min() }
    var worstAbsoluteError: TimeInterval? { results.map(\.absoluteError).max() }
    var earlyCount: Int { results.filter { $0.direction == .early }.count }
    var lateCount: Int { results.filter { $0.direction == .late }.count }
    var exactCount: Int { results.filter { $0.direction == .exact }.count }
    var scoreMilliseconds: Int { TimesUpScoring.scoreMilliseconds(averageAbsoluteError: averageAbsoluteError) }
}

enum TimesUpFormatter {
    static func seconds(_ value: TimeInterval, signed: Bool = false) -> String {
        let magnitude = String(format: "%.2f", abs(value))
        if signed && value > 0 { return "+\(magnitude)s" }
        return "\(magnitude)s"
    }

    static func bias(_ value: TimeInterval) -> String {
        if abs(value) < 0.0005 { return "0.00 s" }
        let label = value > 0 ? "late" : "early"
        return "\(String(format: "%.2f", abs(value))) s \(label)"
    }

    static func directionCopy(_ direction: TimesUpTimingDirection) -> String {
        switch direction {
        case .exact: "Exact!"
        case .early: "Too early!"
        case .late: "Too late!"
        }
    }
}
