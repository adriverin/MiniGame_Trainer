# Direction Sequence Reference Analysis

Source recording: `ScreenRecording_09-03-2026 13-27-53_1.MP4` (HEVC, 1180×2556, 60.09 fps, 182.67 s, 10978 frames). The file is an iPhone screen recording of a YouTube Short of Playus “Memorizer”. YouTube chrome, avatars, rankings, and social overlays are not part of the trainer.

## Objective

Train **directional working memory**. The game shows one large arrow at a time. After the sequence ends, the player reproduces it on a four-button D-pad. Higher integer score is better.

## Round Flow

Each round alternates:

1. **OBSERVE** (`Observa` in the recording) — large central arrow, no buttons.
2. Brief blank / transition.
3. **YOUR TURN** (`Tu turno`) — D-pad appears; player taps the sequence in order.
4. On a full correct sequence: green `¡Correcto!` / **CORRECT**, then the next OBSERVE at `LEVEL N+1`.

The recording opens on a YouTube gallery, then cuts into **level 1 already in YOUR TURN**. Level 1 OBSERVE is off-camera. From level 2 onward both phases are visible through level 12.

## Presentation Phase

- One cream/off-white arrowhead, rotated to up / right / down / left.
- Label: `Observa` (trainer: `OBSERVE`).
- Score top-left, `Nv. N` top-right (trainer: `LEVEL N`).
- No D-pad, no sequence row.

## Recall Phase

- Large arrow gone.
- Four cream rounded-square buttons in a cross, dark triangle glyphs.
- Label: `Tu turno` (trainer: `YOUR TURN`).
- Small white arrowheads accumulate under the label as the player taps. These are **player inputs**, not the hidden target.

## Direction Controls

Supported set: **up, right, down, left**. Cross layout:

```
        UP
LEFT          RIGHT
       DOWN
```

Buttons are independent rounded squares with a visible gap. Touch region matches the visible tile plus ~6% padding.

## Sequence Length

Measured from per-round score deltas (`+1` per correct tap) and from the input row at late levels:

| Level | Sequence length |
| ---: | ---: |
| 1 | 3 |
| 2 | 4 |
| 3 | 5 |
| 4 | 6 |
| 5 | 7 |
| 6 | 8 |
| 7 | 9 |
| 8 | 10 |
| 9 | 11 |
| 10 | 12 |
| 11 | 13 |
| 12 | 14 |

Rule: **`length = level + 2`**. This is schedule **A** (increases by one every level). It is not randomized and does not depend on score except through the level index.

The recording does not cap through level 12. The trainer caps at 16 from level 14 so auto-play / unbounded sessions stay safe. Cap is configurable.

## Sequence Generation

Rounds are **independent**, not Simon-style cumulative.

Evidence: level 9 prefix `RIGHT UP RIGHT RIGHT DOWN DOWN` vs level 10 prefix `LEFT LEFT LEFT LEFT` — the later sequence is not the previous sequence plus one item.

Consecutive repeats **are allowed** (level 9 `RIGHT RIGHT`, `DOWN DOWN`; level 10 four `LEFT`s). Opposite consecutive pairs also appear.

Generator: uniform over the four `Direction` cases, seeded SplitMix64 in tests / DEBUG.

## Presentation Timing

Arrow-on / gap oscillation in the 60 fps decode (early analysis) and total OBSERVE windows:

| Level | OBSERVE window (s) | Length | Window / item |
| ---: | ---: | ---: | ---: |
| 2 | 5.92–9.45 (3.53) | 4 | 0.88 |
| 3 | 11.37–15.81 (4.44) | 5 | 0.89 |
| 6 | 39.52–46.54 (7.02) | 8 | 0.88 |
| 8 | 68.49–77.31 (8.82) | 10 | 0.88 |
| 9 | 84.54–94.19 (9.65) | 11 | 0.88 |
| 12 | 157.34–169.69 (12.35) | 14 | 0.88 |

Per-item time is **constant**. Late levels are harder because they are longer, not faster.

Defaults:

- `arrowOnDuration = 0.600 s` (~36 frames)
- `interArrowGap = 0.266 s` (~16 frames)
- `transitionToRecallDuration = 0.350 s`

`total = N × 0.600 + (N − 1) × 0.266 + 0.350`

Arrow transitions are **not** instantaneous: there is a blank interval between arrows.

## Recall Timing

No countdown, progress bar, or inactivity fail is visible. Recall duration is player-paced (about 1.8 s for four taps at level 2; ~11–16 s at levels 10–12). Trainer does not invent a timer.

## Input Feedback

Correct tap:

- Score increments **immediately** (`12 → 13` on the first level-4 tap; `42 → 44` after two level-8 taps).
- A matching white arrowhead is appended to the YOUR TURN row.
- No strong button recolor is required (finger occlusion dominates the recording).
- Completion flash: green `¡Correcto!` (trainer: `CORRECT`).

Do not add extra metronome sounds. Shared tap haptic/audio on accept matches other trainer games.

## Correct Answer

Full ordered match of `[Direction]`. After the last correct tap the round is complete exactly once, then a ~0.72 s CORRECT hold before the next OBSERVE.

## Wrong Answer

The recording is a clean run through level 12. Failure, lives, and timeout are **not observed**. Smallest architecture-consistent choice: **first wrong direction ends the run**. Configurable via `failsOnFirstWrongInput`. No life system.

## Scoring

**+1 per correct direction press**, not a bulk round bonus.

Completed-round totals from the recording:

