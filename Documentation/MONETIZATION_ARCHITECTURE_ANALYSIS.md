# Monetization Architecture Analysis

Inspected from canonical `main` at `1b57ff8` (15 registered games, no existing StoreKit / ads / privacy code).

## Current App Architecture

MiniGame Trainer is a SwiftUI shell plus SpriteKit minigames. The shell never depends on a concrete game type.

| Piece | Location | Role |
| --- | --- | --- |
| Entry | `MiniGameTrainer/App/MiniGameTrainerApp.swift` | Creates `AppRouter` + `AppEnvironment`, injects services as `@EnvironmentObject` |
| Services | `App/AppEnvironment.swift` | Owns `StatisticsStore`, `UserPreferences`, `FeedbackService` |
| Navigation | `App/AppRouter.swift` | `NavigationStack` path of `AppRoute` |
| Route views | `App/RootView.swift` | Resolves intro / game / results / settings through `GameRegistry` |
| Plug-in protocol | `Core/Game/MiniGameModule.swift` | `descriptor` + `makeIntroView()` + `makeGameView()` |
| Registry | `Core/Game/GameRegistry.swift` | Single array of 15 modules; adding a game is one extra line |
| Session facade | `GameSessionHost` | Persist result + route to results; quit back to intro |
| Persistence | `Core/Persistence/` | UserDefaults JSON (`statistics.v1`) and preference booleans |
| Settings | `Features/Settings/SettingsView.swift` | Sound, haptics, per-game stats, reset, version |
| Debug | `App/DebugLaunchOptions.swift` | DEBUG launch arguments / UserDefaults (`autoPlay`, `openIntro`, per-game flags) |

Deployment target is **iOS 17.0**, Swift 5, XcodeGen-driven (`project.yml`). Final production bundle ID is `com.gamewe.minigametrainer`. There are **no Swift packages** today.

Registered game IDs (source of truth for attempt accounting):

`piano`, `trampbox`, `react`, `towerStack`, `centerHit`, `keepUp`, `timesUp`, `grid`, `trace`, `directions`, `tapSeven`, `swipeFast`, `targetSpeed`, `bloopy`, `colorReflex`

There is no second session system, no per-game attempt manager, and no existing purchase / ad / ATT / UMP code.

## Game Session Lifecycle

```
Home
  → Library card → AppRouter.showIntro
    → Intro PLAY → AppRouter.startGame
      → RootView pushes module.makeGameView()
        → SKScene.didMove → scene.startSession() (countdown / play)
          → onFinish → GameSessionHost.finish → statistics.record + AppRouter.finishGame
            → Results
              → Try Again → AppRouter.retry → new game view
              → Home → AppRouter.goHome
```

Other start paths:

- DEBUG `-autoPlay <id>` currently writes `[.gameIntro, .game]` onto the path (bypasses the PLAY button, still creates a playable run).
- Pause-overlay **Restart** lives inside each game view (`viewModel.restart()` → `scene.startSession()`). It does **not** go through the router or `GameSessionHost`.

`GameSessionHost` is only a finish/quit facade. A playable run *starts* when `AppRouter` pushes `.game`. That is the shared logical start of every registered game.

## Best Attempt-Consumption Hook

**Use `AppRouter.startGame` and `AppRouter.retry` as the single authorization / consumption point.**

Reasons:

1. Every Intro PLAY already calls `router.startGame(descriptor.id)` (15 intros, identical pattern).
2. Results Try Again already calls `router.retry(gameID:)`.
3. Both methods already append `.game`, which is when SpriteKit creates the scene and a genuine run begins.
4. Future games inherit this automatically if they use the existing PLAY / Try Again plumbing.
5. It does not require a second session type and does not modify game physics / scoring.

Atomic rule: check remaining + consume on the same `@MainActor` turn before appending `.game`. Two rapid PLAY taps must start at most one session.

DEBUG auto-play will be changed to call `startGame` so it uses the same gate.

**Out of scope for consumption (documented decision):** in-session pause Restart. Hooking it would require editing every game scene, which violates “do not add monetization to 15 games” and “do not modify gameplay.” A pause Restart continues an already-consumed run. Quitting mid-run does not refund.

Do **not** consume on library open, intro open, settings, results, or Home.

## Existing Persistence

`StatisticsStore` and `UserPreferences` use isolated `UserDefaults` keys and Codable JSON. Tests inject `UserDefaults(suiteName:)`.

There is no database. Adding a versioned Codable `attempts.v1` blob beside `statistics.v1` is the consistent approach.

Local-only daily limits: a user who manually changes the device date/time can manipulate the free-attempt day. This implementation will **not** add a backend solely to prevent that.

## Existing Settings

