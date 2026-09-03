# TRACE Reference Analysis

Source recording: `ScreenRecording_09-03-2026 13-11-50_1.MP4` (HEVC, 1180×2556, 60 fps, 106.92 s, 6424 video frames). The file is an iPhone screen recording of a YouTube Short of Playus “Trace 98 Points”. YouTube chrome, avatars, “La puntuación cuenta”, trophy chips, and percentile text are **not** part of the trainer.

Method: 1 fps overview of the full Short, 10 fps of the first 15 s of the playfield, 2 fps of the cropped playfield for the whole run, native frames at representative timestamps, and RGB classification of yellow vs cyan pixels. Score digits were read from playfield frames (the large white integer), not from YouTube overlays. Node counts and path lengths at high density are harder to census through compression and the tracing finger; those rows are marked.

## Objective

Train **ordered path memory** plus **motor tracing**. A yellow path is drawn through a field of dim circular nodes. After it disappears, the player drags through the same nodes in the same order. Correct steps paint a cyan path and add points. Patterns get denser and longer. Higher integer score is better.

This is **not** a set-memory game (which nodes were used). The task is the connected sequence.

## Dot Field Geometry

| Score (approx) | Lattice | Rows × cols (best reading) | Visible nodes | Notes |
| ---: | --- | --- | ---: | --- |
| 0 | sparse offset / rectangular-looking | **3 × 2** | 6 | Multiple native frames. Two columns, three rows. |
| 3 | same family, slightly wider | ~3 × 3 to 4 × 3 | ~7–12 | Dim nodes appear beside the path. |
| 7 | denser offset | ~4 × 3 to 5 × 4 | ~12–20 | |
| 14 | clearly staggered rows | ~5 × 4 | ~20 | Finger on a cyan node; rows look offset. |
| 33 | dense field | ~6 × 5 to 9 × 6 | ~30–50 | Yellow path ~10 nodes. |
| 52 | dense | ~5 × 5 claimed / denser | | Recall, finger down, path not yet drawn. |
| 75 | hexagonal-looking outline | ~7–8 rows | | Yellow path ~7 nodes. |
| 87–98 | dense hex packing | ~7–9 staggered rows | ~40+ | One late frame is consistent with a hex-packed cluster, not a sparse rectangle. |

**Lattice decision:** late-game rows are **staggered** (hex / odd-r offset packing). Early 3×2 is the same packing with so few columns that it looks rectangular. Horizontal segments exist (so this is **pointy-top hex**: E/W plus four diagonals, not flat-top). Apparent “straight down” segments at high density are treated as steep hex diagonals, not square-grid verticals.

All nodes of a given round sit on one regular offset lattice. They do **not** all remain a single hard-coded 4×4. Density is a difficulty variable.

Playfield (ignoring YouTube chrome) occupies the central/lower ~0.55 of the Shorts frame, horizontally centered. Node visual radius scales with spacing (thick yellow “sausage” joins are about one node diameter). Hit regions are circular and slightly larger than the fill, but not huge: the player must pass near a node to snap.

Normalized trainer defaults (full-screen SpriteKit, not the cropped Short):

| Quantity | Ratio / rule |
| --- | --- |
| Score Y from top | `scoreYFromTopRatio = 0.12` |
| Timer bar Y from top | `timerYFromTopRatio = 0.155` |
| Timer width | `timerWidthRatio = 0.56` |
| Timer thickness | `timerThicknessRatio = 0.007` of scene width |
| Grid center Y from bottom | `gridCenterYRatio = 0.42` |
| Grid footprint width | `gridWidthRatio = 0.78` |
| Grid footprint height | `gridHeightRatio = 0.52` |
| Node visual radius | `0.22 × hex spacing` |
| Line width | `0.42 × hex spacing` |
| Hit radius | `0.42 × hex spacing` (non-overlapping neighbors) |

## Reference Pattern Presentation

Yellow path. It does **not** pop in as a finished drawing.

Yellow-pixel counts on the 10 fps early crop:

| t (s) | Yellow samples | Reading |
| ---: | ---: | --- |
| 1.5 | 3675 | Game has started; first nodes appearing |
| 2.0–3.0 | ~9400–10200 | First pattern held, ~4 nodes / 3 segments |
| 3.5 | 474 | Path gone; recall begins |
| 5.5 | 2428 | Second pattern starts (first node / first segment) |
| 6.0 | 4634 | Growing |
| 6.5 | 11587 | Growing |
| 7.0 | 17483 | Near-complete (~5–6 nodes) |
| 7.5 | 18593 | Hold |
| 8.0 | 140 | Hidden |

**Model:** draw **node-to-node** at `segmentRevealDuration ≈ 0.32 s` per added node after the first, then `patternHoldDuration ≈ 0.40 s`, then **instant hide** (not a fade). Path nodes are solid yellow circles; joins are thick yellow strokes with round caps and round joins. Dim grid nodes stay visible the whole time.

