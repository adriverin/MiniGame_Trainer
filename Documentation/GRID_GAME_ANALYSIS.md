# GRID Reference Analysis

Source: `ScreenRecording_09-03-2026 12-54-04_1.MP4` (111.14 s, 60 fps, 1180×2556).
The recording is a phone screen-capture of a YouTube Short of handheld tablet gameplay, so HUD digits and cell counts were measured from the inner game surface rather than inferred from still screenshots alone.

Monotonic times below are video timestamps, not frame indices.

## Objective

GRID is a spatial working-memory task. A subset of cells lights up, the highlight disappears, and the player must recreate the same set of cells and submit before a per-round recall timer expires. Higher integer score is better.

## Round Flow

1. HUD shows the current score and `LEVEL N`.
2. A rectangular grid of rounded squares appears, all visually equivalent.
3. A subset of cells lights pale cyan/white for a short presentation.
4. Highlights disappear. Unselected cells are indistinguishable.
5. The player taps cells to reconstruct the set. Selected cells stay lit.
6. A green submit control (`Okay!` in the source; trainer uses `SUBMIT`) evaluates the set.
7. A correct set awards points, advances one level, and starts the next pattern.
8. Grid size and target count increase across the run.

The intro line *“Memoriza el patrón, luego recrealo.”* appears only at session start.

## Grid Size Progression

Measured from frames where the full board is visible:

| Level | Rows × columns | Evidence |
| --- | --- | --- |
| 1 | 3×3 | t≈5.5–8.5 s, score 0 then 4 |
| 2 | 3×3 | still 3×3 immediately after the first score of 4 |
| 3 | 4×4 | t≈15.5 s, score 16, 4×4 board |
| 4 | 4×4 | 4×4 remains through the run-up to score 28 |
| 5 | 5×5 | t≈29.5 s, score 28, `Nivel 5`, 5×5, submit in progress |
| 6 | 5×5 | t≈40 s, score 41, `Nivel 6` |
| 7 | 6×6 | t≈49.5 s, score 60, `Nivel 7` |
| 8 | 6×6 | 6×6 continues |
| 9 | 6×6 | t≈79.5 s, score 97, `Nivel 9` |
| 10 | 7×7 | t≈99.5–111 s, score 120 then 148, `Nivel 10` |

A 4×3 / 5×6 reading appeared in a few blurry frames; those are treated as camera-crop artefacts. The high-confidence sequence is square grids: 3, 3, 4, 4, 5, 5, 6, 6, 6, 7.

## Pattern Size Progression

Target counts were not printed. They are inferred from (a) cells lit at submit when the selection looks complete, and (b) score deltas if scoring equals target count.

| Level | Inferred targets | Notes |
| --- | --- | --- |
| 1 | 4 | Directly counted on the 3×3 at first submit |
| 2 | 6 | Score 4→10 |
| 3 | 6 | Score 10→16; 6/16 of a 4×4 |
| 4 | 12 | Score 16→28; dense 4×4 |
| 5 | 13 | Score 28→41; ~12 lit at the Nivel 5 submit (count ±1) |
| 6 | 19 | Score 41→60; density is high on 5×5 |
| 7 | 17 | Score 60→77; density drops as the board grows to 6×6 |
| 8 | 20 | Score 77→97 |
| 9 | 23 | Score 97→120 |
| 10 | 28 | Score 120→148 at end of recording |

Patterns are non-contiguous. Isolated cells, edge cells, and diagonal neighbours all appear. No symmetry-avoidance rule is visible.

## Pattern Exposure Duration

Presentation is short. The green recall bar is absent during presentation and returns as soon as recall starts.

Round-transition gaps in which the bar is gone (submit feedback + next presentation):

- t≈30.0–33.0 s → ~3.0 s total
- other clean gaps cluster around 2–4 s

After subtracting the ~0.35 s post-submit beat used by other trainer games, **presentation is about 1.2–2.0 s**. It does not clearly shorten with level in this recording. Implemented as a constant **1.40 s**, configurable.

## Recall Phase

Recall is explicit: cells start equivalent, the player builds a selection, then submits. A lime progress bar is visible only in this phase.

## Cell Selection

Taps light a cell pale cyan/white. Selected cells remain lit until submit. The recording never clearly shows a selected cell being tapped off, but the player reconstructs deliberately before `Okay!`. **Toggle-on/toggle-off is implemented** so an accidental tap can be corrected. Assumption is documented here.

## Submission

A wide green pill under the grid. Source copy is `Okay!`. Trainer copy is `SUBMIT`. The control is only active during recall. Evaluation is the set of currently selected cells.

## Correct Answer Behavior

Score jumps, level increments by one, grid may grow, and a new pattern is presented after a short beat. No long celebration. Implemented feedback hold: **0.35 s**.

## Incorrect Answer Behavior

**Unknown.** The supplied run is a strong completion and never shows a wrong submit, a life counter, or a reveal-of-truth animation.

Trainer default, matching Keep Up / Tower Stack: **one incorrect submitted set ends the run**. No life system. Configurable in DEBUG.

## Scoring

Observed HUD scores at level boundaries:

| After level | Score | Delta |
| --- | --- | --- |
| start | 0 | — |
| 1 | 4 | +4 |
| 2 | 10 | +6 |
| 3 | 16 | +6 |
| 4 | 28 | +12 |
| 5 | 41 | +13 |
| 6 | 60 | +19 |
| 7 | 77 | +17 |
| 8 | 97 | +20 |
| 9 | 120 | +23 |
| 10 | 148 | +28 |