| After level | Score | Delta | Length |
| ---: | ---: | ---: | ---: |
| 1 | 3 | +3 | 3 |
| 2 | 7 | +4 | 4 |
| 3 | 12 | +5 | 5 |
| 4 | 18 | +6 | 6 |
| 5 | 25 | +7 | 7 |
| 6 | 33 | +8 | 8 |
| 7 | 42 | +9 | 9 |
| 8 | 52 | +10 | 10 |
| 9 | 63 | +11 | 11 |
| 10 | 75 | +12 | 12 |
| 11 | 88 | +13 | 13 |
| 12 in progress | 100 at 12/14 taps | +12 so far | 14 |

User-sampled intermediates `5, 8, 20, 29, 65, 80` sit on this per-tap staircase. Level 12 opens at score **88**.

Wrong tap adds nothing.

## Level Progression

One successful full sequence → `level + 1`. Level 1 starts at score 0. The HUD uses `Nv. N`; trainer copy is `LEVEL N`.

## Difficulty Progression

Only sequence length grows. Presentation speed is flat. No extra distractors, no timer squeeze.

## Session End

Not shown. Trainer ends on the first wrong input, then the shared results screen. The Short ends during level 12 recall at score 100.

## Geometry

Normalized to the game scene (SpriteKit Y up). YouTube chrome excluded.

| Element | Ratio |
| --- | ---: |
| Score | x 0.085, y 0.905, font 0.145 × width |
| Level | x 0.915, y 0.905, font 0.048 × width |
| OBSERVE / YOUR TURN | x 0.085, y 0.825, font 0.055 × width |
| Sequence row | y 0.745, left-aligned under the phase label |
| Observe arrow center | (0.50, 0.47) |
| Observe arrow | width 0.28, height 0.21 |
| D-pad center | (0.50, 0.385) |
| Button size | 0.21 × width |
| Button gap | 0.042 × width |
| Corner radius | 0.22 × button |
| Inner glyph | 0.42 × button |

Background: original bright blue `RGB(46, 138, 230)`. Arrow: cream `RGB(246, 242, 228)`. Buttons: cream `RGB(244, 241, 232)` with dark glyphs. One vector arrowhead, rotated.

## High-Confidence Findings

- Independent sequences each round, not Simon cumulative.
- Consecutive repeats allowed.
- `length = level + 2`.
- Score `+1` per correct tap, immediately.
- YOUR TURN row shows **player inputs only**.
- Presentation speed is constant; length is the difficulty.
- Four-direction D-pad; OBSERVE hides it.
- Prefix errors are not shown; first-wrong fail is the adopted rule.

## Ambiguities

- Level 1 OBSERVE is off-camera; length 3 is inferred from the 0→3 score step.
- Exact arrow-on / gap split has ±1–2 frames of compression noise; totals are stable.
- Failure / lives / timeout never appear. First-wrong end is documented, not observed.
- Button pressed-state tint is occluded.
- Whether score should rewind on interruption is not shown; trainer rewinds the in-flight round so taps cannot double-count.
- Sequence-length cap beyond level 12 is not in the source.

## Frame Measurements

| Level | Sequence (observed prefix / notes) | Length | Arrow-on | Gap | Recall window (s) | Score before | Score after | Delta | Result |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | off-camera OBSERVE; recall from 4.26 | 3 | 0.600 | 0.266 | 4.26–5.89 | 0 | 3 | +3 | correct |
| 2 | LEFT … (4 items) | 4 | 0.600 | 0.266 | 9.50–11.35 | 3 | 7 | +4 | correct |
| 3 | UP then DOWN among 5 | 5 | 0.600 | 0.266 | 15.83–18.64 | 7 | 12 | +5 | correct |
| 4 | first tap UP, score 12→13 | 6 | 0.600 | 0.266 | 23.96–28.34 | 12 | 18 | +6 | correct |
| 5 | OBSERVE 29.15–35.26 | 7 | 0.600 | 0.266 | 35.30–39.47 | 18 | 25 | +7 | correct |
| 6 | UP LEFT DOWN UP … | 8 | 0.600 | 0.266 | 46.56–52.22 | 25 | 33 | +8 | correct |
| 7 | OBSERVE 52.24–60.12 | 9 | 0.600 | 0.266 | 60.16–68.44 | 33 | 42 | +9 | correct |
| 8 | DOWN LEFT … | 10 | 0.600 | 0.266 | 77.33–84.52 | 42 | 52 | +10 | correct |
| 9 | R U R R D D … | 11 | 0.600 | 0.266 | 94.24–105.65 | 52 | 63 | +11 | correct |
| 10 | LEFT LEFT LEFT LEFT … | 12 | 0.600 | 0.266 | 117.27–133.64 | 63 | 75 | +12 | correct |
| 11 | R L L L U D … | 13 | 0.600 | 0.266 | 145.12–157.32 | 75 | 88 | +13 | correct |
| 12 | D R R D D R R R D / D U U … | 14 | 0.600 | 0.266 | 169.74–180.69 (cut) | 88 | 100 at 12/14 | +12 so far | in progress |

Arrow-on and gap are the fitted constants, not independently OCR'd per arrow. Recall windows are D-pad-visible spans in the 60 fps timeline.

## Proposed Configuration

```
sequenceLengthOffset = 2
sequenceLengthCap = 16
arrowOnDuration = 0.600
interArrowGap = 0.266
transitionToRecallDuration = 0.350
roundSuccessHoldDuration = 0.720
pointsPerCorrectInput = 1
failsOnFirstWrongInput = true
allowsConsecutiveRepeats = true
requiresTapToStart = false
```
