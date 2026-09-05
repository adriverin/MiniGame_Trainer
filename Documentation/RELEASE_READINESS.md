# gamewe — App Store Release Readiness

> **Branding checkpoint addendum — 5 September 2026:** The audit below records the
> original `6084edf` state. The release display name is now **gamewe**, matching
> the legal pages. The production AppIcon universal iOS slot now references the
> intended 1024 × 1024 artwork, with its unused alpha channel removed and RGB
> pixels preserved. The original missing-icon finding and naming follow-ups below
> are historical; build/test validation is recorded in the UI polish audit.
> Internal MiniGameTrainer names, bundle identifiers, subscription group, and all
> monetization configuration remain unchanged. The root PNG is a duplicate
> reference; the exported privacy PDF is QA evidence, neither is a build input.

**Audit date:** 5 September 2026  
**Canonical commit:** `6084edf` (`main`, matches `origin/main`)  
**Verdict: NOT READY TO SUBMIT**

One code-level blocker (missing App Icon). All other in-repo checks passed. App Store Connect, AdMob console, legal naming, and Distribution export remain operator work. This audit did not upload, submit, or push.

Identity note: this checklist originally named `com.minigametrainer.app`. Commit `c0e4990` replaced that placeholder. Current production identity on main is `com.gamewe.minigametrainer`. Do not create App IDs or StoreKit products under the old identifier.

---

## Check results

| # | Check | Result |
|---|---|---|
| 1 | Git status clean | **PASS** |
| 2 | Version and build number strategy | **PASS** |
| 3 | Bundle ID | **PASS** (`com.gamewe.minigametrainer`) |
| 4 | Deployment target | **PASS** (iOS 17.0) |
| 5 | Release signing configuration | **PASS** (Automatic + team `CA4ZH8R7Y7`) |
| 6 | DEBUG-only tooling cannot appear in Release | **PASS** |
| 7 | Leak search (demo ads, placeholders, TODO/FIXME, forcePro, overlays) | **PASS** |
| 8 | Production rewarded ads are explicit-user-action only | **PASS** |
| 9 | No banners / interstitials / app-open ads | **PASS** |
| 10 | UMP runs before eligible ad loading | **PASS** |
| 11 | Privacy Options can appear when required | **PASS** |
| 12 | ATT intentionally absent | **PASS** |
| 13 | StoreKit product IDs | **PASS** (`com.gamewe.minigametrainer.pro.*`) |
| 14 | Localized StoreKit display prices | **PASS** (code) |
| 15 | Restore Purchases | **PASS** (code) |
| 16 | Terms and Privacy production URLs | **PASS** |
| 17 | Exactly 15 games | **PASS** |
| 18 | Full unit tests | **PASS** (535 tests, 0 failures) |
| 19 | Clean Release build | **PASS** |
| 20 | `xcodegen generate` twice, second pass clean | **PASS** |
| 21 | No crashes/assertions/force-unwraps on monetization network paths | **PASS** |
| 22 | AppIcon / launch assets production quality and present | **FAIL** |
| 23 | Info.plist contains only required usage descriptions/config | **PASS** |
| 24 | Archive for generic iOS device | **PASS** (Development-signed archive) |
| 25 | This report | **PASS** |

---

## Exact blockers

### 1. Missing App Icon (check 22) — App Store rejection

`MiniGameTrainer/Resources/Assets.xcassets/AppIcon.appiconset/` contains only `Contents.json`. There is no 1024×1024 PNG (or any image). The slot has no `filename`.

Evidence from the Release archive:

- No `AppIcon*` files in the `.app`
- Archived `Assets.car` is 18,536 bytes (AccentColor + LaunchBackground only)
- Generated asset-catalog Info.plist has `NSAccentColorName` only — no `CFBundleIcons` / `CFBundleIconName`

Apple rejects uploads without a 1024×1024 App Store icon.

Launch screen itself is present: `UILaunchScreen` → `LaunchBackground` (solid dark color `#1A0C33`-class sRGB). That is valid, not branded. It is not the blocker.

**Required action:** add a production 1024×1024 App Icon to `AppIcon.appiconset` and regenerate. Do not ship the empty placeholder.