`SettingsView` is a SwiftUI `Form` on `ScreenBackground`: Feedback toggles, per-game statistics, reset, version, disclaimer. No subscription, restore, legal, or privacy rows exist. New rows must use the same Form style.

## Dependency Injection

Pattern is `@StateObject` services on the app + `@EnvironmentObject` down the tree. `AppEnvironment` is the composition root and already accepts `UserDefaults` for tests.

Monetization services will be created there (`AttemptManager`, `PurchaseManager`, `ConsentManager`, `RewardedAdManager`) and injected the same way. `AppRouter` will hold `AttemptManager` so PLAY / retry stay centralized.

No `@Environment` key wrappers exist today; do not invent a parallel DI system.

## StoreKit Integration Point

iOS 17 supports StoreKit 2:

- `Product.products(for:)`
- `Product.purchase()`
- `Transaction.currentEntitlements` (not deprecated single-product helpers)
- `Transaction.updates` long-lived listener
- `AppStore.sync()` for restore
- `transaction.finish()` after verification

`PurchaseManager` is the single owner. Entitlement (`isPro`) is derived only from **verified** current entitlements for the configured monthly/yearly product IDs. Product-price loading is a separate concern so a catalog fetch failure cannot strip an already-verified Pro user.

Final production bundle ID: `com.gamewe.minigametrainer`. Final App Store Connect product IDs:

- `com.gamewe.minigametrainer.pro.monthly`
- `com.gamewe.minigametrainer.pro.yearly`

Create these identifiers in App Store Connect. They have not been created yet.

## Advertising Integration Point

No ads exist. Add Google Mobile Ads via XcodeGen `packages:` (canonical, survives `xcodegen generate`).

Only user-initiated rewarded ads. No interstitial, rewarded interstitial, banner, native, or app-open ads.

`RewardedAdManager` owns load / present / full-screen callbacks. SwiftUI only asks it to present for a captured `gameID`. Reward grants happen only from Google’s `userDidEarnRewardHandler`, once per presentation token.

DEBUG rewarded unit (never production): `ca-app-pub-3940256099942544/1712485313`.

The Mobile Ads Swift package **transitively** depends on `GoogleUserMessagingPlatform` (`1.1.0..<4.0.0` in the current Package.swift). Do not add a second UMP package copy.

## Consent Integration Point

UMP at every launch: `requestConsentInfoUpdate` then `ConsentForm.loadAndPresentIfRequired`. Ads initialize/load only when `ConsentInformation.shared.canRequestAds` is true, through one guarded path.

Privacy Options appears in Settings only when `privacyOptionsRequirementStatus == .required`.

Geography is not hard-coded; UMP uses the AdMob Privacy & Messaging configuration (EEA / UK / Switzerland).

## Info.plist / XcodeGen

`project.yml` generates `MiniGameTrainer/Resources/Info.plist`. New keys must be declared there:

- `GADApplicationIdentifier` — official Google **sample** App ID until production is supplied (`ca-app-pub-3940256099942544~1458002511`)
- `SKAdNetworkItems` — official Google list from the iOS quick-start (retrieved 2026-09-02), not an old blog post

No ATT key unless ATT is actually implemented (it will not be; see MANUAL_SETUP).

## Testing Strategy

Existing suite: **475** `func test*` methods (counted on this baseline). Pattern: isolated `UserDefaults` suites, deterministic game logic, no UI tests.

New tests will inject a `DayClock` + `Calendar` so midnight / DST / timezone cases do not depend on the real date. StoreKit cryptography is not unit-tested; a small `EntitlementEvaluator` maps verified vs unverified vs expired inputs. Reward double-grant is tested via `RewardedGrantSession`, not the live SDK.

## Proposed Architecture

```
AppEnvironment
  ├── AttemptManager + AttemptStore (UserDefaults attempts.v1)
  ├── PurchaseManager (StoreKit 2, Transaction.updates)
  ├── ConsentManager (UMP)
  └── RewardedAdManager (rewarded only, gated by canRequestAds + !isPro)

AppRouter.startGame / retry
  → AttemptManager.beginPlayableRun(gameID)   // atomic
      → .started  → push .game
      → .blocked  → push .attemptGate

RootView
  → intro wrapped with AttemptStatusBanner (no game-file edits)
  → AttemptGateView / PaywallView as shared routes
```

Future games: register in `GameRegistry` and use `router.startGame` / `GameSessionHost.finish`. No monetization code is required unless session start stops going through `AppRouter`.

Clock / calendar are injectable. Pro bypasses consumption without wiping the day’s free/bonus counters. Rewarded grants are rejected unless that game is exhausted (defense in depth). Local calendar-day IDs use `Calendar` components, never `timestamp / 86400`.
