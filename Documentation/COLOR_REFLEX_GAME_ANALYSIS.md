# COLOR REFLEX Reference Analysis

Source recording: `ScreenRecording_09-03-2026 16-08-06_1.MP4` (HEVC, 1180×2556, 60.09 fps, 46.545 s, 2798 frames). The file is an iPhone screen recording of a YouTube Short of Playus “Color Reflex”. YouTube chrome, avatars, leaderboards, percentile badges, and social overlays are not part of the trainer.

This is **not** REACT. REACT is a fixed number of discrete circle-target trials whose primary result is average reaction time (lower is better). COLOR REFLEX is a timed score-attack: the whole gameplay field changes color, the player taps, and the primary result is integer points (higher is better).

## Objective

Train **reaction time + inhibition**. The screen shows `Wait...` on a solid color. The player must not tap. After a random delay the entire gameplay background changes color and the text switches to `Tap!`. A successful tap scores **+1**. Premature taps cost session time. The run continues until the global session timer reaches zero. Higher integer score is better.

## Session Start

| Event | Recording time |
| --- | ---: |
| YouTube / Playus intro card | 0.00–1.50 s |
| Intro title **COLOR REFLEX** + Spanish instructions + `Duración ~27s` | 0.00–2.30 s |
| Purple **Start** button visible | ~1.00 s |
| First active gameplay frame (teal field, score `0`, `Wait...`, full top bar) | **2.367 s** |
| First color-change trigger | 3.933 s |
| Score `1` + `218 ms` feedback during next wait | ~4.50 s |
| Gameplay ends (field collapses to dark / results) | **43.767–43.800 s** |
| Results: `JUEGO TERMINADO` / **16 PUNTOS** | ~44.5–46.5 s |

There is **no 3-2-1 countdown**. Start lands directly in `Wait...`. Trainer mapping: intro PLAY → `GameSessionHost` start → `waiting` immediately.

## Wait Phase

Centered bold white copy: **`Wait...`** (title case, ellipsis). The player must suppress tapping. There is no visible countdown, pulse, or other cue that reveals the trigger instant. The current solid background stays on screen.

## Trigger / Color Change

At trigger time the **entire** main gameplay rectangle changes to a different saturated color and the text switches to **`Tap!`** on the same logical frame. Color and text are atomic from the player’s perspective. Reaction timing starts at that logical timestamp (`triggerTimestamp`).

Observed trigger colors (compressed RGB from 30 fps half-res samples):

| Name | Representative RGB |
| --- | ---: |
| teal | (21, 174, 156) |
| cyan | (69, 193, 239) |
| blue | (51, 122, 254) |
| purple | (122, 48, 236) |
| yellow | (255, 181, 14) |
| orange / coral | (255, 116, 71) |

The trainer uses an original high-separation palette in the same families. Exact Playus RGB values are not copied.

## Tap Phase

`Tap!` is centered in the same place as `Wait...`. The first new touch begin after the trigger is the reaction. Further touches from the same event are ignored.

## Reaction Measurement

```
reactionTime = tapTimestamp - triggerTimestamp
```

Both stamps are raw monotonic times (`CACurrentMediaTime()` or the injected test clock). Display rounding never feeds scoring. Observed on-screen feedback: `218 ms`, `237 ms`, `214 ms`.

## Scoring

