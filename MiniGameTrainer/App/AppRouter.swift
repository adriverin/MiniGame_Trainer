import SwiftUI
import Combine

/// Navigation destinations. Games are referenced by their descriptor id so the router
/// never depends on a concrete minigame type.
enum AppRoute: Hashable {
    case gameIntro(gameID: String)
    case game(gameID: String)
    case results(GameResult)
    case settings
    case statistics
    case attemptGate(gameID: String)
    case paywall
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    let attemptManager: AttemptManager
    private var isLaunchingSession = false

    init(attemptManager: AttemptManager) {
        self.attemptManager = attemptManager
    }

    func showIntro(for gameID: String) {
        path.append(.gameIntro(gameID: gameID))
    }

    func startGame(_ gameID: String) {
        authorizeAndStart(gameID: gameID, replacingResults: false)
    }

    /// Replaces the running game with its results so "back" never returns into a finished game.
    func finishGame(with result: GameResult) {
        if case .game = path.last {
            path.removeLast()
        }
        path.append(.results(result))
    }

    /// From results straight back into a fresh game, after another attempt authorization.
    func retry(gameID: String) {
        authorizeAndStart(gameID: gameID, replacingResults: true)
    }

    func quitToIntro() {
        switch path.last {
        case .game, .attemptGate:
            path.removeLast()
        default:
            break
        }
    }

    func goHome() {
        path.removeAll()
    }

    func showSettings() {
        path.append(.settings)
    }

    func showStatistics() {
        if case .statistics = path.last { return }
        path.append(.statistics)
    }

    func showPaywall() {
        if case .paywall = path.last { return }
        path.append(.paywall)
    }

    func dismissPaywall() {
        if case .paywall = path.last {
            path.removeLast()
        }
    }

    private func authorizeAndStart(gameID: String, replacingResults: Bool) {
        if case .game(let current) = path.last, current == gameID {
            return
        }
        guard !isLaunchingSession else { return }
        isLaunchingSession = true
        defer { isLaunchingSession = false }

        if replacingResults, case .results = path.last {
            path.removeLast()
        }

        switch attemptManager.beginPlayableRun(for: gameID) {
        case .started:
            if case .attemptGate = path.last {
                path.removeLast()
            }
            path.append(.game(gameID: gameID))
            MonetizationLog.debug("Started playable run game=\(gameID)")
        case .blocked:
            if case .attemptGate(let current) = path.last, current == gameID {
                return
            }
            path.append(.attemptGate(gameID: gameID))
            MonetizationLog.debug("Blocked playable run game=\(gameID)")
        }
    }
}
