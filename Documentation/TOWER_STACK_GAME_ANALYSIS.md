# Tower Stack Reference Analysis

## Objective

Train visual timing, spatial alignment and shrinking-target precision by tapping to drop a
sliding block onto a pseudo-3D tower. Misaligned blocks are cut to the overlap with the tower
top; the surviving footprint carries into the next block; blocks slide faster as the tower grows.

Reference: `ScreenRecording_09-02-2026 13-05-21_1.MP4`, 1180 × 2556, 119.3 s, encoded at 60 fps
with duplicated frames (effective ≈30 fps for most of the clip). The recording is a YouTube
Short of a Playus session; only the game viewport (x = 70…1109, 1040 px wide) was measured.
Pixel values below are given at half resolution (520 px wide viewport, 1278 px tall) unless
stated otherwise. Measurements were produced with ffmpeg frame extraction plus numpy scripts
(frame differencing, colour segmentation, camera fitting).

## Timeline

| Time | Event |
| --- | --- |
| 0–1.9 s | Platform intro card: "TOWER STACK … Duración ~40s", "2/2 intentos restantes". |
| 1.9–3.1 s | Gameplay already visible under a dark scrim with "Toca para colocar el bloque"; the first block is already sliding behind the scrim. |
| 3.1 s | Tap dismisses the scrim (score "0" appears). The tap does **not** place the block. |
| 4.70 s | First placement, score 1. |
| 116.90 s | Placement 173. |
| ≈117.28 s | "JUEGO TERMINADO – 173 PUNTOS" overlay appears while the next block is still ~0.1 s away from the tower: the player tapped early with a ~5 %-width block → zero overlap → game over. No timer ran out. |
| 117.4–119.3 s | Result card counts up 0 → 173 "Puntos". |

Active gameplay lasted 114 s, so the "~40s" on the instruction card is an estimated typical
duration, not a timer. **End condition = first miss.** The game-over overlay appears within one
recorded frame (≤ 33 ms); no falling missed block is visible.

## Score

174 score-region change events were detected between 3.1 s and 117.3 s (0 appearing, then
1…173). Every event coincides with one placement and the digit-glyph diffs match +1 steps
(2→3, 5→6, 8→9 produce the characteristic small diffs). The pedestal counts as score 0; the
first successful user placement gives 1. No bonus increments were found anywhere in the run.
`pointsPerPlacement = 1`, higher is better.

## Initial State

- A dark grey (RGB ≈ 34–53) pedestal with the same 1 × 1 footprint as the first block rises
  from below the screen; its top face centre sits at ≈ 0.445 of the screen height from the top.
- The first block is orange and spawns at the far end of the right-hand axis (upper-right on
  screen), already moving while the scrim is displayed.
- The player's first tap only dismisses the scrim; the block continued for another 1.6 s
  (it reached the near end, reversed, and was placed on the return pass at 4.70 s).
- Camera starts with the pedestal top at the same screen position later used for the tower top.

## Pseudo-3D Camera

The reference is a real 3D render: the far moving block appears ≈ 20 % smaller than a block on
the tower, and the pedestal's vertical edges converge downward (screen width 348 px at the top
face, 271 px 289 px lower, 235 px 429 px lower). A pinhole camera was fitted to the top-face
diamond corners, the block thickness and the pedestal convergence:

| Parameter | Fit (top face only) | Fit (top face + pedestal) | Chosen |
| --- | ---: | ---: | ---: |
| Pitch (elevation) | 34.9° | 37.4° | 36° |
| Azimuth | 45° (symmetric diamond) | 45° | 45° |
| Camera distance | 8.3 block widths | 3.6 block widths | 5.0 block widths |
| Block height / width | 0.214 | 0.176 | 0.22 (direct thickness measurement) |

