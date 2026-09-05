import Foundation

/// DEBUG-only launch arguments for automation and quick manual checks, e.g.
/// `-autoPlay piano -pianoSkipCountdown -pianoOverlay -pianoAutoStart` or `-openIntro piano`.
/// Tower Stack: `-autoPlay towerStack -towerStackAutoStart -towerStackOverlay -towerStackGeometry`
/// `-towerStackAutoPlace 0` (perfect) / `0.05` (5 % offset), `-towerStackMissAt 20`, `-towerStackPauseAtScore 12`.
/// KEEP UP: `-autoPlay keepUp -keepUpAutoCatch -keepUpOverlay -keepUpGeometry`,
/// `-keepUpEdgeCatch 0.75`, `-keepUpMissAt 100`, `-keepUpPhysicsScore 40`, or `-keepUpNoTrail`.
/// TIME'S UP: `-autoPlay timesUp -timesUpAutoStart -timesUpOverlay -timesUpGeometry`,
/// `-timesUpAutoTap`, `-timesUpAutoOffset 0.01`, or `-timesUpScript 0.01,-0.03,-0.16`.
/// GRID: `-autoPlay grid -gridOverlay -gridAutoCorrect -gridForcePattern -gridSeed 42`
/// `-gridLevel 10 -gridRows 5 -gridColumns 5 -gridTargets 8 -gridPresentation 0.8 -gridTimeout 5`.
/// TRACE: `-autoPlay trace -traceOverlay -traceAutoSolve -traceSkipPresentation -traceScore 90`.
/// DIRECTIONS: `-autoPlay directions -directionsAutoInput -directionsOverlay -directionsGeometry`,
/// `-directionsSkipPresentation -directionsLevel 12 -directionsSeed 1 -directionsFailAt 3`,
/// `-directionsSequence up,left,down,right`.
/// TAP AT 7: `-autoPlay tapSeven -tapSevenAutoStart -tapSevenOverlay -tapSevenGeometry`,
/// `-tapSevenAutoTap`, `-tapSevenAutoOffset 0.01`, `-tapSevenTarget 7`, `-tapSevenPerfect 0.0005`,
/// `-tapSevenMax 15`.
/// SWIPE FAST: `-autoPlay swipeFast -swipeFastAutoPlay -swipeFastOverlay -swipeFastGeometry`,
/// `-swipeFastScore 70 -swipeFastSeed 1 -swipeFastAllowedTime 1.2 -swipeFastWrongFails`,
/// `-swipeFastAutoExpire -swipeFastAutoWrong`.
/// TARGET SPEED: `-autoPlay targetSpeed -targetSpeedAutoHit -targetSpeedAutoMiss -targetSpeedOverlay`,
/// `-targetSpeedHitboxes -targetSpeedScore 400 -targetSpeedLives 3 -targetSpeedSeed 1`,
/// `-targetSpeedLifetime 1.2 -targetSpeedSpawn 0.22 -targetSpeedMaxActive 4`.
/// BLOOPY: `-autoPlay bloopy -bloopyAutoSteer -bloopyOverlay -bloopyGeometry`,
/// `-bloopyScore 400 -bloopySeed 17602 -bloopyNoTrail`.
/// JUMPY: `-autoPlay jumpy -jumpyAutoAdvance -jumpyControlQA -jumpyOverlay -jumpyHitboxes`,
/// `-jumpyScore 75 -jumpyDifficulty 120 -jumpySeed 42 -jumpyHoldCollision`.
/// Monetization (DEBUG): `-forcePro` / `-simulatePro`, `-forceFree`, `-setAttempts0`,
/// `-grantBonus`, `forceDayIdentifier`, `monetizationGameID`, `-showAttemptState`.
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
    static func apply(router: AppRouter, environment: AppEnvironment? = nil) {
        let tuning = PianoTuningStore.shared
        if pianoSkipCountdown { tuning.debugOptions.skipCountdown = true }
        if pianoShowOverlay { tuning.debugOptions.showPerformanceOverlay = true }
        if pianoShowHitboxes { tuning.debugOptions.showHitboxes = true }
        if pianoAutoStart { tuning.config.requiresTapToStart = false }
        let trace = TraceTuningStore.shared
        if flag("traceOverlay") { trace.debugOptions.showOverlay = true }
        if flag("traceHitboxes") { trace.debugOptions.showHitboxes = true }
        if flag("traceAutoSolve") { trace.debugOptions.autoSolve = true }
        if flag("traceAutoSolveWrong") {
            trace.debugOptions.autoSolve = true
            trace.debugOptions.autoSolveWrong = true
        }
        if flag("traceSkipPresentation") { trace.debugOptions.skipPresentation = true }
        if let index = CommandLine.arguments.firstIndex(of: "-traceScore"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = Int(CommandLine.arguments[index + 1]) {
            trace.debugOptions.forcedScore = max(0, value)
        }
        let bloopy = BloopyTuningStore.shared
        if flag("bloopyOverlay") { bloopy.debugOptions.showOverlay = true }
        if flag("bloopyGeometry") { bloopy.debugOptions.showGeometry = true }
        if flag("bloopyAutoSteer") { bloopy.debugOptions.autoSteer = true }
        if flag("bloopyNoTrail") { bloopy.debugOptions.showTrail = false }
        if let index = CommandLine.arguments.firstIndex(of: "-bloopyScore"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = Int(CommandLine.arguments[index + 1]) {
            bloopy.debugOptions.forcedScore = max(0, value)
        }
        if let index = CommandLine.arguments.firstIndex(of: "-bloopySeed"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = UInt64(CommandLine.arguments[index + 1]) {
            bloopy.config.randomSeed = value
        }
        let jumpy = JumpyTuningStore.shared
        if flag("jumpyOverlay") { jumpy.debugOptions.showOverlay = true }
        if flag("jumpyHitboxes") { jumpy.debugOptions.showHitboxes = true }
        if flag("jumpyAutoAdvance") { jumpy.debugOptions.autoAdvance = true }
        if flag("jumpyHoldCollision") { jumpy.debugOptions.holdCollision = true }
        if flag("jumpyControlQA") {
            jumpy.debugOptions.controlQAScript = true
            jumpy.debugOptions.disableCollisions = true
            jumpy.debugOptions.showOverlay = true
        }
        if let index = CommandLine.arguments.firstIndex(of: "-jumpyScore"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = Int(CommandLine.arguments[index + 1]) {
            jumpy.config.startingScore = max(0, value)
        }
        if let index = CommandLine.arguments.firstIndex(of: "-jumpyDifficulty"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = Int(CommandLine.arguments[index + 1]) {
            jumpy.debugOptions.forcedDifficultyScore = max(0, value)
        }
        if let index = CommandLine.arguments.firstIndex(of: "-jumpySeed"),
           CommandLine.arguments.indices.contains(index + 1),
           let value = UInt64(CommandLine.arguments[index + 1]) {
            jumpy.config.randomSeed = value
        }
        applyMonetizationDebug(environment: environment)
        if let gameID = autoPlayGameID, GameRegistry.module(for: gameID) != nil {
            router.path = [.gameIntro(gameID: gameID)]
            router.startGame(gameID)
        } else if let gameID = openIntroGameID, GameRegistry.module(for: gameID) != nil {
            router.path = [.gameIntro(gameID: gameID)]
        }
    }

    @MainActor
    private static func applyMonetizationDebug(environment: AppEnvironment?) {
        guard let environment else { return }
        if flag("forcePro") || flag("simulatePro") {
            environment.purchaseManager.debugOverride = .forcePro
        }
        if flag("forceFree") {
            environment.purchaseManager.debugOverride = .forceFree
        }
        if let gameID = UserDefaults.standard.string(forKey: "monetizationGameID")
            ?? autoPlayGameID
            ?? openIntroGameID {
            if flag("setAttempts0") {
                environment.attemptManager.debugSetAttemptsExhausted(for: gameID)
            }
            if flag("grantBonus") {
                environment.attemptManager.debugGrantRewardedAttempts(for: gameID)
            }
        }
        if let day = UserDefaults.standard.string(forKey: "forceDayIdentifier"), !day.isEmpty {
            environment.attemptManager.debugDayIdentifierOverride = day
        }
        if flag("showAttemptState") {
            MonetizationLog.debug(environment.attemptManager.debugDumpState())
        }
    }
    #else
    @MainActor
    static func apply(router: AppRouter, environment: AppEnvironment? = nil) {}
    #endif
}
