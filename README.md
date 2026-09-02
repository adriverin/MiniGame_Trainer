# MiniGame Trainer

An iPhone app for practising short reaction/skill minigames. Each game is an isolated module
plugged into a shared shell (home, library, intro, results, statistics, settings). The library
currently contains **Piano**, **Trampbox**, and the five-round visual reaction trainer **REACT!**.
Reference measurements live in `Documentation/GAME_ANALYSIS.md`,
`Documentation/TRAMPBOX_GAME_ANALYSIS.md`, and `Documentation/REACT_GAME_ANALYSIS.md`.

This is an independent training app; it is not affiliated with any game platform and uses only
original assets.

## Requirements

- Xcode 16 or newer (built and tested with Xcode 26.4)
- iOS 17.0+ deployment target, iPhone only, portrait
- Swift 5 language mode, SwiftUI + SpriteKit, no third-party dependencies
- Optional: [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) if you
  change `project.yml`; the generated `MiniGameTrainer.xcodeproj` is committed so it is not required
  to build.

## Running the App

```bash
open MiniGameTrainer.xcodeproj          # scheme: MiniGameTrainer
# or from the command line:
xcodebuild -project MiniGameTrainer.xcodeproj -scheme MiniGameTrainer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project MiniGameTrainer.xcodeproj -scheme MiniGameTrainer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

If you edit `project.yml`, regenerate with `xcodegen generate`.

Flow: Home → game card → intro → PLAY → 3‑2‑1‑GO → "Tap the tiles" → gameplay → results → Try Again / Home.

## Architecture

```text
MiniGameTrainer/
├── App/            entry point, AppRouter (NavigationStack path), AppEnvironment (services),
│                   RootView (route → view), DebugLaunchOptions (DEBUG launch arguments)
├── Core/
│   ├── Game/       MiniGameModule protocol, MiniGameDescriptor, GameRegistry, GameResult,
│   │               GameSessionHost (persists a result and routes to results)
│   ├── Persistence/ StatisticsStore (UserDefaults JSON), GameStatistics, UserPreferences
│   ├── Feedback/   FeedbackService (haptics + synthesized sounds)
│   ├── Utilities/  SeededRandomNumberGenerator (SplitMix64)
│   └── UI/         AppTheme (colours/fonts), shared components
├── Features/
│   ├── Home/, GameLibrary/, Results/, Settings/   shell screens (SwiftUI)
│   └── Games/Piano/                               the Piano minigame (see below)
├── Resources/      asset catalog, Info.plist
MiniGameTrainerTests/   XCTest unit tests for the pure game logic and persistence
Documentation/GAME_ANALYSIS.md   frame-by-frame analysis of the reference recording
```

Principles:

- The shell knows games only through `MiniGameModule` (descriptor + intro view + game view) and
  `GameResult` (score, duration, accuracy, reaction times, display metrics). No game-specific
  state lives in app-level types.
- Every game gets independent statistics keyed by its descriptor id (`GameStatistics`).
- Real-time gameplay runs in SpriteKit (`SKScene` inside `SpriteView`); menus are SwiftUI.
- Simulation is separated from rendering: `PianoGameLogic` (rules, state machine, scrolling,
  spawning, hit/miss, scoring, metrics) has no SpriteKit dependency and is unit-tested.
  `PianoGameScene` renders it, forwards touches and emits countdown/hint/flash visuals.
  `PianoGameViewModel` bridges the scene to SwiftUI (pause, restart, results).

### SwiftUI ↔ SpriteKit

`PianoGameView` measures the full-screen size, creates one `PianoGameScene` via the view model
and hosts it in a `SpriteView` at the display's maximum refresh rate. The scene owns the
`PianoGameLogic`; every frame it calls `logic.update(deltaTime:)`, drains `PianoGameEvent`s and
syncs pooled `PianoTileNode`s to the simulated rows. Touches are handled in
`touchesBegan(_:with:)` and applied synchronously (no SwiftUI gesture layer). When the logic
reaches `gameOver`, the scene freezes, flashes red, waits briefly and reports a
`PianoSessionSummary`; the view model converts it into a `GameResult` and hands it to
`GameSessionHost`, which records statistics and navigates to the shared `ResultsView`.

## Adding a New Minigame

1. Create `Features/Games/<Name>/` and a type conforming to `MiniGameModule`:

   ```swift
   enum ReactionGameModule: MiniGameModule {
       static let descriptor = MiniGameDescriptor(
           id: "reaction", name: "Reaction", subtitle: "...", instructions: "...",
           iconName: "bolt.fill", difficulty: .easy, skills: ["Reaction"])
       static func makeIntroView() -> AnyView { AnyView(ReactionIntroView()) }
       static func makeGameView() -> AnyView { AnyView(ReactionGameView()) }
   }
   ```

2. Register it in `Core/Game/GameRegistry.swift`:

   ```swift
   static let modules: [any MiniGameModule.Type] = [
       PianoGameModule.self,
       ReactionGameModule.self,
   ]
   ```

3. In the game view, when the session ends, build a `GameResult` (score, duration, optional
   accuracy/reaction times, any `GameMetric`s you want on the results screen) and call
   `GameSessionHost(router:statistics:).finish(result)`. Use `router.startGame(id)` from your intro.

The home card, intro navigation, results screen, personal best and per-game statistics come for
free. Keep all game constants in the game's own config type and keep rules out of the `SKScene`.

## Piano Game

Files in `Features/Games/Piano/`:

| File | Responsibility |
|---|---|
| `PianoGameConfig.swift` | Every tunable constant (ratios, speeds, rules, timings). `.reference` = values inferred from the recording. |
| `PianoGeometry.swift` | Resolves ratios to points for a scene size (lane width, row height, playfield top, miss line). |
| `PianoTile.swift` | `PianoTile` (lane, state, timestamps) and `PianoRow` (contiguous scrolling band). |
| `PianoSpawner.swift` | Lane sequence rules (no repeated primary lane, double rows after unlock), seeded RNG. |
| `PianoDifficultyModel.swift` | `speed = min(initial + score × increase, max)`, spawn interval, reaction window. |
| `PianoGameLogic.swift` | State machine, movement, spawning, hit/miss evaluation, scoring, events. |
| `PianoPerformanceTracker.swift` | Per-tile reaction times, tap depth, accuracy → `PianoSessionSummary`. |
| `PianoGameEvent.swift` | `PianoGameState`, `PianoGameEvent`, tap outcomes. |
| `PianoGameScene.swift` | SpriteKit rendering, countdown, hint, touch input, red flash, debug overlay. |
| `PianoTileNode.swift` | Pooled sprite for a tile; hit → instant ghost + settle fade. |
| `PianoGameViewModel.swift` | Scene ownership, pause/resume/restart, feedback, `GameResult` mapping. |
| `PianoGameView.swift` / `PianoIntroView.swift` | SwiftUI hosting, pause overlay, intro screen. |
| `PianoTuningStore.swift` | Config used for the next session (edited by the DEBUG panel). |
| `Debug/` | `PianoDebugOptions`, `PianoDebugSettingsView` (DEBUG only). |

Mechanics (see `Documentation/GAME_ANALYSIS.md` for evidence): a contiguous column of rows scrolls
down 4 lanes; each row has one white tile (two after ~15 points, 15 % of rows). Tap every white
tile before its bottom edge crosses the miss line (~83 % of screen height). Each tile is +1.
Speed grows linearly with score. Tapping empty space or a consumed tile ends the game, as does a
missed tile. Tiles start stationary and begin moving on the first tap.

## Debug / Calibration Mode

Available in Debug builds only:

- **Tuning panel**: on the Piano intro screen tap the slider icon (top-right). Sliders/steppers for
  every `PianoGameConfig` value (layout ratios, speeds, spawning, rules, visual timings), a
  random seed field for deterministic lane sequences, and toggles for the overlays below. Changes
  apply to the next session; "Reset to reference values" restores the measured defaults.
- **Performance overlay**: FPS, state, score, active tiles, speed (pt/s and scene-heights/s),
  spawn interval, last reaction time, game time, node pool size.
- **Hitboxes**: green outlines of the tappable cell of every active tile.
- **Miss line**: red line at the configured miss ratio.
- **Skip countdown**.
- **Launch arguments** (Xcode scheme → Arguments, or `xcrun simctl launch ... <args>`):
  `-autoPlay piano` jumps straight into the game, `-openIntro piano` opens the intro screen;
  `-pianoSkipCountdown`, `-pianoOverlay`,
  `-pianoHitboxes`, `-pianoAutoStart` (no tap-to-start) toggle the corresponding options.

REACT has a DEBUG tuning panel for its wait range, grid geometry, colors, invalid-tap rules,
repeat prevention, seed, hitboxes, and timing overlay. Launch aids include `-autoPlay react`,
`-reactSkipStart`, `-reactOverlay`, `-reactHitboxes`, `-reactSeed <value>`, and the visual-QA-only
`-reactAutoTap`.

## Tests

`MiniGameTrainerTests` covers all three games plus shared statistics: scoring, invalid input,
timing arithmetic, randomization, geometry, difficulty curves, frame-rate independence, reset,
pause/interruption recovery, deterministic seeds, performance summaries, score direction, and
statistics persistence (86 tests). Run with the scheme's Test action or the `xcodebuild ... test`
command above.
# MiniGame_Trainer