No other in-repo release-blocking defects were found. Gameplay calibration was not changed.

---

## Check notes

### 1. Git status

Working tree was clean on `main` at `6084edf`, up to date with `origin/main`, before this report was written. Producing this file is the only new local change.

### 2. Version and build strategy

| Field | Value | Source |
|---|---|---|
| Marketing version | `0.1.0` | `project.yml` → `CFBundleShortVersionString` |
| Build | `1` | `project.yml` → `CFBundleVersion` |

Single source of truth is `project.yml` `info.properties`, mirrored in `MiniGameTrainer/Resources/Info.plist`. No auto-increment. Confirmed in the Release `.app` and the archive.

Operator decision (not a code fail): first public listing often uses `1.0.0`. `0.1.0` is valid if that is the intended public version.

### 3. Bundle ID

Current production bundle ID:

`com.gamewe.minigametrainer`

Confirmed in `project.yml`, generated `project.pbxproj`, `MonetizationConfiguration.currentBundleID`, Release Info.plist, and the archive (`codesign` identifier + `CA4ZH8R7Y7.com.gamewe.minigametrainer`).

`com.minigametrainer.app` is the superseded placeholder. `MonetizationConfigurationTests` asserts product IDs do not contain `minigametrainer.app`.

### 4. Deployment target

iOS **17.0** in `project.yml`, project-level `IPHONEOS_DEPLOYMENT_TARGET`, and archived `MinimumOSVersion`. iPhone only (`TARGETED_DEVICE_FAMILY = 1`). Portrait only.

### 5. Release signing

- `CODE_SIGN_STYLE = Automatic` (project)
- Target `DEVELOPMENT_TEAM = CA4ZH8R7Y7`
- Target `CODE_SIGN_IDENTITY = iPhone Developer` (Debug and Release)
- Archive signed as **Apple Development: ADRIAN RODRIGUEZ GARCIA (86426UW2C5)**
- Profile: **iOS Team Provisioning Profile: \***
- Entitlement `get-task-allow = true` (expected on a Development archive; Organizer App Store export must re-sign with Apple Distribution and strip this)

Archive succeeded. This archive is not upload-ready until Distribution export.

### 6–7. DEBUG tooling and leak search

Release does **not** set `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`.

Gated with `#if DEBUG` (compiled out of Release):

- Launch flags: `-forcePro`, `-simulatePro`, `-forceFree`, `-grantBonus`, overlays, autoplay
- `PurchaseManager.debugOverride`
- `AttemptManager` debug grants / day override
- UMP `umpDebugGeography` / test device IDs
- Settings → Monetization Debug
- All 15 game tuning sheets / `*DebugSettingsView.swift`
- `MonetizationLog.debug` prints

Launch-argument overlay application in tuning stores is also `#if DEBUG`. Overlay drawing code exists in Release scenes but defaults to `.none` with no UI to enable it.

`TODO` / `FIXME` / `PLACEHOLDER` / `XXXX`: none in `MiniGameTrainer/` source.

Google sample App ID and rewarded test unit exist as named constants. Release `rewardedAdUnitID` is `#else productionRewardedAdUnitID`. Release Info.plist `GADApplicationIdentifier` is `ca-app-pub-2544426617197908~2256365307`. `strings` on the Release binary found **no** `3940256099942544`, `1712485313`, `forcePro`, `grantBonus`, or `umpDebugGeography`.

### 8. Rewarded ads are user-initiated only

`RewardedAdManager.watchAd` is called only from `AttemptGateView`’s “Watch ad · +3 attempts” button. Preload on gate appear and after dismiss does not present. Grant happens only in Google’s reward callback, once per `RewardedGrantSession` token. Pro skips ads.

### 9. No other ad formats

App code loads only `RewardedAd`. No `BannerView`, `InterstitialAd`, `AppOpenAd`, or rewarded-interstitial usage. Banner/interstitial/app-open symbols in the binary come from the Google Mobile Ads SDK, not app call sites. `AttemptStatusBanner` is a SwiftUI attempt-status chip, not an ad.

### 10. UMP before ads

`AppEnvironment.startMonetization()`:

1. `purchaseManager.start()`
2. `await consentManager.updateAndPresentIfRequired()`
3. `await rewardedAdManager.syncWithConsentAndEntitlement()`

`syncWithConsentAndEntitlement` / `preload` return unless `consent.canRequestAds` is true (and the user is not Pro). `MobileAds.shared.start` runs only after that gate.

### 11. Privacy Options

Settings → Legal shows “Privacy Options” only when `consent.privacyOptionsRequired` (`UMPConsentInformation.privacyOptionsRequirementStatus == .required`). It calls `presentPrivacyOptionsForm`. AdMob Privacy & Messaging must actually enable a privacy-options entry point (operator step).

### 12. ATT absent

No `NSUserTrackingUsageDescription` in `project.yml`, source `Info.plist`, or the Release/archive Info.plist. No `ATTrackingManager` / App Tracking Transparency usage. Intentional.

### 13–15. StoreKit

Configured product IDs:

- `com.gamewe.minigametrainer.pro.monthly`
- `com.gamewe.minigametrainer.pro.yearly`

Group name: `MiniGameTrainer Pro`. Local StoreKit file (Xcode testing only) matches. Paywall shows `product.displayPrice` from StoreKit; no hardcoded `€` / `3.99` / `24.99` in UI. Restore exists on Paywall and Settings (`AppStore.sync` + `Transaction.currentEntitlements`). Failed catalog shows “Subscriptions are unavailable right now.” with retry.

### 16. Legal URLs

| Link | URL |
|---|---|
| Privacy | `https://adriverin.github.io/gamewe_support/#privacy` |
| Terms | `https://adriverin.github.io/gamewe_support/#terms` |

Both are live HTTPS pages (effective 4 September 2026). Paywall and Settings use the same URLs. Compile-time `URL(string:)!` constants are valid and were not treated as network-path crash risk.

Residual review risk: the legal pages brand the product as **gamewe**, while the App Store display name is **MiniGame Trainer**. Align naming before review.

### 17. Games

`GameRegistry.modules` has exactly 15 entries. `AttemptManagerTests.testEveryRegisteredGameHasStableMonetizationIDAndOwnAllowance` asserts `ids.count == 15`.

1. Piano  
2. Trampbox  
3. React  
4. Tower Stack  
5. Center Hit  
6. Keep Up  
7. Time’s Up  
8. Grid  
9. Trace  
10. Directions  
11. Tap at 7  
12. Swipe Fast  
13. Target Speed  
14. Bloopy  
15. Color Reflex  

### 18–20. Tests, Release build, XcodeGen

- `xcodebuild test` (Debug, iPhone 17 Pro / iOS 26.4): **535 tests, 0 failures**. `TEST SUCCEEDED`.
- `xcodebuild clean build -configuration Release` (same simulator): **BUILD SUCCEEDED**.
- `xcodegen generate` twice: both passes left `git status` clean.

### 21. Monetization crash safety

StoreKit, UMP, and rewarded load/present use `do/catch` or `Result` and surface user-safe copy. Attempt persistence decode failure resets to empty. `PresentingViewController.topMost()` is optional. No `fatalError` / `precondition` / `try!` / `as!` on monetization network paths. `fatalError("Not supported")` exists only on unused SpriteKit `init(coder:)`.

### 23. Info.plist

Release Info.plist keys (plus SKAdNetwork list): display name, bundle ID, versions, `GADApplicationIdentifier` via `$(GAD_APPLICATION_IDENTIFIER)`, `ITSAppUsesNonExemptEncryption = false`, portrait orientations, dark UI, launch color, full-screen. No camera / mic / location / photos / tracking usage descriptions. None are required for the current feature set.

No app-level `PrivacyInfo.xcprivacy`. Google Mobile Ads / UMP ship their own. Residual: Apple may warn on first-party UserDefaults required-reason APIs at upload time.

### 24. Archive

```
xcodebuild archive -scheme MiniGameTrainer -configuration Release \
  -destination 'generic/platform=iOS'
```

**ARCHIVE SUCCEEDED** at `/tmp/MiniGameTrainer-audit.xcarchive`.

Not uploaded. Development identity + wildcard team profile + `get-task-allow`. Export via Organizer → App Store Connect with Apple Distribution before upload.