Selected reference nodes brighten to opaque yellow. Inactive nodes stay dim.

## Player Input

One continuous drag. Native `touchesBegan` / `touchesMoved` / `touchesEnded`. No submit button.

- Finger down on the **first target node** starts the trace (cyan).
- Dragging through later nodes **snaps** to node centers. The committed path is geometric (center→center), not raw finger polyline.
- While dragging, a cyan tether from the last accepted node toward the finger is visible before the next snap (native frame t ≈ 4.0 s).
- Remaining inside the same node does **not** append duplicates.
- Individual taps of the first node only highlight that node; the rest of the path still needs a drag (or a slide into the next hit circle). There is no evidence of tap-tap-tap as the primary control.
- Lifting before the path is complete ends the attempt (see Incorrect Pattern Behavior). Completing the last node evaluates immediately; a lift is not required.

Input is ignored while the yellow path is showing, during the short evaluation gap, and after the session ends.

## Path Validation

`targetSequence: [TraceNode]` and `playerSequence: [TraceNode]`. **Order matters.** This is option C in the brief (exact connected path / sequence), not A (set of nodes).

- Correct iff `playerSequence` equals `targetSequence` element-wise.
- Reverse `D,C,B,A` is **rejected**. The recording never traces a path backwards; the first node of the yellow draw is the required start. Assumption is documented because the source never tests reverse explicitly.
- Generator and input both use **hex-adjacent** steps only. No observed segment jumps over an intermediate lattice node.
- Revisits: no high-confidence target path reused a node. Generator forbids repeats.
- Self-crossing: not used as a design feature. Hex-adjacent simple paths do not cross their own interiors. Generator does not add extra no-cross constraints.

## Scoring

**Higher is better. Integer points. +1 per correct segment, awarded the moment the next correct node snaps — not only after the full path.**

Evidence:

- During the first recall, the score is **0** while the yellow path is up, **1** at t ≈ 4.0 s with a single cyan segment, then **3** at t ≈ 5.0 s with a longer cyan path. Intermediate **2** is consistent with 0.5 s sampling missing one snap.
- Completing a 4-node / 3-segment path therefore adds **3**. Completing a 5-node path adds **4**.
- The first node of a path does **not** add a point.

This matches irregular increments as paths get longer (prompt samples 1, 3, 5, 7, 9, … 17, 24, …) better than “+1 per completed round” or “+1 per node including start”.

Wrong nodes and incomplete lifts do **not** subtract already-awarded segment points. They just stop that pattern.

Fixtures used in tests are only the high-confidence first two rounds. Later deltas in the Short are consistent with “delta = segment count” but path length at those timestamps is not census-grade.

## Difficulty Progression

Grid size and typical path length both grow with **score**, not with wall-clock time. The source does not show a labelled level chip.

Compiled score thresholds (interpolated between measured snapshots; last row is a cap):

| Min score | Rows × cols | Nodes | Typical target count |
| ---: | --- | ---: | ---: |
| 0 | 3 × 2 | 6 | 4 |
| 8 | 4 × 3 | 12 | 5 |
| 16 | 5 × 4 | 20 | 6 |
| 28 | 6 × 5 | 30 | 7 |
| 42 | 7 × 6 | 42 | 9 |
| 60 | 8 × 7 | 56 | 11 |
| 80 | 9 × 8 | 72 | 13 |

Path length is **not** strictly monotonic in the recording (a score-75 presentation looks shorter than a score-33 presentation). The trainer samples uniformly in a widening range around the typical count, clamped to `[3, min(16, nodeCount)]`.

Exposure time grows with segment count because the path is drawn incrementally. Recall window also grows with segment count so late paths remain completable.

## Pattern Generation

Deterministic seeded walk on the current hex lattice:

1. Pick a random in-bounds start node.
2. Repeatedly append a random **unvisited hex neighbor**.
3. If the walker is stuck before reaching the target length, restart from a new start (bounded attempts).
4. Reject consecutive duplicates (implied by unvisited), out-of-bounds nodes, and zero-length steps.

No global `Int.random`. Tests inject `SeededRandomNumberGenerator`.

## Timer / Progress Bar

Thin yellow stadium under the score, dark/empty track to the right.

**This is a per-pattern recall timer, not a global session bar.**

Proof it resets: at t ≈ 90 s (score 87, mid-trace) the fill is about one third; at t ≈ 100 s (score 94, another trace) it is about two thirds again. A monotonic session bar cannot refill.

It is **not** path-progress: at recall start (t ≈ 3.5 s, zero cyan nodes) the bar is **full**.

Drain happens during `awaitingTrace` and `tracing`. During yellow presentation the bar is empty/absent in several frames. Trainer: hide fill while showing the pattern; set remaining = full when recall starts; linear drain.

Recall duration (compiled, generous so the source run is possible):

`recallDuration = 2.8 + 0.55 × segmentCount` seconds.