Measured top-face diamond of a full-size block at the tower top (frame t = 5.05 s):
far vertex (258, 518), left (86, 603), right (434, 604), near (258, 718); far edges have
slope ±0.49, near edges ±0.66 (perspective asymmetry). Horizontal extent 348 px = **0.67 of the
viewport width**, so the world block edge is 0.475 viewport widths at the tower-top depth.
Block thickness at the near vertical edge = 43–45 px (0.126 of the diamond width); the same
face measured on the far spawning block is 35 px (0.8× – perspective).

Chosen projection: pinhole camera, target = tower-top-surface centre projected to
(0.5 width, 0.445 height from top), pitch 36°, azimuth 45°, distance 5 block widths, focal
length derived so a unit block at the target spans 0.67 of the scene width. This reproduces the
diamond, the 15–20 % far-block shrink and the downward convergence of the pedestal.

## Movement Axes

Consecutive blocks alternate between the two horizontal world axes:

| Block | Spawn (screen) | Direction | Screen path slope |
| --- | --- | --- | ---: |
| 1 | upper-right (behind scrim) | down-left | −0.60 |
| 2 (4.73 s) | upper-left, partly off-screen | down-right | +0.61 |
| 3 (5.67 s) | upper-right | down-left | −0.78 (noisy) |
| 4 (6.62 s) | upper-left | down-right | +0.63 |
| 26, 28 | upper-right | down-left | −0.70 |
| 27, 29 | upper-left | down-right | +0.79 / +0.92 (noisy) |

Every spawn is at the **far** end of its axis (away from the camera) and the block travels toward
the camera, passing over the tower. Axis alternation is strict for all 173 placements sampled
(spawn side alternates upper-right / upper-left in every inspected window). The trainer models
the footprint with two dimensions (width along X, depth along Z); an X placement trims width,
a Z placement trims depth.

## Movement Range and Reversal

- Spawn distance: block 2's far vertex was first fully formed at (70, 377) with the tower's far
  vertex at ≈ 518 and moved to (250, 487) at placement; converting through the fitted camera
  gives a spawn centre ≈ **1.3 block widths** from the tower centre along the axis.
- The only observed reversal is block 1, which reached the near end (its centre about
  1.2–1.4 block widths past the tower centre, mostly off-screen behind the pedestal) and
  reversed immediately without a pause. Blocks 2…173 were always placed on the first pass.
- Reversal distance appears symmetric (≈ ±1.3 widths); the range is in world units and does not
  shrink with the block: the 5 %-width block at score 172 spawned at the same screen location as
  the full block at score 1.
- The movement range being constant means later blocks stay visible for the same time only
  because speed grows; no evidence of pausing, wrapping or easing at the ends.

## Speed

Direct tracking of block 2's far vertex over its whole spawn→placement travel (4.767 → 5.617 s):
Δ = (172, 106) px in 0.85 s → 238 px/s on screen, constant within measurement noise for the far
and near halves (237 vs 239 px/s), i.e. no ease-in/out. Through the fitted camera this is
≈ **1.4 block widths / s** at score 1.

Because every spawn is at the same distance and the player places the block as it reaches the
tower centre, the placement interval is a direct proxy for travel time (spawn → centre):

| Score range | Mean interval (s) | 1 / interval | Relative speed (vs. 1–10) |
| --- | ---: | ---: | ---: |
| 1–10 | 0.957 | 1.045 | 1.00 |
| 10–20 | 0.890 | 1.124 | 1.08 |
| 20–30 | 0.850 | 1.176 | 1.13 |
| 30–40 | 0.800 | 1.250 | 1.20 |
| 40–50 | 0.760 | 1.316 | 1.26 |
| 50–60 | 0.720 | 1.389 | 1.33 |
| 60–70 | 0.680 | 1.471 | 1.41 |
| 70–80 | 0.670 | 1.493 | 1.43 |
| 80–90 | 0.630 | 1.587 | 1.52 |
| 90–100 | 0.600 | 1.667 | 1.60 |
| 100–110 | 0.580 | 1.724 | 1.66 |
| 110–120 | 0.560 | 1.786 | 1.71 |
| 120–130 | 0.530 | 1.887 | 1.81 |
| 130–140 | 0.510 | 1.961 | 1.88 |
| 140–150 | 0.490 | 2.041 | 1.96 |
| 150–160 | 0.480 | 2.083 | 2.00 |
| 160–170 | 0.450 | 2.222 | 2.13 |
| 170–173 | 0.467 | 2.143 | 2.06 |

