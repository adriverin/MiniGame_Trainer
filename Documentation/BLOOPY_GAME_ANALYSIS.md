# BLOOPY Reference Analysis

Primary source: `ScreenRecording_09-03-2026 15-51-49_1.MP4` (1180 × 2556 HEVC, 83.403 s, 5012 frames, 60.09 fps). The recording is a YouTube Shorts capture of a Playus Bloopy run to 554. All measurements ignore player chrome (status bar, leaderboard strip, subscribe/nav, right-side icons) and use a gameplay crop of approximately y = 280...2100 (1820 px tall). SpriteKit trainer coordinates are bottom-origin; source pixels are top-origin.

The video was inspected as 1 Hz overview frames, 10 Hz start/end plates, native key frames, and a ~20 Hz computer-vision track (1520 samples, 1133 with a ball lock). Source frames can duplicate and the large score / YouTube icons can occlude the ball, so values are rounded.

This is **not** KEEP UP. The player steers the ball; platforms are environmental landing surfaces.

## Objective

Climb as high as possible by landing a white ball on floating peach platforms. Vertical bounce is automatic. Horizontal motion is player-steered. The world wraps at the left and right edges. Higher integer score is better. The demonstrated run reaches **554** and then fails.

## Player Control

Source instruction (Spanish on the intro plate, ~t = 4–6 s):

> Toca izquierda o derecha para moverte mientras la bola rebota hacia arriba. La pantalla se repite en los lados — desaparece por un lado y reaparece por el otro.

English equivalent: tap left or right to move while the ball bounces upward; the screen wraps at the sides.

There are **no** visible left/right buttons and **no** drag-to-position cursor. Control is invisible half-screen steering.

Observed trajectories are smooth curves, not discrete hops. Horizontal velocity frequently sits near zero (median |VX| ≈ 18 px/s in the 20 Hz track) and is driven up to roughly 0.7–1.6 play-widths/s under input (p90 ≈ 822 px/s, p99 ≈ 1948 px/s; the p99 tail is contaminated by occlusions). Sign reversals are common (117 in the track).

Adopted input model (best fit; not a drag paddle):

- Touch left half → constant horizontal acceleration left
- Touch right half → constant horizontal acceleration right
- Holding keeps applying acceleration
- Releasing stops acceleration; residual VX decays with damping
- No center dead zone (none visible)
- One active command: latest touch wins
- Touch never applies a vertical impulse

This is model **C** (hold accelerates) with damping on release, not KEEP UP's absolute platform drag.

## Ball Physics

| Quantity | Source | Compiled trainer |
|---|---|---|
| Ball diameter | median radius ≈ 32 px → 64 px | `0.054` of scene width |
| Gravity | fitted from ~0.70 s hop and ~0.31 H world bounce | `4.80` scene-heights / s² |
| Bounce impulse | time-to-apex ≈ 0.36 s | `1.72` scene-heights / s |
| Starting VX | near 0 after the first hops | `0` |
| Max \|VX\| | p90–p99 band | `1.45` scene-widths / s |
| Horizontal accel | p50 ≈ 0.82 W/s², reversals faster | `2.40` scene-widths / s² |
| Horizontal damping | VX often collapses toward 0 when unsteered | `2.20` / s |

Vertical integration is exact constant acceleration. Horizontal integration is acceleration-or-damp, then toroidal wrap. Physics is **not** score-scaled: landing-to-landing time stays ~0.67 s early, ~0.75 s mid, ~0.70 s late.

## Automatic Bounce

The ball rebounds whenever its bottom crosses a platform top while descending. No tap is required. Time-to-apex ≈ 0.36 s; typical landing-to-landing ≈ 0.70 s because the next platform is higher than the departure platform, so descent is shorter than a same-height hop.

Bounce impulse does **not** change with score in this recording. Platform color does **not** change the outgoing VY (the t ≈ 20.0 s hop off a red platform is a normal rise).

## Platform Geometry

Peach (and later red) rounded rectangles.

