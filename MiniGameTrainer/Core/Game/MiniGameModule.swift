import SwiftUI

/// The plug-in surface every minigame implements. The application shell only knows about this
/// protocol and `GameResult`; everything else (scenes, view models, configs) stays inside the
/// game's own feature folder.
///
/// Adding a new game:
/// 1. Create `Features/Games/<Name>/` with a type conforming to `MiniGameModule`.
/// 2. Register it in `GameRegistry.modules`.
/// 3. Start playable runs through `AppRouter.startGame` (Intro PLAY). Attempt gating is
///    applied there automatically — no game-specific monetization code.
/// 4. When the game ends, build a `GameResult` and hand it to `GameSessionHost.finish(_:)`,
///    which persists statistics and navigates to the shared results screen.
@MainActor
protocol MiniGameModule {
    static var descriptor: MiniGameDescriptor { get }

    /// The screen shown before the game starts (instructions + Play button).
    @ViewBuilder static func makeIntroView() -> AnyView

    /// The full-screen gameplay view. It must report completion through `GameSessionHost`.
    @ViewBuilder static func makeGameView() -> AnyView
}

/// Small facade games use to end a session: persists the result and routes to the results screen.
@MainActor
struct GameSessionHost {
    let router: AppRouter
    let statistics: StatisticsStore

    func finish(_ result: GameResult) {
        statistics.record(result)
        router.finishGame(with: result)
    }

    func quit() {
        router.quitToIntro()
    }
}
