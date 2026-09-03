# Tap Seven Reference Analysis

Source recording: `ScreenRecording_09-03-2026 14-03-56_1.MP4` (HEVC, 1180×2556, 60.07 fps, 43.665 s, 2624 frames). The file is an iPhone screen recording of a YouTube Short of Playus “On Time!”. YouTube chrome, avatars, social overlays, and the source title are not part of the trainer. Trainer name: **TAP AT 7**.

This is not TIME'S UP. The elapsed number and circular progress stay visible for the whole attempt. The target is an explicit 7.00 s timestamp, not a hidden interval.

## Objective

Tap once as close as possible to **exactly 7.000 seconds** after the attempt clock starts. The visible timer counts up. A turquoise ring fills clockwise and completes at 7 s. The score is the absolute timing error. Lower is better.

## Start Flow

| Event | Recording time | Evidence |
| --- | ---: | --- |
| YouTube / Playus game list | 0.00–1.20 s | Feed and “Todos los juegos” |
| Ready screen | ~1.35 s | Empty dark ring, dim `0.00`, copy `Toca para empezar, luego en 7s`, gray circular button below the ring |
| First attempt clock start | ~1.32–1.56 s | Frame at 1.50 s already shows `0.18` and `TOCA EN 7` |
| First tap / in-game result | ~8.65–8.70 s | `7.00` + `Resultado exacto: 6.9998` + `PERFECTO` |
| GAME OVER modal | ~9.5–11.2 s | `JUEGO TERMINADO` / `HAS PUNTUADO` / `0,00 Segundos` |
| Ready screen again | ~11.5 s | Same start cue as the first play |
| Second attempt running | 12.5 s | `1.00` |
| Second result | ~19.2 s | `Resultado exacto: 7.0009` / `POR 0.0009s` |
| Third and fourth plays | 22–43 s | Same ready → one tap → result → GAME OVER loop |

There is **no 3-2-1 countdown**. Timing does not begin when the game screen appears. The first tap on the ready screen starts the clock. That start tap is not scored. The timing tap is a later, separate touch.

Trainer mapping: intro PLAY lands on **ready**. The ready tap, captured with `CACurrentMediaTime()`, is `startTimestamp`. DEBUG can skip the ready cue.

## Timer

- Counts **up** from `0.00`.
- Stays visible for the whole attempt, including after 7.00 on the result freeze.
- Display uses **two decimal places**: `0.18`, `1.32`, `1.95`, `2.15`, `4.16`, `5.43`, `6.18`, `6.52`, `6.78`, `6.94`, `7.00`.
- Result overlay also shows a four-decimal raw elapsed (`6.9998`, `7.0007`, `7.0009`).
- Display rounding never feeds scoring.

## Circular Progress

- Dark gray incomplete track.
- Bright turquoise completed arc.
- Thick circular stroke.
- Starts at 12 o’clock.
- Fills **clockwise**.
- Reaches a full circle at 7.00 s.
- Linear in the recording: displayed `1.95` ≈ 28% fill (`1.95 / 7 = 0.279`); `5.43` ≈ 77%; `6.94` is a 1–2° gap at the top.

## Input

Any single tap after the clock has started submits the attempt, including taps before 7 s. Multi-touch cannot submit twice. After submit, further gameplay taps are ignored until a new play starts.

The ready-state gray circle is a visual affordance. The recording does not prove it is the only hit target; the trainer accepts a tap anywhere on the scene.

## Target Time

Canonical target: **7.000 seconds**.

Do not use 6.9998 or other frame-derived values as the target. Those are tap results against 7.000.

Configuration: `targetDuration = 7.0`.

## Result Calculation

```
elapsed = tapTimestamp - startTimestamp
signedError = elapsed - targetDuration
absoluteError = abs(signedError)
```

Negative = early, positive = late. Primary score is `absoluteError`. GAME OVER shows that error rounded to two decimal places (`0,00 Segundos`), not the four-decimal raw elapsed.

## Perfect Threshold

A visible center value of `7.00` is **not** PERFECT by itself. Every recorded finish displayed `7.00` at two decimals.

| Play | Raw elapsed | Abs error | Classification |
| ---: | ---: | ---: | --- |
| 1 | 6.9998 | 0.0002 s | `PERFECTO` |
| 2 | 7.0009 | 0.0009 s | `POR 0.0009s` (not perfect) |
| 3 | 7.0007 | 0.0007 s | `POR 0.0007s` (not perfect) |

So PERFECT is a tolerance, not exact float zero and not “rounds to 7.00”.

Evidence bounds the threshold to **(0.0002, 0.0007]**. Default: `perfectThreshold = 0.0005` (0.5 ms). That is also the window whose three-decimal rounding equals `7.000`.

```
isPerfect = abs(signedError) < perfectThreshold
```

Just inside 0.0005 → PERFECT. 0.0005 on the boundary is not PERFECT (`<`). 0.0007 and 0.0009 are not PERFECT.

## Early / Late Behavior

Early taps are valid. The first recorded finish is 0.2 ms early and scores. Late taps are valid: 0.7 ms and 0.9 ms late both score with `POR …s` instead of PERFECT. The recording never shows a large miss (0.25 s early/late), but the rule is the same absolute-error formula.

Direction is optional on the trainer results metrics (`0.04 s early` / `0.04 s late`). It does not replace the primary absolute score.

## Session Structure

