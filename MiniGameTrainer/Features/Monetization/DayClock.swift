import Foundation

/// Injectable clock so daily-reset tests do not depend on the real device date.
protocol DayClock: AnyObject {
    var now: Date { get }
}

final class SystemDayClock: DayClock {
    var now: Date { Date() }
}

final class MutableDayClock: DayClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

enum LocalDayIdentifier {
    static func make(now: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: now)
        let era = components.era ?? 1
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%d-%04d-%02d-%02d", era, year, month, day)
    }
}
