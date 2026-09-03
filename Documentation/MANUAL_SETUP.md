# MiniGameTrainer Monetization Manual Setup

This file is the production checklist. Code uses explicit placeholders until these
steps are finished. The StoreKit Configuration file
(`MiniGameTrainer/Resources/Monetization.storekit`) is for **local Xcode testing
only**. App Store Connect remains the production source of products.

## A. Finalize Bundle Identifier

Detected current project bundle ID (`project.yml` `PRODUCT_BUNDLE_IDENTIFIER`):

`com.minigametrainer.app`

This is the identifier currently in the repo. Confirm it is the final App Store
bundle ID before creating products. If it changes, update product IDs to match.

Exact proposed subscription product IDs derived from the current bundle ID:

- Monthly: `com.minigametrainer.app.pro.monthly`
- Annual: `com.minigametrainer.app.pro.yearly`

Configured in `MiniGameTrainer/Features/Monetization/MonetizationConfiguration.swift`.

## B. Apple Developer / Agreements

In App Store Connect / Apple Developer:

- Accept the Paid Applications agreement
- Complete tax information
- Complete banking information
- Confirm the App Store Connect user can create subscriptions and submit the app

## C. Subscription Group

Create one subscription group:

**MiniGameTrainer Pro**

Both monthly and yearly products belong to this **same** group.

## D. Monthly Subscription

- Product ID: `com.minigametrainer.app.pro.monthly`
- Reference name: Pro Monthly
- Duration: 1 month
- Type: Auto-renewable subscription
- Target price: closest App Store price point to €3.99

The UI must **not** hard-code €3.99. It shows StoreKit `displayPrice`.

## E. Annual Subscription

- Product ID: `com.minigametrainer.app.pro.yearly`
- Reference name: Pro Annual
- Duration: 1 year
- Type: Auto-renewable subscription
- Same subscription group as monthly
- Target price: closest App Store price point to €24.99

Do not invent a savings percentage in the UI unless it is calculated from the
two loaded StoreKit prices in the same currency.

## F. Localization

Add subscription display names and descriptions for every storefront you ship.
Suggested English:

- Monthly display name: Monthly Pro
- Annual display name: Annual Pro
- Description: Unlimited attempts. No ads.

Localize further languages in App Store Connect, not in code.

## G. App Review Information

Have ready:

- Sandbox or demo Apple ID notes if Review needs them
- Screenshots of the paywall (localized prices, Restore, Terms, Privacy)
- Screenshots of the attempt gate and a rewarded-ad prompt
- A short review note: free users get 7 attempts per game per local day; extra
  attempts come only from a user-initiated rewarded ad (+3) or Pro

## H. AdMob Account

Create or use an existing Google AdMob account and accept the terms.

## I. AdMob App

Register an iOS app with the **exact** production bundle ID.

Obtain the AdMob App ID (`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`).

Paste it here, then run `xcodegen generate`:

1. `project.yml` → `targets.MiniGameTrainer.info.properties.GADApplicationIdentifier`
2. That regenerates `MiniGameTrainer/Resources/Info.plist`

The current value is Google's **official sample** App ID
`ca-app-pub-3940256099942544~1458002511` for development. It is **not** a
production App ID.

`MonetizationConfiguration.Ads.productionAdMobAppIDPlaceholder` documents the
same replacement.

## J. Rewarded Ad Unit

Create a **Rewarded** ad unit only. Do not create interstitial, rewarded
interstitial, banner, native, or app-open units for this app.

Paste the production rewarded unit ID into:

`MonetizationConfiguration.Ads.productionRewardedAdUnitIDPlaceholder`

DEBUG / development builds **always** use Google's official test unit:

`ca-app-pub-3940256099942544/1712485313`

Never load the production rewarded unit in DEBUG. Never click live production
ads during development.

## K. Privacy & Messaging / UMP

In AdMob → Privacy & messaging:

- Create a European regulations message
- Apply it to EEA, United Kingdom, and Switzerland (do not hard-code this in
  the app; UMP reads the AdMob configuration)
- Configure ad partners / vendors as required by that message
- Enable a privacy-options / manage-consent entry point so
  `privacyOptionsRequirementStatus` can become `.required`

The app calls `requestConsentInfoUpdate` on every launch, then
`ConsentForm.loadAndPresentIfRequired`.

DEBUG testing helpers (optional UserDefaults):