| Band (video t) | Approx score | Width / 1180 | Height / play | Notes |
|---|---:|---:|---:|---|
| 8–15 s | 0–50 | 0.23 | 0.036 | 4–5 platforms on screen |
| 15–25 s | 50–130 | 0.21 | 0.036 | |
| 25–40 s | 130–270 | 0.17 | 0.034 | |
| 40–55 s | 270–380 | 0.12 | 0.036 | |
| 55–70 s | 380–480 | 0.097 | 0.036 | |
| 70–83 s | 480–554 | 0.085 | detector-starved | very narrow |

Platform thickness is roughly half a ball diameter and does not shrink. Width is the difficulty lever.

## Platform Generation

X positions span left, center, and right. Because the world wraps, a platform near x = 0 is horizontally close to one near x = W. Consecutive vertical gaps on screen grow from ~0.19 play-heights early to ~0.43 later, then plateau. That is consistent with a score-driven spacing ramp that stays inside one bounce height (~0.31 H).

Generator rules used in the trainer:

- Deterministic RNG for X, width jitter, and spacing jitter
- Next platform must be vertically reachable (`Δy < bounce height`)
- Horizontal placement uses **toroidal** distance, not Euclidean X
- Maximum wrap-distance ≤ flight-time × max VX × reachability margin
- 8 platforms of lookahead; recycle when far below the camera

## Camera / Vertical Progression

The ball stays in a tight screen band during successful climbing:

| Video t | Ball play-Y mean | min | max |
|---|---:|---:|---:|
| 15–25 s | 0.459 | 0.393 | 0.538 |
| 25–40 s | 0.450 | 0.380 | 0.551 |
| 55–70 s | 0.523 | 0.375 | 0.932 |

Image-Y min ≈ 0.38 play is the apex. Successful landings sit near 0.45–0.50 play. Converted to full-frame bottom-origin that is about **0.56–0.58** of scene height. The camera therefore does **not** center the ball. It only scrolls upward when the ball is above a follow line near `0.58 H`, and it never scrolls down. World Y, camera Y, and screen Y are separate.

## Horizontal Screen Wrap

The instruction is explicit and is treated as a rule even though this particular run almost never uses the edges (only one 20 Hz sample with xr < 0.12). Wrap is toroidal on the **ball center**, preserving overshoot:

`x ← ((x % W) + W) % W`

Example: W = 100, x = 98, Δx = +5 → x = 3. VX sign is unchanged. There is no side-wall reflection.

Partial clipping is expected: the ball can sit half off-screen. The trainer draws a wrap-copy sprite when the disc overlaps an edge so the incoming half is visible. The recording does not isolate a clean dual-sprite frame, so this is the simplest matching treatment.

## Collision

Valid landing only on the **top** face:

- ball descending (`vy < 0` in +Y-up)
- previous bottom above platform top
- current bottom crosses platform top
- toroidal X overlap with the platform slab (test `x`, `x − W`, `x + W`)

Reject underside hits, side-wall slab hits, and a second bounce on the same platform until the ball has left it. Resolve `ballY = platformTop + radius`, apply bounce impulse, keep leftover timestep.

## Scoring

Score is **not** +1 per platform. Visible integers:

| t (s) | Large score |
|---:|---:|
| 9.0 | 12 |
| 10 | 16 |
| 12 | 32 |
| 15 | 44 |
| 20 | 88 |
| 30 | 175 |
| 45 | 313 |
| 60 | 408 |
| 75 | 517 |
| 80.5 | 554 |

Rate during clean climbing is about **7–9 points/s**. Bounce cadence is ~0.70 s, so that is ~5–6 points per hop — and the values are not multiples of a constant per-landing award (12, 16, 32, 44, 88). That matches **maximum world-height** scoring.

Calibration used in the trainer: 1 point per `0.038` scene-heights of max world Y above the start. A 0.70 s hop that nets ~0.22–0.25 H then yields ~6–7 points, and 72 s of climbing yields ~550, matching 554.

The large center number updates continuously as height is gained, not only on contact. The header “TÚ” chip can lag by a few points (t = 45 s description: 313 vs 309).

