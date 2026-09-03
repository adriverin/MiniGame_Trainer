# TARGET SPEED Reference Analysis

Source recording: `ScreenRecording_09-03-2026 15-22-32_1.MP4` (HEVC, 1180×2556, 60.10 fps, 177.35 s, 10659 frames). The file is an iPhone screen recording of a YouTube Short of Playus “Target Speed” (`@gd_nubot`, title “Playus - Target Speed 731 Points”). YouTube chrome, avatars, leaderboards, percentile badges (“Top 1% mundial”), gem rewards, and social overlays are not part of the trainer.

Frame analysis used 1 fps overview stills plus a 10 fps pass with calibrated score OCR (digit templates from known frames), heart-region red-blob counts, and red-circle target detection in the playfield. Score OCR confidence was 1.00 on almost every gameplay second.

## Objective

Train **multi-target reaction tapping**. Circular bullseye targets appear around a dark field. The player must tap each target before its personal lifetime expires. A successful tap scores **exactly one point** and removes that target. A timeout costs one life. The session starts with three lives. Higher integer score is better.

This is not a precision-ring game, not a memory sequence, and not a swipe game.

## Session Flow

| Event | Recording time |
| --- | ---: |
| YouTube / Playus menus, large bullseye teaser | 0.0–2.0 s |
| Gameplay HUD appears: 3 hearts, score **0**, Spanish instruction | ~2.0–3.0 s |
| Instruction: **¡Toca los objetivos antes de que desaparezcan!** | ~2.5–3.5 s |
| First point (score **1**) | 3.195 s |
| Score **50** | ~24 s |
| Score **100** | ~40 s |
| Score **200** | ~64 s |
| Score **300** | ~84 s |
| Score **400** | ~105 s |
| Confirmed life loss 3 → 2 | ~112.8–113.0 s (score ~435–436) |
| Score **500** | ~126 s |
| Score **600** | ~147 s |
| Score **700** | ~167 s |
| Score **709** still playing, 2 lives | 169–170 s |
| Score **727–730**, overlay begins | ~173.5–174.2 s |
| Results: **JUEGO TERMINADO / HAS PUNTUADO / 731 Puntos** | ~174.5–177 s |

There is **no 3-2-1 countdown**. After the Playus start confirm, instruction copy is brief and gameplay is already live. Trainer: no countdown; short instruction overlay only.

Play duration for the 731-point run is about **171 s** (first point at 3.2 s, results at ~174.5 s).

## Lives

The run begins with **3** red heart icons on the HUD row, left of the score.

| Time | Score | Lives before | Lives after | Active targets | Cause |
| ---: | ---: | ---: | ---: | ---: | --- |
| 3.2 | 1 | 3 | 3 | 1 | session start; no miss |
| 14.9 / 15.4 | 26–27 | 3 | 3 | 1–2 | **false** heart-detector flicker (recovered next frame) |
| **112.82** | **435 → 436** | **3** | **2** | 4–5 | **timeout miss** (score still rose because another target was hit in the same 100 ms bin) |
| 113–173 | 436–728 | 2 | 2 | 2–5 | no further confirmed miss |
| 173.9–174.2 | 728–730 | 2 | 1/0 (HUD collapsing under results) | 3–5 | end cascade / overlay occludes hearts |

The only high-confidence in-play life loss is **3 → 2 near score 435**. Score does **not** decrease on a miss.

Heart-detector flicker earlier in the run recovered immediately and is not treated as a real miss.

## Target Spawn

Targets appear at scattered playfield positions, not on a grid. Early play is mostly one live target. From score ~50 a second target is typical. From ~150–200, three live targets are common. Late play shows 3–5 at once.

New targets appear while others are still aging (different timer-ring colors in the same frame). Spawn is **asynchronous** and **not** gated on a successful hit.

## Target Size

Diameter / full recording width (1180 px), 10 fps detections, faded ghosts excluded:

