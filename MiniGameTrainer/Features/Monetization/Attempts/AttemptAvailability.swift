import Foundation

enum AttemptAvailability: Equatable {
    case proUnlimited
    case free(remaining: Int)
    case rewarded(remaining: Int)
    case exhausted

    var allowsPlay: Bool {
        switch self {
        case .proUnlimited, .free, .rewarded:
            return true
        case .exhausted:
            return false
        }
    }

    var canRequestRewardedAd: Bool {
        self == .exhausted
    }
}

enum PlayableRunStart: Equatable {
    case started
    case blocked
}