Score increments 0 → 1 → … → 16, one integer per successful reaction. No multi-point bonus is visible. The results screen primary number is **16 PUNTOS**. A later social modal showing `14 Puntos` is treated as Playus overlay chrome (same class of mismatch seen in TIME'S UP), not the session score.

Primary persistence: integer points, **higher is better**. Average / best reaction are secondary metrics only.

## Random Delay

Measured from 30 fps color-change onsets. Wait start for round 1 is gameplay start. Later wait starts are estimated as `previousTrigger + 0.220 s` (the displayed first-reaction cluster). The 0.220 s offset is a display-based estimate, not a captured touch timestamp.

| Point | Wait start (est.) | Trigger | Random delay | Color before | Color after |
| ---: | ---: | ---: | ---: | --- | --- |
| 1 | 2.367 | 3.933 | 1.566 | teal | cyan |
| 2 | 4.153 | 5.700 | 1.547 | cyan | blue |
| 3 | 5.920 | 9.733 | 3.813 | blue | purple |
| 4 | 9.953 | 11.567 | 1.614 | purple | yellow |
| 5 | 11.787 | 12.367 | 0.580 | yellow | blue |
| 6 | 12.587 | 13.300 | 0.713 | blue | purple |
| 7 | 13.520 | 14.767 | 1.247 | purple | cyan |
| 8 | 14.987 | 17.033 | 2.046 | cyan | teal |
| 9 | 17.253 | 21.067 | 3.814 | teal | blue |
| 10 | 21.287 | 24.767 | 3.480 | blue | cyan |
| 11 | 24.987 | 27.567 | 2.580 | cyan | purple |
| 12 | 27.787 | 28.533 | 0.746 | purple | yellow |
| 13 | 28.753 | 32.133 | 3.380 | yellow | orange |
| 14 | 32.353 | 36.067 | 3.714 | orange | purple |
| 15 | 36.287 | 39.067 | 2.780 | purple | teal |
| 16 | 39.287 | 41.200 | 1.913 | teal | purple |
| 17 (no score) | 41.420 | 43.733 | 2.313 | purple | cyan |

A 17th trigger appears ~67 ms before the field goes dark. Score stays 16 — the last tap window is cut off by session end.

## Random Delay Distribution

| Statistic | Value (s) |
| --- | ---: |
| Minimum (successful) | 0.580 |
| Maximum (successful) | 3.814 |
| Mean (16 successful) | 2.115 |
| Sample size | 16 successful + 1 truncated |

The sample is small. Values occupy the whole interval; there is no obvious discrete ladder. Simplest supported model:

```
waitDelay = rng.uniform(0.60, 4.00)
```

Do **not** reuse REACT’s 1.0…3.5 s range. Endpoints are rounded to clean tenths that bracket every successful observation.

## Premature Tap Penalty

The intro says, approximately: *“Don’t tap too early — it will cost you time!”* (`¡No toques demasiado pronto - te costará tiempo!`).

**No false start occurs in this high-score run.** Score, wait state, and the top bar all evolve smoothly. There is no sudden bar jump, score drop, freeze, or warning flash that would reveal the exact penalty.

Inferred trainer policy (documented as inferred, not observed):

- Premature tap does **not** end the game.
- It subtracts a configurable time from `sessionDeadline` (default **1.5 s**, midpoint of the 1.0–2.0 s suggested range).
- The top bar shortens immediately because remaining time is `deadline - now`.
- The current wait is reset with a new random delay (simplest defensible continuation; source does not demonstrate keep-vs-reset).
- Score is unchanged.
- A touch that began during `Wait...` is classified as premature even if it is still held when the color changes. Only a **new** `touchesBegan` after the trigger can score.

## Session Timer

This is a **global session timer**, not a per-trial countdown.

Evidence:

- The bar does not refill after points 1, 2, 5, 7, 8, 10, 12, 13, 14, 16.
- Fill shrinks steadily left→right remaining width across the whole run.
- Late-game fill is a thin red sliver while score is 15–16, then the field dies.

| Recording t | Gameplay elapsed | Score | Bar fraction (visual) | Background | Wait/Tap |
| ---: | ---: | ---: | ---: | --- | --- |
| 2.367 | 0.00 | 0 | ~1.00 green | teal | Wait |
| 4.50 | 2.13 | 1 | high green | cyan | Wait + 218 ms |
| 7.50 | 5.13 | 2 | ~0.80 green | blue | Wait |
| 11.50 | 9.13 | 3 | high green | yellow / purple | Tap / Wait |
| 14.50 | 12.13 | 6 | ~0.60 green | purple | Wait |
| 17.50 | 15.13 | 8 | ~0.50–0.60 green | teal | Wait + 237 ms |
| 27.50 | 25.13 | 10 | ~0.35–0.40 orange | purple | Tap |
| 30.50 | 28.13 | 12 | mid-low | yellow | Wait |
| 33.50 | 31.13 | 13 | ~0.20–0.25 red | orange | Wait |
| 37.50 | 35.13 | 14 | ~0.15–0.20 red | purple | Wait |
| 39.50 | 37.13 | 15 | sliver red | teal | Wait + 214 ms |
| 41.50 | 39.13 | 16 | nearly empty red | purple | Wait |
| 43.50 | 41.13 | 16 | sliver | cyan | Tap |
| 43.80 | 41.43 | 16 | gone | dark | game over |

Least-squares intuition from late-game remaining slivers and the hard end at 43.80 s: duration ≈ **41.4 s**. Early visual “80% at 5 s” readings are softer (YouTube compression + vision estimates) and are not used as the clock.

Linearity: remaining width ≈ `1 - elapsed / duration`. No refill, no easing that survives the capture.

## Top Progress Bar

- Thin horizontal **capsule** just inside the top of the gameplay field.
- White / light outline track.
- Colored fill, **left → right remaining width**. Empty track is a darkened version of the current background.
- Fill color is **independent of the field color** and stages with remaining time:
  - green while remaining is high
  - orange / yellow around ~0.35–0.40 remaining
  - red below ~0.25 remaining
- Drain direction: right edge moves left.

Approximate full-viewport trainer ratios (YouTube chrome discarded):

| Quantity | Ratio |
| --- | ---: |
| Bar width / scene width | 0.78 |
| Bar height / scene height | 0.012 |
| Bar center Y from bottom | 0.935 |
| Corner radius | 0.50 of height (capsule) |

## Background Colors

Six strongly distinct families. Every measured trigger changed to a **different** color. After a successful tap the new color **remains** as the next `Wait...` field; the following trigger picks another color. The field does not reset to a neutral background.

Generator rule: `nextColor != currentColor`, deterministic seeded RNG.

## Transition Between Rounds

Successful tap:

1. Score increments immediately.
2. Text returns to `Wait...` on the **same** (just-tapped) color.
3. Last reaction (`218 ms`) appears in the lower area and persists into the next wait.
4. Next random delay starts immediately. No long lockout.
5. Session clock keeps running.

## Difficulty Progression

Delays in scores 0–5, 6–10, and 11–16 all contain both short (~0.6–0.8 s) and long (~3.5–3.8 s) waits. Later rounds are not systematically shorter or more variable. **No difficulty ramp.**

## Session End

When remaining time reaches zero:

- taps are rejected
- the active round dies
- score freezes
- shared trainer Results is shown

The 17th trigger in the recording is cut off. An already-triggered `Tap!` is **not** completable after the deadline. Compare `tapTimestamp` and `sessionDeadline` directly: `tapTimestamp <= sessionDeadline` is accepted; later is game over.

A premature penalty that would drive remaining below zero clamps to zero and emits a single `gameOver`.

## Geometry

Normalized to the trainer full-screen field (SpriteKit Y up). Source measurements are relative to the inner Playus rectangle after ignoring Shorts chrome; vertical transfer is medium confidence.

| Element | X | Y from bottom | Font / size |
| --- | ---: | ---: | --- |
| Score | 0.50 | 0.78 | ~0.155 of width, heavy |
| Prompt `Wait...` / `Tap!` | 0.50 | 0.46 | ~0.088 of width, bold |
| Reaction `218 ms` | 0.50 | 0.28 | ~0.038 of width, ~0.55 opacity |
| Session bar | 0.50 | 0.935 | width 0.78, height 0.012 |

Prompt sits in the lower-middle of the field, not optical dead-center. Score sits in the upper third under the bar.

## High-Confidence Findings

- Timed score-attack, not a fixed trial-count reaction test.
- Global session bar, left-to-right remaining, no per-point refill.
- `Wait...` → color change + `Tap!` is the stimulus.
- +1 per valid reaction; 16 is the demonstrated session score.
- Reaction milliseconds are real in-game feedback and persist into the next wait.
- Current color remains after a hit; next trigger is a different color.
- Session lasts ~41.4 s in this recording, not the intro chip’s ~27 s.
- PLAY starts waiting immediately.
- Primary result is integer points, higher is better.

## Ambiguities

- Exact premature-tap penalty amount: **unobserved**. Default 1.5 s, configurable.
- Whether a false start keeps the same scheduled trigger or resamples: **unobserved**. Trainer resamples.
- Exact wait-distribution endpoints: 16 samples. Uniform 0.60…4.00 is the least complex fit.
- First-frame bar looking slightly under 100% may be capture / outline inset, not a designed head start.
- Social results chrome (`14 Puntos` vs `16 PUNTOS`) is ignored.
- Bar stage cutovers are visual, not pixel-fitted.

## Frame Measurements

Gameplay start: **2.367 s** (first teal gameplay frame).  
Gameplay end: **43.767–43.800 s** (cyan flash then dark / results).  
Measured duration: **41.40 s**.

Color-change onsets at 30 fps are listed in **Random Delay**. 15 fps and 30 fps agree on the same 16 successful triggers plus one truncated 17th.

## Proposed Configuration

```
sessionDuration          = 41.0 s     // clean nominal; measured 41.40 s
minWait                  = 0.60 s
maxWait                  = 4.00 s
prematurePenalty         = 1.50 s     // inferred
prematureResetsWait      = true       // inferred
requiresTapToStart       = false
reactionFeedbackPersists = true
bar green above          = 0.42 remaining
bar orange above         = 0.25 remaining
else red
nextColor != currentColor
seeded RNG
```

The intro `Duración ~27s` chip is a typical-run / marketing estimate, the same class of mismatch as SWIPE FAST’s `~13s` chip versus a 23.6 s high-score run. The shrinking bar and the 2.367→43.80 gameplay window are the clock.
