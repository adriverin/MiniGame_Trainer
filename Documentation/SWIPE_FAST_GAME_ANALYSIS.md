# SWIPE FAST Reference Analysis

Source recording: `ScreenRecording_09-03-2026 14-06-08_1.MP4` (HEVC, 1180×2556, 60.10 fps, 33.07 s, 1987 frames). The file is an iPhone screen recording of a YouTube Short of Playus “Swipe Fast”. YouTube chrome, avatars, leaderboards, percentile badges, and social overlays are not part of the trainer.

## Objective

Train **multi-target directional reaction**. Four boxes are live at once. Each shows one cardinal arrow. The player must swipe **inside** a box **in that box’s arrow direction** before that box’s personal deadline expires. A correct swipe scores one point, replaces that box’s arrow, and refills only that box’s timer. Higher integer score is better.

This is not a one-target highlight game and not a memory sequence.

## Session Flow

| Event | Recording time |
| --- | ---: |
| YouTube / Playus menus, “last attempt” modal | 0.00–6.5 s |
| Intro card: **SWIPE FAST!** + Spanish instructions + `Duración ~13s` (later `~15s`) | ~5.5–7.0 s |
| Gameplay appears, score **0**, four arrows, four full cyan bars | ~7.0 s |
| Overlay copy `Desliza en la dirección de las flechas!` on the grid | ~7.0 s (brief) |
| First point (score **1**) | ~8.0 s |
| Score ~10 | ~10.5 s |
| Score ~21 | ~14.5 s |
| Score ~37 | ~19.5 s |
| Score ~53 | ~24.5 s |
| Score ~68 | ~29.5 s |
| Score **70** | ~30.5 s |
| Score **71**, several bars red / near empty | ~30.9 s |
| Gameplay ends (boxes disappear under results overlay) | ~31.15–31.20 s |
| Results: `HAS PUNTUADO` / **71 Puntos** | ~31.5–33.0 s |

There is **no 3-2-1 countdown**. PLAY (in the source, the last-attempt confirm) lands on four live boxes immediately. The brief Spanish overlay is instruction, not a timer gate. Trainer: no countdown.

The intro duration chip (`~13s` / `~15s`) is a typical-run estimate. This 71-point run lasted **~23.6 s of play**, so the chip is **not** a global session clock.

## Four-Box Layout

Always a **2×2** of large rounded squares in the middle of the gameplay area:

| Box | Index | Typical start arrows (t ≈ 7.0 s, score 0) |
| --- | ---: | --- |
| Top-left | 0 | RIGHT |
| Top-right | 1 | UP |
| Bottom-left | 2 | UP |
| Bottom-right | 3 | UP |

All four arrows are visible simultaneously for the entire run. There is never a single highlighted target. The player chooses which urgent box to service next.

Boxes are slightly lighter than the purple field, large corner radius (squircle-like), uniform size, uniform gutters.

## Arrow Directions

Set: **UP / RIGHT / DOWN / LEFT** only. One arrow per box. White filled chevron, centered, rotated in 90° steps. No diagonals as targets.

At spawn, three of four boxes showed UP — same direction **can** appear in multiple boxes at once.

## Gesture Recognition

Not directly instrumented (no touch overlay). Inferred from successful play:

- A swipe belongs to the box where the finger **starts**.
- Classification is a cardinal direction from displacement.
- Rapid repeated swipes (~3 per second late game) score continuously — no 200–300 ms UI cooldown.
- Human swipes are imperfect; the run would be impossible with a tight ±15° cone. Dominant-axis classification is the defensible rule.
- One-finger play in this recording. No overlapping two-box scores from one motion.

Trainer defaults:

```
minimumDistance = 0.16 × boxSide   (≈ 28–36 pt on iPhone)
axis: abs(dx) > abs(dy) → horizontal, else vertical
sign(dx)/sign(dy) picks the cardinal
45° tie → vertical (abs(dy) >= abs(dx))
SpriteKit Y-up: +dy = up
```

