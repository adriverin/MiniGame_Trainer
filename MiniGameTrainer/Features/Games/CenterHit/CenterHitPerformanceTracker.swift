import Foundation

struct CenterHitSessionSummary: Equatable {
    let attempts: [CenterHitAttempt]
    let duration: TimeInterval

    var averagePrecision: Double? { average(attempts.map(\.precision)) }
    var bestPrecision: Double? { attempts.map(\.precision).max() }
    var worstPrecision: Double? { attempts.map(\.precision).min() }
    var averageCenterError: Double? { average(attempts.map(\.absoluteError)) }
    var bestCenterError: Double? { attempts.map(\.absoluteError).min() }
    var leftToRightAveragePrecision: Double? { average(attempts.filter { $0.direction == .right }.map(\.precision)) }
    var rightToLeftAveragePrecision: Double? { average(attempts.filter { $0.direction == .left }.map(\.precision)) }

    var precisionStandardDeviation: Double? {
        guard let mean = averagePrecision, !attempts.isEmpty else { return nil }
        let variance = attempts.reduce(0) { $0 + pow($1.precision - mean, 2) } / Double(attempts.count)
        return sqrt(variance)
    }

    /// Percentage hundredths persisted in the existing integer score field.
    var scoreBasisPoints: Int { Int(((averagePrecision ?? 0) * 100).rounded()) }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

enum CenterHitFormatter {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.2f%%", value)
    }

    static func points(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f pt", value)
    }
}