| Score band | n | min | p25 | median | p75 | max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0–50 | 281 | 0.032 | 0.192 | 0.193 | 0.200 | 0.232 |
| 50–100 | 254 | 0.036 | 0.192 | 0.193 | 0.197 | 0.230 |
| 100–200 | 523 | 0.030 | 0.193 | 0.193 | 0.202 | 0.232 |
| 200–300 | 525 | 0.036 | 0.193 | 0.198 | 0.204 | 0.237 |
| 300–400 | 533 | 0.025 | 0.193 | 0.197 | 0.203 | 0.239 |
| 400–500 | 571 | 0.036 | 0.193 | 0.198 | 0.203 | 0.237 |
| 500–600 | 574 | 0.022 | 0.193 | 0.198 | 0.203 | 0.236 |
| 600–750 | 712 | 0.030 | 0.193 | 0.198 | 0.203 | 0.236 |

The dominant size is a **large** bullseye at **~0.193 width**. A minority tail of medium / small / tiny targets appears throughout and becomes more mixed later. Size is **not** one deterministic radius per score.

Trainer uses discrete tiers sampled from score-dependent weights:

| Tier | Diameter / width |
| --- | --- |
| Large | 0.175–0.228 |
| Medium | 0.090–0.155 |
| Small | 0.045–0.085 |
| Tiny | 0.022–0.040 |

## Target Lifetime

Visible-track spans are mostly **hit ages** (median 0.30–0.40 s) because this is a strong run. Full-lifetime proxies are the long unhit tracks:

| Score band | median visible | max visible (full-life proxy) |
| --- | ---: | ---: |
| 0–50 | 0.30 s | 1.10 s |
| 50–100 | 0.40 s | 1.10 s |
| 100–200 | 0.40 s | 2.00 s (possible track merge) |
| 200–400 | 0.40 s | 1.20–1.30 s |
| 400–700 | 0.40 s | 1.20–1.40 s |

Implemented lifetime anchors (score-linear, floor 1.10 s):

`1.40, 1.30, 1.25, 1.20, 1.18, 1.15, 1.12, 1.10` at scores `0, 50, 100, 200, 300, 400, 500, 700`.

Small-target tracks were shorter in the detector (median 0.30, max 0.60). That is **ambiguous**: detector drop-out on tiny red rings is as likely as a shorter lifetime. Trainer uses **the same lifetime regardless of radius**.

## Simultaneous Targets

| Score band | min | typical | max |
| --- | ---: | ---: | ---: |
| 0–50 | 0 | 1 | 2 (rare 3–4 if a fade ghost was counted) |
| 50–100 | 1 | 2 | 3 |
| 100–200 | 1 | 2 | 4 |
| 200–400 | 1 | 3 | 4 |
| 400–500 | 2 | 3 | 5 |
| 500–750 | 1 | 3 | 5–6 |

Configured maximum simultaneous targets: **5**, the largest count grounded in 1 fps stills (t=119, five detections). A 6-count in the 10 fps pass is treated as a possible fade/ghost overcount.

## Player Input

One-finger taps on the bullseye. No swipe, no hold, no multi-touch required. Rapid late-game tapping (~4.3 successful hits / s average across the run) implies no tap cooldown.

Hit testing is circular. Visible radius is the intended hitbox. A modest minimum accessibility radius (`0.028 × width`) is applied so the tiniest tier remains physically tappable; it is not a large hidden forgiveness disc.

## Successful Tap

1. Target is removed immediately (short optional shrink/fade in the scene only).
2. Score increments by **1**.
3. Lives unchanged.
4. Other targets keep their own clocks.

Score updates in the same instant the target disappears. No combo popup, no +2/+3 bursts.

## Miss

When a target’s deadline passes:

1. It darkens / turns translucent (already in a warning fade in the last ~22% of life).
2. Exactly one life is removed.
3. Score is unchanged.
4. The dark remnant is gone within ~0.20 s.
5. The session continues if lives remain.

Background taps (off every live target) were **not demonstrated**. Trainer **ignores** them: no life loss, no score penalty, no combo (there is no combo).