`+1 per level` is ruled out. Deltas equal the inferred target counts above. Time-bonus hypotheses (delta = targets × remaining-time factor) are not uniquely identified: later rounds still award large integer jumps while the bar is only partly depleted.

**Implemented rule:** on a correct submit, `score += targetCells.count`. Deterministic. No random bonus. Wrong or timed-out submits add 0 and end the run.

## Level Progression

Visible labels: `Nivel 1`, `Nivel 5`, `Nivel 6`, `Nivel 7`, `Nivel 9`, `Nivel 10`. Trainer displays `LEVEL N`. One correct submit advances exactly one level.

Primary difficulty variables actually visible:

1. Grid size (3→7)
2. Number of highlighted cells

Exposure duration and recall timeout do **not** obviously tighten in this recording, so they stay constant.

## Timing / Timeout

The intro badge `Duración ~30s` is a typical-session estimate, not a 30 s global clock. Gameplay in this recording lasts ~105 s after Start and still shows a mostly-full green bar at late levels.

The bar **resets every round** and depletes only during recall. Four well-measured recall windows:

| Window | Fill drop | Implied full duration |
| --- | --- | --- |
| t≈24–30 s | 0.61→0.39 of HUD | ~18 s |
| t≈47–53 s | 0.68→0.39 | ~14 s |
| t≈77–84 s | 0.67→0.34 | ~14 s |
| t≈94–100 s | 0.67→0.40 | ~15 s |

**Implemented recall timeout: 15.0 s**, monotonic `TimeInterval`, not frame count.

## Timeout Behavior

The recording never reaches 0 on the bar. Implemented default: timeout is treated as an incorrect round and ends the run. Assumption, exposed for calibration.

## Visual Geometry

- Board is centered and remains inside a fixed envelope as *n* grows.
- Cells are rounded squares with a small dark gap (~12 % of cell size).
- Corner radius ~22 % of cell size.
- Inactive fill: dark blue/purple. Active/selected: pale cyan/white. Same treatment for presentation and player selection.
- Cell size is derived from the envelope:

```
cellSize = min(
  availableWidth  / (columns + gapRatio * (columns - 1)),
  availableHeight / (rows    + gapRatio * (rows - 1))
)
```

Fixed cell pixels would overflow at 7×7; that is rejected.

## High-Confidence Observations

- Set-equality scoring; tap order does not matter.
- 3×3 / 4×4 / 5×5 / 6×6 / 7×7 square progression.
- Level 1 highlights 4 cells and scores +4.
- Per-round recall timer ~15 s, not a 30 s session timer.
- Submit button required; filling the set does not auto-advance.
- Presentation highlight fully clears before recall.
- One-life fail pattern is *not* observed; it is a trainer default.

## Ambiguities

- Exact target counts after level 1 (inferred from score deltas).
- Whether a wrong submit ends the run, deducts points, or retries the level.
- Whether selected cells can be deselected (assumed yes).
- Exact presentation duration vs. submit-feedback split.
- Exact timeout fail behaviour.
- Whether later levels shorten exposure (not supported by this tape).
- Level 6 target density (19/25) is aggressive; may need human calibration.

## Frame Measurements

See the per-level table in **Proposed Configuration**. Additional notes:

- t≈0–5 s: Playus intro / Start. Ignored for branding.
- t≈5.5 s: trainer-equivalent playfield, score 0, `Nivel 1`, 3×3.
- t≈7.5 s: 3×3 with 4 lit cells, avatar `4 Puntos`.
- t≈29.5 s: 5×5, score 28, `Nivel 5`, finger on `Okay!`.
- t≈40 s: score 41, `Nivel 6`, 5×5.
- t≈49.5 s: score 60, `Nivel 7`, 6×6.
- t≈79.5 s: score 97, `Nivel 9`, 6×6.
- t≈99.5 s: score 120, `Nivel 10`.
- t≈111 s: score 148 (title also states 148). No Playus ranking UI is reproduced.

## Proposed Configuration

| Level | Rows × columns | Total cells | Targets | Presentation | Recall | Score before | Score after | Delta | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 3×3 | 9 | 4 | 1.40 s | 15.0 s | 0 | 4 | +4 | correct |
| 2 | 3×3 | 9 | 6 | 1.40 s | 15.0 s | 4 | 10 | +6 | correct |
| 3 | 4×4 | 16 | 6 | 1.40 s | 15.0 s | 10 | 16 | +6 | correct |
| 4 | 4×4 | 16 | 12 | 1.40 s | 15.0 s | 16 | 28 | +12 | correct |
| 5 | 5×5 | 25 | 13 | 1.40 s | 15.0 s | 28 | 41 | +13 | correct |
| 6 | 5×5 | 25 | 19 | 1.40 s | 15.0 s | 41 | 60 | +19 | correct |
| 7 | 6×6 | 36 | 17 | 1.40 s | 15.0 s | 60 | 77 | +17 | correct |
| 8 | 6×6 | 36 | 20 | 1.40 s | 15.0 s | 77 | 97 | +20 | correct |
| 9 | 6×6 | 36 | 23 | 1.40 s | 15.0 s | 97 | 120 | +23 | correct |
| 10 | 7×7 | 49 | 28 | 1.40 s | 15.0 s | 120 | 148 | +28 | correct |
| 11+ | 7×7 | 49 | min(48, 28+2×(level−10)) | 1.40 s | 15.0 s | — | — | +targets | — |

Generator: unique random cells, no connectivity constraint, seeded in tests/DEBUG.

Interruption: if the app backgrounds during presentation or recall, the current round is restarted (new pattern, same level and score) so a compromised memory trial is not continued.