**One timing attempt per game.**

The recording contains four separate plays because the player dismisses GAME OVER and starts again. Pattern:

1. ready
2. one timing attempt
3. in-game result on the ring
4. GAME OVER modal with one score
5. new play

There is no in-session average of several taps. `attemptCount = 1`.

## Score / Persistence

- Primary score: absolute error in seconds, **lower is better**.
- GAME OVER display: two decimal places (`0,00 Segundos`).
- In-game detail: four decimal places.
- Trainer persistence: integer milliseconds (`0.0376 s` → `38`). Same `ScorePresentation` scale as TIME'S UP (`storageScale = 1000`, two displayed fraction digits).
- `0.00 s` / stored `0` is a valid personal best. Do not treat integer zero as “no score yet”.

## Geometry

Measured on a 10 fps 295×639 decode (¼ of 1180×2556), using the white timer glyph cluster as the ring center.

| Quantity | Measurement | Ratio used |
| --- | ---: | --- |
| Ring center X | 147–154 / 295 | `ringCenterXRatio = 0.50` |
| Ring center Y | ~313 from top; 0.51 from bottom | `ringCenterYRatio = 0.51` |
| Centerline diameter | ~174 px / 295 | `ringDiameterRatio = 0.59` of scene width |
| Stroke width | ~18–21 px / 295 | `ringStrokeRatio = 0.064` of scene width |
| Start angle | 12 o’clock | `-π/2` in SpriteKit / standard polar |
| Direction | clockwise | `clockwise: true` from top |
| Instruction | below the ring, ~0.30 from bottom | `instructionYRatio = 0.30` |
| Timer font | fills most of the inner disk | `timerFontSizeRatio = 0.20` of width |
| Start button | gray circle under the ring, ready only | `startButtonDiameterRatio = 0.18` |

YouTube right-side icons overlay the Short. Ratios are of the Shorts frame, not a chrome-stripped crop. Human calibration of diameter / Y remains expected.

## High-Confidence Findings

- Target is 7.000 s. Timer counts up and remains visible.
- Ring fill is linear `elapsed / 7`, clockwise from the top, full at 7 s.
- One attempt, then a result, then a separate restarted play.
- Ready tap starts the clock; a later tap submits.
- PERFECT is a sub-millisecond window, not two-decimal `7.00`.
- GAME OVER score is absolute error at two decimals. `0,00` appeared for 0.0002, 0.0007, and 0.0009 s errors.
- No metronome, tick sounds, or periodic haptics in the recording.

## Ambiguities

- Exact PERFECT cutoff is not unique: any value in (0.0002, 0.0007] fits the three labelled finishes. Default 0.0005 s is documented as an inference.
- Behavior after 7.00 if the player does not tap is **not in the recording**. Every play taps within ~1 ms of 7. Trainer keeps the ring full, keeps counting, and still accepts a late tap until a trainer-specific safety timeout (`maxAttemptDuration = 15 s`). That timeout is not from the source.
- Whether the gray ready button is the only hit target.
- Whether GAME OVER `0,00` is `round(absError, 2)` or `floor`. All samples are < 0.005 s so both would show `0,00`. Trainer uses standard millisecond rounding of the raw error, then two-decimal display of that stored value.
- Exact native font and stroke compared with Shorts compression / ¼-res decode.

## Frame Measurements

Times are seconds in the recording. “Displayed timer” is the on-screen two-decimal value. Ring % is `displayed / 7` unless a polar measurement is noted.

| Timestamp | Displayed timer | Ring completion | Target / instruction state |
| ---: | --- | ---: | --- |
| 1.00 | — | — | Playus list / “On Time!” card |
| 1.40 | 0.00 (dim) | 0% | Ready: “Toca para empezar, luego en 7s” |
| 1.50 | 0.18 | ~3% | `TOCA EN 7`, timing |
| 2.00 | 0.68 | ~10% | Timing |
| 3.50 | 1.95 | ~28% (polar ~28%) | Timing |
| 5.50 | 4.16 | ~59% | Timing |
| 7.00 | 5.43 | ~78% (polar ~76%) | Timing |
| 8.00 | ~6.4 | ~91% | Timing |
| 8.50 | 6.94 | ~99%, tiny top gap | Still `TOCA EN 7` |
| 8.70 | 7.00 | 100% | `Resultado exacto: 6.9998` / `PERFECTO` |
| 11.50 | 0.00 | 0% | Ready again (new play) |
| 12.50 | 1.00 | ~14% | Timing, play 2 |
| 19.20 | 7.00 | 100% | `7.0009` / `POR 0.0009s` |
| 23.50 | 1.31 | ~19% | Timing, play 3 |
| 29.20 | 6.78 | ~97% | Timing |
| 29.50 | 7.00 | 100% | `7.0007` / `POR 0.0007s` |
| 39.50 | 6.52 | ~93% | Timing, play 4 |

## Proposed Configuration

```
attemptCount = 1
targetDuration = 7.0
perfectThreshold = 0.0005
maxAttemptDuration = 15.0          // trainer safety timeout; not from source
requiresTapToStart = true
ringDiameterRatio = 0.59
ringStrokeRatio = 0.064
ringCenterXRatio = 0.50
ringCenterYRatio = 0.51
instructionYRatio = 0.30
timerFontSizeRatio = 0.20
progress = clamp(elapsed / targetDuration, 0, 1)
```