## Scoring

**Formula: +1 per successful tap.**

This is the highest-confidence finding in the recording.

10 fps OCR of the large white HUD score produced **730** score transitions:

| Delta | Count | Interpretation |
| ---: | ---: | --- |
| +1 | 717 | real hits |
| +2 | 2 | two hits inside one 100 ms bin (one at t=113.519 during the miss scramble) |
| other | 11 | OCR substitutions (`160→11→163`, `246→2→249`, `259→60→262`, `639→540→41→642`) |

Early gameplay already increments by 1 on large and small targets:

| t (s) | Before | After | Delta | Notes |
| ---: | ---: | ---: | ---: | --- |
| 3.195 | 0 | 1 | +1 | first hit, large |
| 3.794 | 1 | 2 | +1 | large |
| 4.293 | 2 | 3 | +1 | remaining target diameter ~0.097 |
| 8.287 | 10 | 11 | +1 | remaining ~0.088 |
| 13.578 | 22 | 23 | +1 | remaining ~0.046 still visible |

Average scoring rate after score ~180 is a nearly flat **~4.8 points / s**, which matches a skilled hit rate of ~4.8 taps / s under +1, not a size- or speed-scaled formula.

Hypotheses:

| Hypothesis | Result |
| --- | --- |
| A. constant points per target | **Accepted** |
| B. smaller targets worth more | Rejected (tiny and large both +1) |
| C. faster taps worth more | Rejected (slow and fast hits both +1) |
| D. size × reaction | Rejected |
| E. level multiplier | Rejected (no step-change in delta) |
| F. hidden size value | Rejected |
| G. combo / streak | Rejected (no burst deltas) |

Intro copy therefore does **not** say “smaller and faster targets are worth more.”

## Difficulty Progression

Difficulty is modeled as **score thresholds**, not elapsed time. High score and elapsed time rise together in this clean run; there is no long stall that would separate them. After the miss at score 435 the scoring rate stays ~4.8 / s, so a time-only model is not required.

Independent variables that change with score:

- target radius mix (more small/tiny later)
- lifetime (slight decrease, 1.40 → 1.10 s)
- spawn interval (0.50 → 0.20 s)
- simultaneous cap (1 → 5)

Scoring value does **not** change. Fade-warning fraction is constant.

## Target Generation

- Seeded RNG for position, size tier, and diameter inside the tier.
- Center is uniformly sampled in the play rect, then rejected if it would overlap an existing live target (`distance < r1 + r2 + padding`) or clip the play rect.
- Large targets are fully contained. Source examples stay inside the field; slight YouTube-chrome clipping on the recorded phone is not part of the trainer.
- Unique integer `id` per target. Array index is never used as identity.

## Visual Feedback

- Original bullseye: red outer, white ring, red center. Not a Playus asset.
- Thin timer ring just outside the bullseye. Starts full **green**, depletes, turns yellow / orange / red.
- Last 22% of lifetime: opacity ramps down (expiring warning). Still hittable through `expiresAt`.
- Hit: immediate remove + short scene pulse so rapid tapping is not blocked.
- Miss: dark translucent remnant for `missFadeDuration` (0.20 s), then remove.

## Session End

**0 lives → game over**, exactly once.

The Short reaches the Playus results card at 731 points. The HUD still shows 2 hearts at t=173 (score 727). The last half-second is occluded by the results overlay, so a final 2 → 0 cascade is **not fully visible**. The trainer still ends at 0 lives; there is no evidence of a time-limit ending, a score cap, or replenishing lives.

Do not copy the Playus “JUEGO TERMINADO / HAS PUNTUADO / Top 1% / HECHO” card. The shared trainer results screen is used.

## Geometry

Normalized to the **trainer scene** (SpriteKit Y-up). Recording measurements were taken on the full 1180×2556 phone frame, then remapped off YouTube chrome.