- `umpDebugGeography` = `eea` | `disabled` | `regulated`
- `umpDebugDeviceIdentifier` = UMP test device ID
- Settings → Monetization Debug → Reset UMP consent

## L. ATT Decision

**ATT is not implemented.**

This configuration:

- does not call `ATTrackingManager.requestTrackingAuthorization`
- does not add `NSUserTrackingUsageDescription`
- does not request IDFA
- serves rewarded ads after UMP `canRequestAds`, using SKAdNetwork items from
  the current Google Mobile Ads iOS quick-start

ATT is required only if the app later requests permission to track / use IDFA
(for example a Privacy & Messaging ATT prompt, or an explicit tracking
request). If that is enabled later:

- add the App Tracking Transparency framework
- add `NSUserTrackingUsageDescription` via `project.yml`
- sequence ATT with UMP per Google's current guidance

Until then, do not add an ATT dialog.

## M. App Privacy

Adding Google Mobile Ads changes App Store Connect App Privacy answers.
Do **not** invent legal answers here.

Review Google's current Mobile Ads / UMP data disclosures and declare only
what the enabled features actually collect. This app also stores local
per-game attempt counts in UserDefaults and processes subscriptions through
Apple. There is no first-party analytics SDK in the project today.

## N. Privacy Policy

A production Privacy Policy URL is required before release.

Replace:

`MonetizationConfiguration.privacyPolicyURL`

Current placeholder: `https://EXAMPLE-REQUIRED-PRIVACY-POLICY.invalid/privacy`

The policy should address at least:

- Google Mobile Ads / rewarded advertising
- consent management (UMP)
- subscription purchases through Apple
- local attempt-count storage
- any analytics that are actually present (none in this codebase today)

Do not claim collection that is not implemented.

## O. Terms of Use

Replace:

`MonetizationConfiguration.termsOfUseURL`

Current placeholder: `https://EXAMPLE-REQUIRED-TERMS.invalid/terms`

Alternatively use Apple's standard EULA (Paid Applications / custom license
setting in App Store Connect). If you use the standard EULA, the paywall
Terms link should point to Apple's EULA URL and this custom Terms URL can be
removed.

## P. Subscription Testing

1. Xcode scheme uses `MiniGameTrainer/Resources/Monetization.storekit` for local
   StoreKit testing. This is **not** App Store Connect.
2. Sandbox Apple ID: test monthly / yearly purchase, renewal, expiration.
3. TestFlight uses sandbox / production-signed products; local `.storekit`
   files do not apply.
4. Accelerated renewal in StoreKit Configuration does not match real renewal
   timing.
5. Test Restore Purchases: active subscription → Pro; expired → not Pro.
6. Test revocation / refund: Pro must drop after StoreKit current entitlements
   no longer include a verified qualifying product.

## Q. Rewarded Ad Testing

- DEBUG always uses `ca-app-pub-3940256099942544/1712485313`
- Test on a real device as well as Simulator
- Never click live production ads in development
- No +3 attempts until Google's reward callback
- Duplicate callback must still grant exactly +3
- Offline / no-fill: no grant, show "Ad unavailable right now", allow retry

## R. UMP Testing

- Consent required (EEA-style debug geography)
- Consent not required
- Privacy Options visible only when UMP says required
- Reset consent (DEBUG) and relaunch
- Confirm ads do not load until `canRequestAds` is true

## S. Production Checklist

Before App Store submission verify:

- [ ] Real AdMob App ID in `project.yml` / generated Info.plist
- [ ] Real rewarded unit in `MonetizationConfiguration.Ads`
- [ ] DEBUG test ad unit is not used in Release
- [ ] StoreKit products approved / ready to submit
- [ ] Both products in subscription group MiniGameTrainer Pro
- [ ] Paywall shows localized StoreKit prices (not hard-coded €)
- [ ] Restore Purchases
- [ ] Privacy Policy URL
- [ ] Terms / Apple EULA
- [ ] UMP European message configured
- [ ] App Privacy questionnaire updated from Google's docs
- [ ] ATT still intentionally omitted, or added if tracking was enabled
- [ ] No interstitial / banner / app-open / rewarded-interstitial ads
- [ ] Fresh install: 7 / 7 per game
- [ ] Pro purchase, restore, expiration
- [ ] Rewarded +3 for the exhausted game only
- [ ] Local midnight reset
- [ ] `xcodegen generate` is clean
- [ ] Clean build + full tests