Taps below the distance threshold are ignored.

## Per-Box State

**Confirmed independent.** Each box has its own direction and its own urgency bar. Swiping one box:

- changes that box’s arrow
- refills that box’s bar
- leaves the other three bars aging

Tracked across top-left / top-right / bottom-left / bottom-right at many timestamps (see Frame Measurements). At t ≈ 19.5 s, 24.5 s, 29.5 s, 30.9 s the four bars have **different lengths and different colors at the same frame**. They are not a duplicated global timer.

## Bottom Bars

Thin capsule on the **inner bottom edge** of each box.

| Question | Finding |
| --- | --- |
| A. Width shrinking? | **Yes.** Remaining fill is left-anchored. |
| B. Color changing? | **Yes.** Cyan → yellow → orange → red as remaining drops. |
| C. Both? | **Both.** |
| D. Drain direction | **Right → left** (left edge planted, right edge retracts). |
| E. Independent bar per box? | **Yes.** |
| F. Successful swipe refills only that box? | **Yes.** Other bars continue from their previous remaining fraction. |
| G. Difficulty affects drain rate? | **Yes, approximately.** Early bars stay mostly full cyan; by score 60–71 several bars are simultaneously yellow/orange/red. Drain is faster later. |

At spawn / just after a refill the bar is full-width cyan.

## Correct Swipe

On a matching swipe inside the box:

1. Score increments by **1** (see Scoring).
2. That box’s arrow is replaced immediately.
3. That box’s bar jumps back to full cyan.
4. The other three boxes are undisturbed.

No extra combo popup, no +2/+3 bursts observed.

## Wrong Swipe

**Unobserved.** This is a clean 71-point run; every visible swipe matches. The recording does not show a mismatched direction, so fail-vs-ignore is ambiguous.

Trainer default: **ignore** (consume the gesture, no score, no timer reset, no lives). Configurable to `gameOver` in DEBUG. Do not invent strikes.

## Timeout / Expiry

**Any one box reaching empty → immediate game over.**

Evidence:

- At t ≈ 30.9 s, score 71, bottom-left and bottom-right bars are red and ~5–10% remaining; top-right is orange ~25%.
- At t ≈ 31.00–31.13 s those red bars are at ~0–10%.
- At t ≈ 31.20 s gameplay is gone and the results overlay is up.
- No second-chance flash, no strike counter, no global clock hitting zero independently of the bars.

Wrong-swipe game-over is **not** required to explain this ending.

## Scoring

Integer, higher-is-better, **+1 per correct box swipe**.

Sampled on-screen values (recording time):

| t (s) | Score |
| ---: | ---: |
| 7.0 | 0 |
| 8.0 | 1 |
| 8.5 | 3 |
| 9.5 | 7 |
| 10.5 | 10 |
| 11.5 | 12 |
| 12.5 | 15 |
| 14.5 | 21 |
| 19.5 | 37 |
| 24.5 | 53 |
| 29.5 | 68 |
| 30.5 | 70 |
| 30.9 | 71 |

Increments are continuous singles (…12, 15, 21… / …68, 70, 71). No frame shows a jump of +2 or more. Score updates on recognition, in the same instant as the arrow swap.

Mean scoring rate ≈ **71 / 23.6 s ≈ 3.0 points/s**.

## Difficulty Progression

The game gets harder with score via **shorter per-box allowed time** (faster drain). Controls do not get less sensitive.

Qualitative:

| Score band | Bar look |
| --- | --- |
| 0–10 | All four full / near-full cyan; player is ahead of the deadlines |
| 10–20 | Mostly cyan; occasional shorter bar (~60–80%) |
| 30–40 | Visible desync; some bars ~60%, still mostly cyan |
| 50–60 | One box often yellow/orange and short while others are cyan |
| 60–71 | Several boxes urgent at once (yellow/orange/red), remaining often 10–50% |