Playus live-event copy (“La puntuación cuenta a las: 35 Puntos”, Top 1%, leaderboard avatars) is **not** reproduced.

## Difficulty Progression

Physics (g, impulse, steer accel, max VX) stays constant. Difficulty comes from layout:

- platform width 0.235 → 0.080 of width
- vertical spacing 0.145 → 0.310 of height (capped under bounce height)
- used platforms stay visible longer and read as red
- no moving platforms observed
- no independent break/fall/fade besides scrolling off the bottom

## Platform Colors / Types

Fresh platforms are peach/tan. Red platforms appear from t ≈ 19.9 s (score ~86) onward, **always in the lower half**, and their screen Y increases (they scroll down) then leave. At t = 20.0 s the ball hops off a red slab with a normal trail. Conclusion: **red = already used**, still solid, still landable. Not a hazard, not a moving type, not a score marker.

Early reds are scarce in the track because used slabs sit near the crop bottom / under YouTube chrome.

## Miss / Failure

At t ≈ 80.5 s the score is already 554 and the ball is descending in the lower-right toward a narrow platform. The score does not increase afterward. The run ends because the ball misses and falls below the visible field, not because a red platform kills it and not because the recording is cut at a live peak. Game over waits until the ball is unrecoverable below the camera, not merely because it passed one slab.

## Session End

No source Game Over card is readable under YouTube UI. The trainer holds ~0.42 s after the ball crosses the failure line, then reports the integer height score through `StatisticsStore` (higher-is-better).

## Trail

Historical dotted samples, conceptually like KEEP UP but recalibrated: ~10–14 visible discs, interval 0.045 s, lifetime 0.70 s, scale 0.55 → 0.18, opacity 0.55 → 0.18. Point samples only — a wrap must not draw a segment across the screen.

## Visual Geometry

| Item | Trainer |
|---|---|
| Background | dark teal `RGB(10, 78, 96)` — original, not a Playus asset |
| Fresh platform | peach `RGB(245, 197, 160)` |
| Used platform | red `RGB(214, 72, 64)` |
| Ball | white disc |
| Score | large white, ~0.72 H from the bottom, **behind** platforms |
| Platform corner | ~0.22 of platform height |

## High-Confidence Findings

- Player steers the **ball**, not a paddle. Vertical bounce is automatic.
- Hold left/right half-screen acceleration with release damping.
- Horizontal world is toroidal; no wall bounce.
- Camera follows upward only, keeping the ball near 0.58 H, never centering it.
- Score tracks maximum world height, ~8 points/s while climbing, 554 at failure.
- Gravity and bounce impulse are constant; width and spacing tighten with height/score.
- Red platforms are used leftovers below the ball and remain landable.
- Failure is falling below the camera, after 554 has already frozen.

## Ambiguities

- This run almost never wraps, so wrap visuals (single clipped sprite vs dual copies) are not isolated. Dual copies are used when the disc overlaps an edge.
- Exact damping vs “release instantly zeros VX” is under-determined; residual coasting plus damping is the conservative fit.
- Early absence of red may be crop/occlusion rather than a score unlock. Implemented as “used → red” from the first landing.
- Score unit `0.038 H/point` is fitted to the 554 / ~72 s climb, not OCR on every frame.
- Platform X is random within a wrap-aware reach envelope; the source layout is not a fixed seed we can replay.
- A white hollow ring sits on the first high platform around t = 8 s (tutorial marker). Not reproduced.
- Whether a fallen ball can still be saved by a wrap-around platform that is still on-screen is not shown; failure uses a below-camera line with a small margin.

## Frame Measurements

See tables above. Bounce lock (~20 Hz) counted 167 hops; intervals inside 0.20–1.60 s have median 0.70 s. Ball radius mean 31.9 px. Red detections: 301 frames, t = 19.92…69.39 s, play-Y 0.53…0.99.

## Proposed Configuration

All compiled values live in `BloopyGameConfig.reference`. Physics is height/width-ratio based so iPhones feel alike. DEBUG seed `17602`. Auto-steer exists for late-game QA to 1000+.