1/interval grows by ≈ 0.0735 per 10 points with no visible curvature → **linear** progression,
`speed(score) = initialSpeed × (1 + 0.007 × score)`, ≈ 2.2× at score 173. No steps or cap are
visible up to 173; the trainer caps at 4.0 widths/s (≈ score 300) only as a safety limit.

Speed table (chosen constants, block widths per second): score 0 → 1.40, 25 → 1.65,
50 → 1.89, 75 → 2.14, 100 → 2.38, 125 → 2.63, 150 → 2.87, 170 → 3.07.
Traversal time spawn → centre: 0.93 s → 0.42 s.

## Placement / Cutting

- The block slides at the resting height (its bottom on the tower-top surface); there is no drop.
  On tap it stops instantly at its current position.
- The overhang is removed within one recorded frame: comparing the frames before/after the
  score-28 placement (29.17–29.22 s) the block first overhangs the far-left edge, in the next
  frame the top face is smaller and **no falling piece is visible anywhere**. The same holds for
  all inspected placements. The reference therefore cuts instantly with no debris animation.
- Immediately after placement the placed block performs a squash-and-stretch (top face bulges
  wider, thickness compresses) with a dark translucent halo, recovering in ≈ 0.25 s.
- The next block fades in (alpha 0 → 1 over ≈ 0.1 s) at the far end of the other axis about
  30 ms after the placement.
- The surviving block keeps the geometric intersection: offsets visibly accumulate (e.g. block 1
  sits left-front of the pedestal; later blocks show stair-step ledges on the tower).

## Perfect Placement

No perfect-placement text, snap, sound cue, bonus score or block enlargement was found.
Top-face width sampled 0.2 s after each placement is monotonically non-increasing
(350, 350, 340, 340, 332, 332, 323, 311, 303, 303, 290, …). Exact overlap without a special
perfect mechanic is used; a tiny configurable tolerance exists only to absorb floating-point
noise in the intersection.

## Block Size Progression (player-dependent)

| Score | Top-face diamond width (px) | % initial |
| ---: | ---: | ---: |
| 1 | 350 | 100.0 |
| 5 | 340 | 97.1 |
| 10 | 332 | 94.9 |
| 20 | 323 | 92.3 |
| 30 | 303 | 86.6 |
| 40 | 290 | 82.9 |
| 50 | 283 | 80.9 |
| 60 | 277 | 79.1 |
| 70 | 257 | 73.4 |
| 80 | 233 | 66.6 |
| 100 | 213 | 60.9 |
| 120 | 179 | 51.1 |
| 130 | 137 | 39.1 |
| 150 | 118 | 33.7 |
| 160 | 62 | 17.7 |
| 170 | 24 | 6.9 |
| 172 | 17 | 4.9 |

The diamond width mixes both footprint dimensions ((w + d)·cos 45°). The reference player lost
≈ 20 % over the first 50 placements and most of the remainder above 120 as speed grew; the tower
was a needle (≈ 5 % of the initial footprint) at the end. This is used only as a plausibility
check for the accumulated-overlap model, not as a scripted shrink curve.

## Camera

Tower-top far-vertex screen Y (10 fps, per second): median ≈ 490 (t = 5–25 s), 500 (30–50 s),
510 (55–60 s), 522 (63–85 s), 540 (87–105 s), 570 (107–117 s). The drift equals the shrinking
half-height of the top diamond, i.e. the **top-face centre stays at ≈ 0.445 of the screen height
from the top** (≈ 568 px) for the whole run.

