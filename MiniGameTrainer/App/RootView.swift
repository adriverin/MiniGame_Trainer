import SwiftUI

/// Hosts the navigation stack and resolves routes to views through the game registry.
struct RootView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(AppTheme.Colors.accent)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .gameIntro(let gameID):
            if let module = GameRegistry.module(for: gameID) {
                module.makeIntroView()
            } else {
                MissingGameView(gameID: gameID)
            }
        case .game(let gameID):
            if let module = GameRegistry.module(for: gameID) {
                module.makeGameView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                MissingGameView(gameID: gameID)
            }
        case .results(let result):
            ResultsView(result: result)
                .navigationBarBackButtonHidden(true)
        case .settings:
            SettingsView()
        }
    }
}

private struct MissingGameView: View {
    let gameID: String

    var body: some View {
        ContentUnavailableView("Unknown game", systemImage: "questionmark.square.dashed", description: Text(gameID))
    }
}