If four independent deadlines of length `T` must all be serviced, the survival swipe rate is `4/T`. Early the player scores ~3/s with bars still full → `T` is longer than 4/3 ≈ 1.33 s (they have slack). At the death they score ~3/s with bars hitting zero → `T` has fallen near **1.0–1.2 s** (`4/T ≈ 3.3–4.0/s`), which they could not sustain.

Approximate model used by the trainer (piecewise linear, capped at the last evidence-supported anchor):

| Score | Allowed time (s) |
| ---: | ---: |
| 0 | 2.00 |
| 10 | 1.80 |
| 20 | 1.60 |
| 30 | 1.42 |
| 40 | 1.28 |
| 50 | 1.16 |
| 60 | 1.08 |
| 70+ | 1.00 |

These are **measured-informed anchors, not frame-exact**. Compression, YouTube occlusion, and unknown exact swipe timestamps prevent a unique least-squares `T(score)`. Human calibration should revisit drain speed.

No evidence of direction-distribution change, animation shortening as the primary difficulty, or input deadening.

## Direction Generation

- Uniform over `{up, right, down, left}` is consistent with the recording.
- Same direction **can** occupy several boxes (opening: three UPs).
- All four the same is allowed (not forbidden by evidence).
- Immediate repeat in the **same** box after a swipe: not cleanly measurable (arrows swap faster than 15 fps sampling plus classification noise). Trainer **allows** repeats.
- Only the swiped box is rerolled.

Seeded RNG in tests / DEBUG.

## Session End

Model **A**: any one box expires → immediate game over.

Rejected from this recording:

- B (wrong swipe) — unobserved, not needed to explain the end
- C (strike then continue) — no strike UI
- D/E (global / fixed duration) — bars are desynchronized; play lasted ~23.6 s vs a ~13 s chip
- F — expiry alone is sufficient

71 is a demonstrated score, not a cap.

## Geometry

Measured on native 1180×2556 frames of the Shorts capture. YouTube right-side icons and bottom chrome occlude the true phone margins; ratios are of the **visible Playus playfield**, then mapped to a full-screen trainer scene.

| Quantity | Measurement | Trainer ratio |
| --- | --- | --- |
| Box side | ~412 px tall on native (~0.161 of frame height); roughly square | `boxSizeRatio = 0.38` of scene width |
| Horizontal gap | ~40–80 px | `boxGapRatio = 0.045` of width |
| Vertical gap | ~38 px (0.015 of frame height) | same gap as horizontal, in points |
| Left edge of grid | x ≈ 0.061 of frame | grid centered at `0.50` |
| Top of top boxes | y ≈ 0.399 from top | SpriteKit center Y `boxGridCenterYRatio = 0.42` from bottom |
| Bottom of bottom boxes | y ≈ 0.745 from top | |
| Corner radius | large, ~18% of side | `boxCornerRadiusRatio = 0.18` |
| Bar thickness | ~18–22 px (~5% of box) | `barHeightRatio = 0.055` of box |
| Bar inset | sits inside rounded bottom, ~4% side inset | `barHorizontalInsetRatio = 0.06` |
| Bar Y | flush with inner bottom | `barBottomInsetRatio = 0.03` |
| Arrow | ~45% of box, white fill, no stroke | `arrowSizeRatio = 0.46` |
| Score | large white integer, center x ≈ 0.50, glyph band y ≈ 0.24–0.27 from top | `scoreYRatio = 0.72` from bottom; font `0.155` of width |

Background measured RGB(108, 22, 155) is Playus purple — **not copied**. Trainer uses the shared dark background and an original lighter box fill.

## High-Confidence Findings