---

## Exact remaining App Store Connect / operator steps

Do these after the App Icon is added. Do not upload or submit from this audit.

### Apple Developer / App Store Connect

1. Confirm App ID `com.gamewe.minigametrainer` exists in the Apple Developer portal (explicit App ID, not only the wildcard development profile).
2. Create the iOS app record with that bundle ID if it does not exist.
3. Accept the Paid Applications agreement. Complete tax and banking.
4. Set marketing version `0.1.0` (or bump to `1.0.0` in `project.yml` first if that is the public version) and build `1`.
5. Prepare App Store listing: name **MiniGame Trainer**, subtitle, description, keywords, support URL, marketing URL (optional), category, age rating.
6. Add a 1024×1024 App Store icon that matches the in-app App Icon.
7. Add screenshots for required iPhone sizes (6.9" and any other currently required sizes). Capture attempt gate, rewarded-ad prompt, paywall (localized prices, Restore, Terms, Privacy), and gameplay.
8. Complete App Privacy (nutrition labels) from Google’s current Mobile Ads / UMP disclosures plus local attempt storage and Apple subscriptions. Do not invent collection. Declare no tracking if ATT remains omitted.
9. Set `ITSAppUsesNonExemptEncryption` already `false` in the binary; answer the export-compliance question consistently.
10. Choose custom license (Terms URL) or Apple’s standard EULA. If standard EULA, point the in-app Terms link at Apple’s EULA and update code/docs.

### Subscriptions

11. Create subscription group **MiniGameTrainer Pro**.
12. Create auto-renewable products:
    - `com.gamewe.minigametrainer.pro.monthly` — 1 month — nearest price point to €3.99
    - `com.gamewe.minigametrainer.pro.yearly` — 1 year — nearest price point to €24.99
13. Put both in the same group. Do not create IDs under `com.minigametrainer.app`.
14. Add storefront localizations (display name / description). Suggested English: Monthly Pro / Annual Pro — “Unlimited attempts. No ads.”
15. Submit the subscription group for review with the first app version (or follow current ASC subscription-review flow).
16. Local `Monetization.storekit` is **not** production. TestFlight / App Store use ASC products.

### AdMob / UMP (console)

17. Confirm the AdMob iOS app is registered as `com.gamewe.minigametrainer`.
18. Confirm Release App ID `ca-app-pub-2544426617197908~2256365307` and rewarded unit `ca-app-pub-2544426617197908/1399895858`.
19. Do not create interstitial, rewarded-interstitial, banner, native, or app-open units.
20. Create the European Privacy & Messaging form for EEA, UK, and Switzerland, with a privacy-options entry point so Settings can show Privacy Options.
21. Never click live production ads during development. DEBUG already uses Google’s test rewarded unit.

### Legal

22. Align privacy/terms branding with the App Store name **MiniGame Trainer** (pages currently say **gamewe**).
23. Confirm both fragment URLs remain reachable on a clean device/browser.
24. Review contact email and Switzerland governing-law wording before submission.

### Signing / upload (manual, after icon)

25. In Xcode Organizer, open a **new** Release archive built after the icon is added.
26. Distribute → App Store Connect → upload. Let Xcode re-sign with **Apple Distribution** (must strip `get-task-allow`).
27. Do not upload the Development-signed `/tmp/MiniGameTrainer-audit.xcarchive` from this audit.
28. After upload: answer review questions, attach sandbox notes if needed, then submit for review only when you intend to.

### Device / sandbox verification (not automated here)

29. Fresh install: 7 / 7 free attempts per game.
30. Exhaust one game → Watch ad → +3 for that game only; other games unchanged.
31. Offline / no-fill: “Ad unavailable right now”, no grant, retry works.
32. UMP required vs not-required regions; Privacy Options visible only when required.
33. Purchase monthly and yearly; paywall shows storefront-localized `displayPrice`.
34. Restore with active subscription → Pro; expired / refunded → not Pro.
35. Local midnight reset of free and bonus attempts.

---

## What this audit did not do

- Did not add features or change gameplay calibration
- Did not invent an App Icon
- Did not upload to App Store Connect
- Did not submit for review
- Did not push
