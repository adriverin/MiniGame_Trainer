# Center Hit Reference Analysis

## Objective

Train visual prediction and tap timing by asking the player to tap while a continuously bouncing vertical indicator is at the exact center of a horizontal bar. Five taps are scored; speed increases after each tap; the session score is the arithmetic mean of the five tap precisions.

The supplied 1180 × 2556 screen recording is 17.786 seconds long and contains YouTube Shorts chrome around the game. Measurements below use only the game image. The encoded stream contains 764 frames with variable frame presentation: animation frames are commonly duplicated, and there is one conspicuous source hold around 2.51–2.68 s. That hold is treated as capture/playback stutter rather than game reversal behavior because later edge reversals do not pause.

## Bar Geometry

During stable gameplay frames, the game viewport is approximately 1040 px wide (x = 70...1109 in the recording). The capsule bar is x = 174...1005, approximately 832 px wide, and y = 1257...1463, approximately 207 px high. Its center is approximately (589.5, 1360), its width is 80.0% of the game viewport, and its height is 24.9% of its width. The ends are semicircular, so the effective corner radius is one half of the bar height.

## Zone Geometry

The bar contains seven, not eight, visible sections:

| Zone | Measured x range | Width | Fraction of bar |
| --- | ---: | ---: | ---: |
| Left red | 174...276 | 103 px | 12.4% |
| Left orange | 277...380 | 104 px | 12.5% |
| Left yellow | 381...506 | 126 px | 15.1% |
| Green center | 507...674 | 168 px | 20.2% |
| Right yellow | 675...799 | 125 px | 15.0% |
| Right orange | 800...900 | 101 px | 12.1% |
| Right red | 901...1005 | 105 px | 12.6% |

Compression and antialiasing make individual boundaries uncertain by roughly 1–2 px. A symmetric 12.5/12.5/15/20/15/12.5/12.5 percent partition is the best-supported reconstruction.

## Indicator Geometry

The moving indicator is a bright white vertical capsule approximately 13 px wide. Its visible height is approximately 249 px, about 1.20 times the bar height, and it extends roughly 21 px above and below the bar. Measurements track its center, not an edge.

## Center Marker

The static target is distinct from the moving indicator. It consists of a thin white line at x ≈ 589.5, approximately 5 px wide and confined to the bar, plus a small dark-green linked-circle/target ornament around the exact center. The collision/scoring origin is the mathematical center of the bar. The trainer should preserve the thin fixed line and a subtle center ornament without treating the ornament as a separate scoring region.

## Initial State

The gameplay bar first becomes measurable at about 1.913 s. The moving line is at the center (x ≈ 591) and already moving right. There is no visible countdown or first-tap-to-start interaction in the gameplay footage. The initial configuration therefore starts automatically at center, moving right.

## Movement

Motion is constant-velocity within each attempt. The recording supports five explicit normalized speed levels rather than one reliably inferred additive or multiplicative curve. Recommended calibrated levels are 0.94, 1.44, 1.90, 2.30, and 3.00 bar widths per second.

### Movement

| Attempt | Time interval | Distance traveled | Speed | Traversal period |
| --- | --- | ---: | ---: | ---: |
| 1 | 2.762–3.312 s, right edge toward center | ≈425 px | ≈773 px/s (0.93 widths/s) | ≈1.08 s |
| 2 | 3.653–4.350 s, left edge to right edge | ≈831 px | ≈1,192 px/s (1.43 widths/s) | ≈0.70 s |
| 3 | 4.950–5.475 s, left edge to right edge | ≈831 px | ≈1,583 px/s (1.90 widths/s) | ≈0.53 s |
| 4 | 6.990–7.430 s, left edge to right edge | ≈831 px | ≈1,889 px/s (2.27 widths/s) | ≈0.44 s |
| 5 | 9.485–9.818 s, left edge to right edge | ≈827 px | ≈2,483 px/s (2.98 widths/s) | ≈0.34 s |

The proposed normalized defaults round these noisy source measurements and scale naturally with device width.

## Boundary Reversal

Later edge observations show immediate reversal with no easing or deliberate pause. The implementation should reflect overshoot rather than clamp and discard it. For path bounds `left` and `right`, distance is folded into a triangular wave with period `2 × (right - left)`, preserving all traveled distance even across multiple boundaries.

## Input

The reference provides no evidence that a tap must land on the bar. There is no touch cursor or localized hit affordance. Any single touch in the gameplay scene should score one attempt. Multi-touch must not create multiple attempts.

## Attempt Flow

The line continues from its current position and direction after every tap. The new speed applies immediately. There is no reset, direction change, movement pause, or feedback hold. The attempt label increments with the displayed precision. After the fifth tap, the reference transitions directly to its result presentation.

## Speed Progression

The measured levels are neither cleanly additive in points per second nor cleanly multiplicative. Explicit normalized presets best preserve the footage across screen sizes:

`[0.94, 1.44, 1.90, 2.30, 3.00] × bar width per second`

These are configurable DEBUG values. Relative to attempt one they are approximately `[1.00, 1.53, 2.02, 2.45, 3.19]`.

## Precision Formula

The colored sections are visual guides, not discrete score buckets: taps within the green section produce distinct values with two decimals. The best-supported continuous model is linear distance from center normalized by the half-width:

`normalizedError = abs(indicatorX - centerX) / (barWidth / 2)`

`precision = 100 × clamp(1 - normalizedError, 0...1)`