- Four boxes always live; player multiplexes urgency.
- Per-box independent direction + independent bar/timer.
- Bar: left-anchored remaining width **and** cyan→yellow→orange→red.
- Successful swipe: +1, reroll that arrow, refill that bar only.
- Game over when a bar hits empty (observed at score 71).
- No countdown. Immediate four-box start.
- All four start full together; desync comes from asynchronous servicing, not a designed spawn stagger.
- Score is integer +1 per correct swipe; higher is better; 71 is not a cap.
- Difficulty is shorter allowed time as score rises, capped near 1.0 s.
- “Gain more time” means refill **that box’s** deadline, not a global clock.

## Ambiguities

- Exact `allowedTime(score)` function — anchors above are approximate.
- Exact color remaining-fraction cutovers (YouTube compression shifts hues).
- Wrong-swipe rule (unobserved) — default ignore, configurable game-over.
- Tap / too-short swipe (unobserved) — default ignore.
- Whether new direction is forced ≠ previous in the same box.
- Simultaneous two-finger swipes (unobserved) — default single active gesture.
- Whether a slow drag across the min distance still counts (assumed yes on `touchesEnded`).
- Intro duration chip vs actual 23.6 s play — treated as marketing estimate.
- Results overlay also flashes other numbers (37 / 54) from social UI; session score is **71**.

## Frame Measurements

Times are seconds in the recording. “Swipe time” is the first frame the arrow and bar have already updated — a 1–2 frame upper bound, not a digitizer timestamp. Bar % is visual remaining width.

### Per-box deadline table

| Score | Box | Arrow | Spawn (s) | Swipe (s) | Reaction (s) | Bar % before | Bar color | Result |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| 0→1 | TR | UP | 7.00 | ~7.9 | ~0.9 | ~95 cyan | cyan | +1, TR→LEFT, TR bar refill |
| 3 | mixed | — | — | 8.5 | — | all ~full | cyan | +1 cadence |
| 7 | mixed | — | — | 9.5 | — | all cyan | cyan | +1 |
| 10 | mixed | — | — | 10.5 | — | all cyan full | cyan | +1 |
| 12 | TL | DOWN | ~11.0 | 11.5 | ~0.5 | TL ~65, others ~90 | cyan | +1; **other bars not refilled** |
| 15 | mixed | — | — | 12.5 | — | cyan | cyan | +1 |
| 21 | mixed | — | — | 14.5 | — | cyan, slight desync | cyan | +1 |
| 36–37 | BR | DOWN | ~19.0 | 19.5 | ~0.5 | BR ~60, TL ~full, TR ~70, BL ~80 | cyan | +1; independent lengths |
| 53 | BL | RIGHT | ~24.0 | 24.5 | ~0.5 | BL ~33 yellow/orange; others cyan full | yellow | +1, BL refill only |
| 68 | mixed | — | — | 29.5 | — | TL ~35 orange, TR ~25 red, BL ~50 cyan, BR ~35 orange | mixed | still playing |
| 70 | TL | UP | — | 30.5 | — | TL short red; TR yellow | red/yellow | +1 |
| 71 | mixed | — | — | 30.9 | — | BL ~10 red, BR ~10 red, TR ~25 orange, TL ~40 cyan | mixed | last point |
| 71 | BL/BR | — | — | 31.15 | — | ~0–5 red | red | **expiry / game over** |

Opening directions after the first swipe (score 1, t ≈ 8.0 s): TL RIGHT (unchanged), TR LEFT (changed), BL UP, BR UP — only the serviced box rerolled.

## Proposed Configuration

```
boxCount = 4
allowedTime(score): piecewise linear anchors above, cap 1.00 s at score 70
wrongSwipe = ignore          // DEBUG: gameOver
minSwipeDistance = 0.16 × box
dominant axis, 45° → vertical
single active gesture
one gesture → start box only
score += 1 on correct
expiry of any box → gameOver
no countdown
no score cap
seeded RNG, uniform directions, repeats allowed
bar colors: cyan > 0.48, yellow > 0.30, orange > 0.16, else red
```
