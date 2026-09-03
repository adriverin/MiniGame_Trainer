import Foundation

/// Guards one rewarded presentation so duplicate callbacks cannot grant twice.
@MainActor
final class RewardedGrantSession {
    private struct Active {
        let token: UUID
        let gameID: String
        var didGrant: Bool
    }

    private var active: Active?

    var isPresenting: Bool { active != nil }

    func begin(gameID: String) -> UUID? {
        guard active == nil else { return nil }
        let token = UUID()
        active = Active(token: token, gameID: gameID, didGrant: false)
        return token
    }

    /// Returns the captured gameID the first time a reward is accepted for this token.
    func consumeReward(token: UUID) -> String? {
        guard var current = active, current.token == token, !current.didGrant else {
            return nil
        }
        current.didGrant = true
        active = current
        return current.gameID
    }

    func end(token: UUID) {
        guard active?.token == token else { return }
        active = nil
    }
}
