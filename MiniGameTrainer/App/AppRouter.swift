import SwiftUI
import Combine

/// Navigation destinations. Games are referenced by their descriptor id so the router
/// never depends on a concrete minigame type.
enum AppRoute: Hashable {
    case gameIntro(gameID: String)
    case game(gameID: String)
    case results(GameResult)
    case settings
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    func showIntro(for gameID: String) {
        path.append(.gameIntro(gameID: gameID))
    }

    func startGame(_ gameID: String) {
        path.append(.game(gameID: gameID))
    }

    /// Replaces the running game with its results so "back" never returns into a finished game.
    func finishGame(with result: GameResult) {
        if case .game = path.last {
            path.removeLast()
        }
        path.append(.results(result))
    }

    /// From results straight back into a fresh game.
    func retry(gameID: String) {
        if case .results = path.last {
            path.removeLast()
        }
        path.append(.game(gameID: gameID))
    }

    func quitToIntro() {
        if case .game = path.last {
            path.removeLast()
        }
    }

    func goHome() {
        path.removeAll()
    }

    func showSettings() {
        path.append(.settings)
    }
}