This gives 100% at exact center and 0% at either edge. It is symmetric and monotonic. The rendered frames bracket each input rather than capturing the exact touch delivery timestamp, so the video cannot prove a nonlinear exponent. The linear model is selected because its implied near-center errors agree with the bracketing frames and because half-width normalization gives a meaningful full 0...100 range.

## Per-Attempt Observations

The value is absent before tap one. After each of the first four taps, the large cyan number changes and then persists until the next tap, proving that it is the latest individual precision rather than a running average. Tap five transitions directly to the result; its individual value is not shown.

### Scoring

| Attempt | Tap frame / time | Line X | Center X | Error | Displayed score |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | frame 199 / 3.328 s | ≈581 px (last rendered center ≈579 px) | 589.5 px | ≈9 px | 97.82% |
| 2 | frame 281 / 4.693 s | ≈581 px, inferred between rendered x ≈626 and 556 | 589.5 px | ≈8 px | 97.99% |
| 3 | frame 361 / 6.790 s | ≈583 px, inferred between rendered x ≈619 and 560 | 589.5 px | ≈7 px | 98.31% |
| 4 | frame 438 / 9.352 s | ≈584 px (preceding rendered center ≈589 px) | 589.5 px | ≈6 px | 98.67% |
| 5 | frame 570 / 13.428 s | ≈576 or 604 px, inferred between rendered x ≈631 and the next center crossing | 589.5 px | ≈14 px | Not shown; ≈96.66% implied |

“Line X” for attempts 2, 3, and 5 is necessarily inferred: the touch occurs between captured animation frames and the score/attempt label appears on the following recorded frame. The inferred errors are those produced by the selected linear formula. They should not be presented as direct pixel observations.

## Final Average

The final shown result is 97.89%. The four visible individual values sum to 392.79%. If the result is the stated five-attempt arithmetic mean, the hidden fifth value is approximately 96.66%:

`(97.82 + 97.99 + 98.31 + 98.67 + 96.66) / 5 = 97.89`

Because every displayed value is rounded to two decimals, the exact internal fifth precision cannot be recovered. It should not be asserted more precisely than approximately 96.66%.

## Feedback

The latest precision appears prominently in cyan below the attempt label immediately after the scored tap and remains until replaced. No percentage is shown before the first tap. The bar continues moving behind feedback. There is no observed flash, scoring-zone recolor, sound cue, or movement pause.

## Game Duration

The instruction states approximately 10 seconds. The first scored tap appears at 3.328 s and the fifth at 13.428 s, a 10.10-second scoring interval. Gameplay becomes visible about 1.4 seconds before the first tap, so total observed active display time is somewhat longer and depends on player timing.

## High-Confidence Observations

- One horizontal capsule, seven symmetric colored zones.
- Thin fixed center line and separate taller moving line.
- Initial moving-line state is center, moving right, with automatic start.
- Continuous constant-velocity motion and instantaneous edge reflection.
- First five gameplay taps score; any-screen tap is the supported interpretation.
- Speed increases immediately after each scored tap.
- Movement continues without reset, pause, or direction change.
- Four visible percentages are latest individual attempt values.
- Final score is the five-attempt arithmetic mean, displayed to two decimals.
- Higher precision is better.

## Ambiguities

- Exact source touch timestamps are not encoded, so three tap positions lie between captured frames.
- The exact scoring curve is underdetermined; linear half-width normalization is best supported but not proven.
- Exact fifth-attempt precision is hidden and only approximately recoverable from rounded values.
- Speed estimates are affected by duplicated frames and one source hold; explicit rounded presets are preferable to false precision.
- The center ornament's exact vector shape is decorative and not relevant to score.
- No touch-location evidence exists; any gameplay-area tap is assumed.

## Video Measurements

- Recording: 1180 × 2556, 17.786 s, 764 encoded video frames.
- Effective game viewport width during gameplay: ≈1040 px.
- Bar: ≈832 × 207 px; width/viewport = 0.800; height/width = 0.249.
- Bar center: ≈(589.5, 1360) in recording coordinates.
- Capsule radius: ≈103.5 px.
- Static center line: ≈5 px wide, bar-height only.
- Moving indicator: ≈13 px wide, ≈249 px high, ≈1.20 bar heights.
- Zone fractions: 0.125 / 0.125 / 0.15 / 0.20 / 0.15 / 0.125 / 0.125.

## Initial Configuration

- Attempts: 5.
- Bar width ratio: 0.80 of scene width.
- Bar height ratio: 0.25 of bar width.
- Bar center: x = scene center; y = 0.264 of scene height in SpriteKit bottom-origin coordinates.
- Zone fractions: `[0.125, 0.125, 0.15, 0.20, 0.15, 0.125, 0.125]`.
- Moving indicator width: 0.0156 of bar width (about 13/832).
- Moving indicator height: 1.20 bar heights.
- Fixed center line width: 0.006 of bar width (about 5/832).
- Initial position: exact center.
- Initial direction: right.
- Start: automatic, no countdown.
- Speed levels: `[0.94, 1.44, 1.90, 2.30, 3.00]` bar widths/second.
- Scoring: `100 × clamp(1 - abs(error)/(barWidth/2), 0...1)`.
- Feedback: latest attempt, two decimals, persistent until next attempt.
- End hold: short enough to feel immediate; trainer default 0.35 s for readable fifth-tap feedback before shared Results.
