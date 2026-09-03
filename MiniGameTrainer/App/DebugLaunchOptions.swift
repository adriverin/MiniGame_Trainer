import Foundation

/// DEBUG-only launch arguments for automation and quick manual checks, e.g.
/// `-autoPlay piano -pianoSkipCountdown -pianoOverlay -pianoAutoStart` or `-openIntro piano`.
/// Tower Stack: `-autoPlay towerStack -towerStackAutoStart -towerStackOverlay -towerStackGeometry`
/// `-towerStackAutoPlace 0` (perfect) / `0.05` (5 % offset), `-towerStackMissAt 20`, `-towerStackPauseAtScore 12`.
/// KEEP UP: `-autoPlay keepUp -keepUpAutoCatch -keepUpOverlay -keepUpGeometry`,
/// `-keepUpEdgeCatch 0.75`, `-keepUpMissAt 100`, `-keepUpPhysicsScore 40`, or `-keepUpNoTrail`.
enum DebugLaunchOptions {
    #if DEBUG
    static var autoPlayGameID: String? {
        UserDefaults.standard.string(forKey: "autoPlay")
    }

    static var openIntroGameID: String? {
        UserDefaults.standard.string(forKey: "openIntro")
    }

    static var pianoSkipCountdown: Bool { flag("pianoSkipCountdown") }
    static var pianoShowOverlay: Bool { flag("pianoOverlay") }
    static var pianoShowHitboxes: Bool { flag("pianoHitboxes") }
    static var pianoAutoStart: Bool { flag("pianoAutoStart") }

    private static func flag(_ name: String) -> Bool {
        CommandLine.arguments.contains("-\(name)") || UserDefaults.standard.bool(forKey: name)
    }

    @MainActor
    static func apply(router: AppRouter) {
        let tuning = PianoTuningStore.shared
        if pianoSkipCountdown { tuning.debugOptions.skipCountdown = true }
        if pianoShowOverlay { tuning.debugOptions.showPerformanceOverlay = true }
        if pianoShowHitboxes { tuning.debugOptions.showHitboxes = true }
        if pianoAutoStart { tuning.config.requiresTapToStart = false }
        if let gameID = autoPlayGameID, GameRegistry.module(for: gameID) != nil {
            router.path = [.gameIntro(gameID: gameID), .game(gameID: gameID)]
        } else if let gameID = openIntroGameID, GameRegistry.module(for: gameID) != nil {
            router.path = [.gameIntro(gameID: gameID)]
        }
    }
    #else
    @MainActor
    static func apply(router: AppRouter) {}
    #endif
}