| Element | Recording (down-Y) | Trainer (Y-up) |
| --- | --- | --- |
| Hearts | x 0.13–0.30, y 0.248 from top | `livesXRatio 0.155`, `livesYRatio 0.745` |
| Score | center ~0.50, y 0.244 from top | `scoreXRatio 0.50`, `scoreYRatio 0.745` |
| Play field | x ~0.17–0.80, y ~0.31–0.79 of the phone | x 0.08–0.92, y 0.10–0.675 |
| Background | dark navy / charcoal | RGB(26, 31, 40) |

Score font is large, white, heavy, left-of-center / upper field — same family as other trainer games (`AvenirNext-Heavy`).

## High-Confidence Findings

- Integer score, higher-is-better, **+1 per hit**.
- 3 lives; a timeout costs exactly one life; score is unchanged on a miss.
- Green / yellow / orange / red depleting ring is a per-target lifetime.
- Targets fade before / at expiry.
- Early play is mostly one target; late play is 3–5.
- Spawn is asynchronous (independent clocks).
- Dominant diameter ~0.193 width, with a real small-target tail.
- Final recorded score **731**.
- Instruction: tap targets before they disappear.
- No countdown.

## Ambiguities

- Whether 0 lives was reached on camera (results overlay covers the last frames).
- Background-tap penalty (unobserved; ignored).
- Hidden extra hitbox forgiveness (unobserved; modest min radius only).
- Lifetime vs size (tiny tracks look shorter; likely detector loss).
- Exact ring sweep direction (implemented as clockwise remaining from 12 o’clock).
- Whether fade starts before deadline or only at deadline (implemented as last 22% warning + 0.20 s post-miss remnant).
- Max simultaneous 5 vs a possible 6-count in noisy frames.
- Difficulty(score) vs difficulty(time): score thresholds chosen as the simpler model.

## Video Measurements

Representative hits from the 10 fps OCR pass (remaining on-screen target after the score change; reaction is the visible age, not a touch log):

| Time | Score before | Score after | Delta | Lives | Diameter | Spawn / tap | Reaction | Lifetime (config) | Active |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 3.195 | 0 | 1 | 1 | 3 | 0.215 | first target | ~0.3 | 1.40 | 1 |
| 4.293 | 2 | 3 | 1 | 3 | 0.097 | async | ~0.3 | 1.40 | 1 |
| 9.185 | 11 | 12 | 1 | 3 | 0.225 / 0.192 | two live | ~0.3 | 1.38 | 2 |
| 13.578 | 22 | 23 | 1 | 3 | 0.046 | tiny present | ~0.3 | 1.37 | 2 |
| 19.868 | 38 | 39 | 1 | 3 | 0.203 / 0.107 | mixed | ~0.4 | 1.36 | 2 |
| 40.0 | 102 | — | — | 3 | 0.203 / 0.198 | band sample | — | 1.25 | 2 |
| 64.0 | 204 | — | — | 3 | ~0.20 ×3 | band sample | — | 1.20 | 3 |
| 84.0 | 306 | — | — | 3 | two large | band sample | — | 1.18 | 2 |
| 112.82 | 435 | 436 | 1 | 3→2 | several | **miss + hit** | — | 1.14 | 4–5 |
| 140.0 | 569 | — | — | 2 | 0.200 / 0.193 / 0.170 | band sample | — | 1.13 | 3 |
| 169.0 | 709 | — | — | 2 | 0.203 / 0.077 | small still present | — | 1.10 | 2 |
| 173.5 | 727 | 731 | +4 over ~1 s | 2 | mixed | end | — | 1.10 | 3 |

## Proposed Configuration

See `TargetSpeedGameConfig.reference`.

```
startingLives = 3
pointsPerHit = 1
lifetime anchors = 1.40 … 1.10 s
spawn anchors   = 0.50 … 0.20 s
maxActive       = 1 … 5
firstTargetDelay = 0.35 s
fadeWarningFraction = 0.22
missFadeDuration = 0.20 s
deadline inclusive: touchTimestamp <= expiresAt
background taps ignored
```