Per placement at 60 fps (score 25, 26.23–27.07 s): vertex y 530 → 491 at placement (the new
block is one layer higher), then 491 → 528 over 0.80 s with a slow start (≈ 1 px/frame for
0.45 s, then 3–4 px/frame). At score 150 the same catch-up takes 0.45 s. In both cases the
duration equals the block's spawn→centre travel time, so the camera scroll is synchronised with
the incoming block: `cameraStepDuration = spawnDistance / speed(score)`, ease-in-out.
Camera follows height only; no zoom (the far/near projection stays identical over the run).

## Colours

Top-face colour sampled 0.25 s after each placement (HSV):

| Score | Hue | S | V |
| ---: | ---: | ---: | ---: |
| 3 | 28° | 0.69 | 0.84 |
| 15 | 97° | 0.68 | 0.83 |
| 33 | 180° | 0.69 | 0.84 |
| 51 | 270° | 0.69 | 0.84 |
| 69 | 4° | 0.69 | 0.83 |
| 87 | 97° | 0.68 | 0.83 |
| 105 | 186° | 0.69 | 0.84 |
| 123 | 270° | 0.69 | 0.84 |
| 141 | 359° | 0.69 | 0.84 |
| 159 | 92° | 0.69 | 0.83 |
| 171 | 148° | 0.69 | 0.81 |

Least-squares fit on the unwrapped hue: **hue = 16.7° + 4.99° × blockIndex** (period 72.1
blocks, rms residual 2.4°). Saturation 0.69–0.70 and value 0.83–0.84 are constant. Shading:
left face V × 0.45 (S 0.65), right face V × 0.76 (S 0.68). Pedestal is neutral grey
(left 0.13, right 0.21). Trainer palette: `hue(i) = 17° + 5°·i`, S 0.70, V 0.84, same face
factors — original colours computed procedurally, no assets copied.

Background: vertical gradient, RGB (37, 36, 44) at the top, (58, 49, 96) at 31 %, (89, 65, 181)
at 70 %, (75, 54, 158) at the bottom (hue ≈ 252°).

## HUD

Score digits: white, heavy rounded font, centred at x = 0.5, y ≈ 0.266 of the height from the
top, cap height ≈ 0.055 of the screen height. Nothing else is drawn during gameplay.

## Failure

Frames 116.90–117.28 s (score 173): the tiny block spawns upper-left and is still ≈ 0.1 s from
the tower when the game-over overlay appears; no falling block, no tower reaction. Interpretation:
the player tapped early → zero overlap → immediate game over. No lives, no continue.

## Input

No touch cursor or hit affordance is visible; any tap in the game area places the block.
Multi-touch behaviour cannot be determined from the footage; one placement per touch is assumed.

## High-Confidence Observations

- Pseudo-3D perspective view of a square tower, azimuth 45°, pitch ≈ 36°, moderate perspective.
- Blocks alternate world axes; spawn at the far end; travel toward the camera at constant speed.
- Tap stops the block where it is; the intersection with the tower top survives; the overhang is
  removed instantly; the surviving footprint becomes the next block.
- +1 per placement; base = 0; 173 placements in 112 s; first miss = game over; no timer.
- Speed grows linearly with score (≈ +0.7 % per point; ≈ 2.1× at 170).
- Camera keeps the top-face centre at 0.445 of the height; catch-up takes one travel time.
- Hue advances 5° per block; S/V constant; two side faces shaded 0.45 / 0.76.
- Placed block squashes briefly; next block fades in at spawn.

## Ambiguities

- Exact camera distance (perspective strength) is only bracketed (3.6–8.3 widths); 5 is used.
- Near-end reversal distance is inferred from a single, partially occluded block (block 1).
- Whether the spawn position or speed scales with screen size in the original is unknown; the
  trainer scales everything with the scene width.
- The reference rendered the first block behind the pedestal when it was on the near side (a
  depth-sorting quirk visible only for block 1); the trainer renders correct depth order.