First pattern (3 segments) ≈ 4.5 s of recall budget. The player finished in ~2 s.

## Timeout

The high-score recording **never** reaches zero. Timeout behavior is therefore an assumption: keep awarded points, abandon the rest of the pattern, start the next pattern. It does **not** end the session. Configurable.

## Correct Pattern Behavior

Last correct node snaps → last +1 → short evaluating beat → new grid/path generated from the new score → yellow draw starts. No extra bonus for speed was isolated (increments equal segment counts).

## Incorrect Pattern Behavior

No clear on-camera fail. The demonstrated run is a skilled full trace of every shown path.

Trainer model (smallest defensible, configurable):

- Wrong next node: attempt ends; already-awarded segments stay; next pattern.
- Lift before completion: same.
- Reverse start node: wrong node.
- First mistake is **not** game over.

## Round Transition

~0.25–0.45 s of empty grid between cyan clear and the next yellow node (t ≈ 10.5 s: neither yellow nor cyan). Trainer: `transitionDuration = 0.35 s`.

## Session End

**Not observed.** At t ≈ 104 s the score is still ~96–98 and a cyan trace is in progress. The Short ends while play continues. “98 points / top 1%” is YouTube copy, not an in-game game-over card.

Trainer default: **`sessionDuration = 110 s`** inferred from this ~107 s clip of a claimed high score, plus a few seconds of YouTube intro. When it expires, the run finishes with the current score (mid-pattern remaining segments are not awarded). This is an assumption and a DEBUG control. Pause/quit does not record a result (same as Keep Up forfeit); the session timer is the competitive end.

## High-Confidence Observations

- Blue field, dim circular nodes, yellow reference, cyan recall, large white score, thin yellow bar under the score.
- First grid is 3×2 / 6 nodes.
- Yellow path draws progressively, then vanishes before cyan recall.
- Score increases **during** a correct trace, +1 per added segment.
- Drag-to-snap, geometric cyan segments, rubber-band to the finger.
- Bar refills between patterns (per-recall timer).
- Density and path length increase overall with score.
- Hex / staggered packing at mid/late scores; horizontal + diagonal segments.

## Ambiguities

- Exact row×col at every score after ~10 (compression, finger occlusion).
- Exact path length for every round after the first two.
- Whether a true square-grid vertical step exists (compiled as hex diagonal).
- Reverse-path acceptance (rejected by sequence-memory reading).
- Wrong-node and timeout outcomes (never shown).
- Whether a hidden session clock exists; 110 s is inferred.
- Node revisits / self-crossing (not seen; generator avoids revisits).
- Exact hit-radius forgiveness (compiled as 0.42 × spacing).

## Frame Measurements

Observable rounds from native / 10 fps / 2 fps samples. “—” means not reliably countable.

| t (s) | Phase | Score before | Score after | Δ | Grid | Target nodes | Segments | Present (s) | Trace (s) | Bar | Correct? |
| ---: | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1.5–3.5 | show #1 | 0 | 0 | 0 | 3×2 | 4 | 3 | ~2.0 | — | hidden/empty | — |
| 3.5–5.3 | recall #1 | 0 | 3 | +3 | 3×2 | 4 | 3 | — | ~1.8 | full → draining | yes |
| 5.5–7.8 | show #2 | 3 | 3 | 0 | ~3×3+ | 5–6 | 4–5 | ~2.3 | — | hidden | — |
| 8.0–10.3 | recall #2 | 3 | 7 | +4 | same | 5 | 4 | — | ~2.3 | draining | yes |
| ~10.5–13 | show #3 | 7 | 7 | 0 | denser | — | — | ~2.5 | — | hidden | — |
| ~13–15 | recall #3 | 7 | ~14 by t=20 | — | — | — | — | — | — | draining | yes |
| ~20 | recall | 14 | 14 | — | staggered | — | — | — | in progress | present | yes |
| ~40 | show | 33 | 33 | 0 | dense | ~10 | 9 | in progress | — | faint | — |
| ~60 | recall start | 52 | 52 | — | dense | — | — | — | starting | ~70% | — |
| ~80 | show | 75 | 75 | 0 | hex-like | ~7 | 6 | in progress | — | faint | — |
| ~90 | recall | 87 | 87 | — | hex-like | ≥11 | ≥10 | — | in progress | ~33% | yes |
| ~95 | show | 88 | 88 | 0 | hex-like | long (~15?) | — | in progress | — | faint | — |
| ~100 | recall | 94 | 94 | — | hex-like | ≥8 | — | — | in progress | ~65% | yes |
| ~104–107 | recall | 96–98 | — | — | hex-like | — | — | — | in progress | ~20–25% | recording ends |

Score after round 3 is not isolated to a single frame; t=20 s shows **14**.

## Proposed Configuration

See `TraceGameConfig.reference` and `TraceDifficultyModel`. All of the above durations, thresholds, and radii are DEBUG-tunable. Seeded generator. No Playus branding.
