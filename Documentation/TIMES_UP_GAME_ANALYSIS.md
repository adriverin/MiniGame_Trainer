# TIME'S UP Reference Analysis

Source recording: `ScreenRecording_09-03-2026 12-33-57_1.MP4` (HEVC, 1180×2556, 60 fps, 42.32 s, 2544 frames). The file is an iPhone screen recording of a YouTube Short of Playus “Time’s Up”. YouTube chrome, avatars, and social overlays are not part of the trainer.

## Objective

Train **internal time estimation**. A vertical progress bar drains linearly from full. Halfway through the target interval the bar disappears. The player taps when they believe the original interval has ended. The score is the mean absolute timing error. Lower is better.

This is not a reaction game. The visible half of the bar is a calibration cue; the hidden half is the test.

## Number of Levels

Three levels, labelled `NIVEL 1 DE 3`, `NIVEL 2 DE 3`, then `RESULTADOS FINALES`. Configuration default: `levelCount = 3`.

## Level Start Flow

| Event | Recording time |
| --- | ---: |
| Intro / Start screen | 0.00–1.38 s |
| Black/empty cut | 1.383 s |
| Level 1 full bar appears | 1.483 s |
| Level 1 feedback | 10.983 s |
| Level 2 full bar appears | 15.650 s |
| Level 2 feedback | 24.883 s |
| Level 3 full bar appears | 28.550 s |
| Final results | 37.517 s |

There is **no 3-2-1 countdown**. Tapping **Start** / **SIGUIENTE NIVEL** begins the next interval immediately. The full bar and the timer start on the same event. Later levels do not auto-start after a delay; they wait for the next-level button.

Trainer mapping: intro PLAY lands on a **Tap to start** ready state so the navigation tap cannot score. That ready tap, and each Next Level tap, start the timer immediately.

## Progress Bar Geometry

Measured on the 60 fps half-resolution decode (590×1278), then converted to ratios of the Shorts frame. YouTube right-side icons overlay the game; the bar is still horizontally centered in the video.

| Quantity | Measurement | Ratio used |
| --- | ---: | ---: |
| Bar width | 153 px at half-res (306 px native) | `barWidthRatio = 0.26` of scene width |
| Bar height | 415 px at half-res (830 px native) | `barHeightRatio = 0.40` of scene height |
| Center X | 294.5 / 590 | `barCenterXRatio = 0.50` |
| Center Y | ~0.42 from the scene bottom after excluding Shorts chrome | `barCenterYRatio = 0.42` |
| Shape | Vertical stadium / rounded rectangle | `cornerRadiusRatio = 0.50` of width |
| Fill | Cyan at the top → mid blue at the bottom, vertical gradient | original gradient, not a copied asset |
| Container | Dark translucent rounded track behind the fill | hidden with the fill |
| Drain direction | Top edge moves down; bottom stays planted | fill anchored at the bottom |

Instruction copy sits in the upper third and remains after the bar vanishes: reference `TOCA CUANDO TERMINES`. Trainer copy: `TAP WHEN YOU THINK IT ENDS`.

## Progress Bar Drain

During the stable phase the bottom of the fill is fixed and the height falls linearly. Least-squares fits on that phase:

| Level | Samples | h(t) slope (half-res px/s) | Extrapolated empty |
| --- | ---: | ---: | ---: |
| 1 | 220 | −42.51 | 9.95 s after start |
| 2 | 210 | −43.66 | 9.67 s after start |
| 3 | 204 | −44.91 | 9.39 s after start |

No easing is visible in the stable phase. Progress is `1 - elapsed / targetDuration`. The modest steepening across levels is treated as capture/compression noise, not a designed speed ramp.

## Disappearance Point

The instruction says the bar disappears halfway. Default: `visibilityFraction = 0.5`.

In the recording, cyan fill collapse begins around 37% of the drain-to-empty time (remaining height ≈ 243–252 / 415 ≈ 59%) and the fill is gone ~0.7–0.85 s later. After that, scene mean keeps falling for ~1.5 s, consistent with the dark track fading or with Shorts UI / compression. Linear 50% height would have occurred ~4.88 / 4.75 / 4.62 s after each start — slightly after the fill is already undetectable.

**Interpretation:** the designed rule is a 50% time cutoff. The early visual collapse is not a clean 50% fill frame; YouTube occlusion, a short fade, and detection threshold all contribute. The trainer hides the **entire** bar (fill and track) instantly when `elapsed >= targetDuration × visibilityFraction`. Fade duration is a DEBUG control defaulting to 0.

After disappearance the screen is static: instruction text, dark background, no pulse, no tick, no haptic cadence.

## Target Duration Per Level

Do not use `[5, 5, 5]` from intuition. The strongest clock is the linear drain extrapolated to empty, which clusters near **10 seconds** on every level.

The intro chip `Duración ~22s` would better match three ~5 s intervals plus transitions. That reading is kept as an ambiguity: it may be a Playus estimate, a different build, or a Shorts playback-rate question. Drain geometry is preferred over the marketing duration chip.