- Whether the game accepts a tap during the spawn fade-in is not observable.
- Absolute speeds carry ≈ ±10 % uncertainty from frame duplication in the recording.
- The reference shows no falling cut piece; the trainer adds a short optional debris fall for
  feedback (configurable, can be disabled to match the reference exactly).

## Initial Configuration (compiled defaults)

- Footprint: 1.0 × 1.0 block widths; block width = 0.475 × scene width at the tower-top depth
  (top diamond 0.67 × scene width); block height 0.22 widths.
- Camera: pitch 36°, azimuth 45°, distance 5.0 widths, target at (0.5, 0.555) in SpriteKit
  coordinates (0.445 from the top).
- Movement: spawn at +1.3 widths (far side), range ±1.3 widths, exact reflection at both ends,
  first axis X (upper-right spawn), then alternate.
- Speed: 1.4 widths/s × (1 + 0.007 × score), cap 4.0 widths/s.
- Camera step: one block height per placement, duration = travel time (spawn → centre),
  ease-in-out.
- Colours: hue 17° + 5° × index, S 0.70, V 0.84; faces 1.0 / 0.76 / 0.45.
- Placement: exact interval intersection per active axis; tolerance 0.0005 widths;
  minimum viable dimension 0.002 widths; zero overlap ends the game.
- Feedback: squash 0.25 s; spawn fade 0.1 s; game-over hold 0.6 s before results (trainer choice
  so the miss is readable; the reference cuts to its overlay instantly).
- Score digit cap height ≈ 0.055 of scene height, centred at y = 0.266 from the top.

## Independent verification (this session)

The same MP4 (`1180×2556`, `119.315 s`, `7171` frames at 60 fps) was re-sampled with ffmpeg at
the timestamps below. Findings agree with the measurements above.

| Time | Frame | Observation |
| --- | --- | --- |
| 1.0 s | Playus card | "TOWER STACK", "2/2 INTENTOS RESTANTES", PLAY. Not gameplay. |
| 1.5 s | Instruction overlay | Spanish copy matching the prompt; hourglass **"Duración ~40s"**. |
| 2.2 s | Hint | "Toca para colocar el bloque"; grey pedestal; orange block already sliding; faint "0". |
| 3.2 s | After first tap | Scrim gone; score **0**; block still sliding (tap did not place). |
| 4.75 s | After placement 1 | Score **1**; next block entering from **upper-left**. |
| 5.75 s | After placement 2 | Score **2**; next block entering from **upper-right**. Axes alternate. |
| 15.0 s | Score 11 | Yellow-green top; stepped ledges; camera still frames the top. |
| 29.15–29.23 s | Score 27 | Green; cut happens with **no falling debris** in adjacent frames. |
| 60 s | Score 69 | Warm red top face. |
| 80 s | Score 100 | Green again (hue has wrapped). |
| 100 s | Score 137 | Magenta/pink; tower is a thin needle. |
| 116.85 s | Score 172 | Green needle; still playing. |
| 117.20 s | Score 173 | Game-over path; no timer expiry. |
| 117.8 s | Results | Playus result chrome over the finished tower. |

Direct RGB samples of the top-face (full-frame coordinates ≈ (590, 1100)):

| Score (approx.) | RGB | HSV hue | `17° + 5° × index` |
| ---: | --- | ---: | ---: |
| 1 | (204, 107, 68) | 17.2° | 17° |
| 2 | (206, 119, 68) | 22.2° | 22° |
| 28 | (78, 235, 150) | 147.5° | 152° |
| 69 | (200, 52, 70) | 352.7° | 357° |
| 137 | (190, 45, 114) | 331.4° | 337° |

Residuals are sampling/AA noise, not a different model. Background top ≈ (48, 43, 65).
Active gameplay from first tap (~3.1 s) to miss (~117.3 s) is **~114 s**, confirming that
"~40s" is typical-duration metadata, not a session timer.