Default model: **fixed sequence** `[10, 10, 10]`. Not randomized. Not an increasing-speed curve. Difficulty is the hidden-interval task itself.

## Input Timing

Any single tap after the level has started submits the estimate, including taps before disappearance. Multi-touch cannot submit twice. After a score, further gameplay taps are ignored until the next level starts.

## Early vs Late Feedback

| Level | On-screen value | Direction copy | Sign |
| --- | --- | --- | --- |
| 1 | `+0.01s` | `¡Demasiado tarde!` | plus prefix = late |
| 2 | `0.03s` | `¡Demasiado pronto!` | no plus = early (absolute value) |
| 3 | `0.16s` | none on the final list | no plus, so treated as early |

Trainer English copy:

- Late: `You missed by...` / `+0.01s` / `Too late!`
- Early: `You missed by...` / `0.03s` / `Too early!`
- Exact: `0.00s` / `Exact!`

## Error Calculation

```
signedError = actualElapsed - targetDuration
absoluteError = abs(signedError)
```

Negative = early, positive = late. Stored as `TimeInterval` (Double). Display rounding never feeds back into the average.

## Final Average Calculation

Displayed list: `+0.01s`, `0.03s`, `0.16s`. Displayed average: `0.06s`.

`(0.01 + 0.03 + 0.16) / 3 = 0.0666…` which standard two-decimal rounding of the **already rounded** values would show as `0.07s`.

**Conclusion (high confidence in the rule, medium confidence in the exact raw triple):** the average is computed from higher-precision internal errors, then formatted to two decimals. Example: `0.008 + 0.025 + 0.155 = 0.188`, mean `0.0627` → `0.06s`, while the per-level labels still round to `0.01` / `0.03` / `0.16`.

The implementation does **not** truncate. It averages raw `TimeInterval`s, persists milliseconds with `rounded()`, and formats seconds to two decimals.

## Level Transition

Feedback stays on screen until **Next Level**. The next timer does not run during reading time. Level 3 uses a Results button and then the shared results screen.

## Results

In-game final list plus `AVERAGE 0.06s`. Playus then shows a social game-over / leaderboard (`JUEGO TERMINADO 0,06 SEGUNDOS`, modal `HAS PUNTUADO 0,02 Segundos`). The `0,02` header chip is a social/best UI, not the session average. The trainer uses the shared Results screen with average error as the primary lower-is-better score.

## High-Confidence Observations

- Three discrete levels, button-gated, no countdown.
- Vertical cyan→blue stadium bar, drain from the top, linear while visible.
- Instruction text remains after the bar is gone.
- Late uses a `+` prefix; early shows the absolute value.
- Primary score is mean **absolute** error; lower is better; `0.00s` is a legitimate perfect score.
- Start of the bar and start of the clock are the same event.

## Ambiguities

- Exact per-level target: drain implies ~10 s; intro chip implies ~22 s session (~5 s/level). Default 10 s, exposed in DEBUG.
- Disappearance is not a single clean 50% fill frame in this Shorts capture.
- Level 3 direction is inferred from missing `+`; there is no “too early/late” line on the final list.
- Feedback-frame times are not millisecond-accurate tap times (animation, 60 fps, YouTube re-encode). Do not reconstruct 0.01 s errors from those timestamps.
- Early-tap-before-disappearance is not demonstrated; trainer accepts the tap.
- Fade versus instant hide: capture shows a collapse; trainer defaults to instant hide.

## Video Measurements

Times are seconds in the recording. “Tap” is the first frame of the feedback / results UI, not a proven touch timestamp. Inferred duration from the displayed error uses `target = tapElapsed - signedError` with Level 3 signed as early (`−0.16`).

| Level | Start | Halfway / disappearance | Tap (UI) | Displayed signed error | Inferred target (tap) | Drain-to-empty |
| ---: | ---: | --- | ---: | --- | ---: | ---: |
| 1 | 1.483 | fade 5.150–6.00; linear 50% height at 6.365 | 10.983 | +0.01 s late | 9.49 s | 9.95 s |
| 2 | 15.650 | fade 19.150–19.85; linear 50% height at 20.403 | 24.883 | 0.03 s early | 9.26 s | 9.67 s |
| 3 | 28.550 | fade 31.950–32.62; linear 50% height at 33.170 | 37.517 | 0.16 s early (inferred) | 9.13 s | 9.39 s |

The ~0.4–0.5 s gap between drain-to-empty and tap-inferred duration is attributed to UI delay and capture, not to a second duration model.

## Initial Configuration

```
levelCount = 3
targetDurations = [10, 10, 10]
visibilityFraction = 0.5
barWidthRatio = 0.26
barHeightRatio = 0.40
barCenterXRatio = 0.50
barCenterYRatio = 0.42
cornerRadiusRatio = 0.50
instructionYRatio = 0.76
requiresTapToStart = true
disappearFadeDuration = 0
score unit = milliseconds of mean absolute error
display = seconds with two fraction digits
comparison = lower is better
```
