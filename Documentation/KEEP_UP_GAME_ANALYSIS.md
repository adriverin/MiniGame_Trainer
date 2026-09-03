# KEEP UP Reference Analysis

## Source and method

Primary source: `ScreenRecording_09-02-2026 16-34-51_1.MP4` (1180 × 2556 HEVC screen recording, 35.213 s, nominal 60 fps / 2,117 video frames). The recording contains a YouTube Shorts player around the game. All measurements below ignore the player chrome and use the approximately 1040 × 1640 px gameplay rectangle at source coordinates x = 70...1110 and y = 540...2180.

The video was inspected as one-second and four-frame-per-second contact sheets, individual native frames, and a 30 Hz computer-vision track. The track segmented the white ball and gray platform, then located vertical trajectory reversals. Source frames repeat occasionally and the score can occlude the ball near the apex, so values are rounded and should not be treated as sub-pixel ground truth.

# Fidelity Correction — 2D Platform and Upper Boundary

The earlier fixed-Y implementation was based on the written “left and right” instruction instead of the stronger visual evidence. That assumption is now withdrawn. Across the active run, the platform center moves from approximately y = 1973 px at entry to y = 1636 px at the first catch and spans roughly y = 1241...2017 px while the score and the playfield frame remain stationary. Its x center spans approximately 140...1002 px. The motion is therefore genuine two-dimensional platform control, not camera motion or an apparent change caused by the ball.

The corrected control model directly maps the active touch position to the platform center in both axes. The center is clamped to x = 0...viewport width and y = 0...0.55 viewport heights in the trainer's full-screen SpriteKit coordinates. Clamping the center rather than the circle frame intentionally permits the platform to be partially clipped at the left, right, and bottom edges, as seen in the source. The 0.55 upper center limit is slightly above the highest observed source position (about 0.514 full-screen heights from the bottom), while the reference start y = 0.225 matches the observed entry center (about 0.228).

# Fidelity Correction — Ceiling Is a Physical Wall

The previous conclusion that the upper horizontal line is a “visual divider — not a physical ceiling” is withdrawn. Sequential native-frame tracking of the original score-41 recording shows repeated contacts in which the **top of the ball meets the underside of the line** and **VY reverses** in the same step. The earlier “apex below the line” table was an occlusion artifact: the central score hides the ball at the true contact Y, duplicate source frames flatten the 60 fps track, and several quoted sequences never sampled the actual contact frame.

The line geometry is unchanged and is now **both** the rendered stroke and the logical ceiling. In a representative unobscured frame the antialiased stroke occupies source y = 527...531 px (center y = 530, thickness 5 px, underside y = 532.5) and x = 92...1085 px: at 0.793 full-screen heights from the bottom, with an 0.080-width horizontal inset. Center-row sample is approximately RGB (216, 218, 230) over (32, 35, 44), consistent with white at roughly 0.84 opacity. Collision occurs when `ballCenterY + ballRadius` reaches this underside. The trainer uses one value `upperLineY` / `ceilingY` for drawing and physics; legal ball-center maximum is `ceilingY - ballRadius`.

Clean vertical encounters (unique frames, ball top flush with the line):

| Score ~ | Platform contact | Ceiling contact | Next catch | Up | Down | Ball top at contact | Incoming VY (src, +down) | Outgoing VY | VX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 2 | 4.100 s | 4.481 s | 4.800 s | 0.381 s | 0.319 s | 532 px | −2164 px/s | +2433 px/s | ≈ 0, preserved |
| 20 | 17.733 s | 18.190 s | 18.623 s | 0.457 s | 0.433 s | 532 px | −5767 px/s | +4724 px/s | large, same sign |
| 35 | 29.167 s | 29.450 s | 29.733 s | 0.283 s | 0.283 s | 532 px | noisy late-game | noisy | wall-contaminated |

There is no pause, no flattening of the ball, and no randomized deflection. Horizontal velocity is unchanged at the ceiling unless a side wall is also nearby. Residual upward speed at contact is clearly non-zero, so this is a rebound rather than a gravitational apex. Raw |out|/|in| on the cleanest vertical hit is order-one; gravity across duplicate frames accounts for the apparent 0.84–1.12 scatter. Restitution is therefore **1.0** (elastic). Ceiling contact never increments score.

The previous gravity `3.4 H/s²` and impulse `1.76 H/s` were fitted so a **ballistic** apex would sit near the line **without** a wall. Unique-frame second differences on the score-2 rise (before contact) give g ≈ 1.05 H/s² of full-screen height. Compiled values are `gravityHeightRatio = 1.15` and `bounceImpulseHeightRatio = 1.52`, which from the default platform Y produce platform→ceiling ≈ 0.37 s with leftover speed at the line, matching the early ceiling cadence rather than an artificial apex.

Score-grouped platform→ceiling times do **not** support a simple acceleration curve: later intervals shrink while travel distance and horizontal speed both explode, and many late contacts are wall/side-of-platform chains. Physics stay constant with score.

Collision is also corrected for the moving platform. Each physics step sweeps the ball's previous/current center against the platform's previous/current center in relative space. A contact is valid only on the configured upper-facing arc, inside the effective horizontal catch span, and while relative motion approaches the contact normal. This admits a platform moving upward into a ball and a platform crossing a genuine ball trajectory, while rejecting lower-face contacts, separating motion, and equatorial sideways sweeps. Output horizontal velocity remains the measured impact-offset response. Platform velocity transfer is independently configurable in X and Y but defaults to zero because the recording does not isolate a reliable transfer coefficient. Visual viewport clipping never truncates the logical platform: collision always uses its full circle. Adding the ceiling does not remove this sweep.

Ceiling reflection preserves overshoot: remaining time after contact is integrated with reversed VY rather than clamping `ballY = ceiling - radius` and discarding excess motion. Failure still occurs only after the entire ball leaves below the viewport, and platform collision is evaluated first, so a catch by a low, partially clipped platform remains valid.

## High-confidence findings

- One descending ball contact increments the displayed score by exactly one. The demonstrated run reaches 41.
- A miss ends the run. There is no 15-second hard stop: active play spans approximately 30 seconds in this recording.
- The ball follows gravity between contacts and **rebounds from the upper horizontal line**. That line is a physical ceiling, not a cosmetic divider. The previous visual-divider conclusion is superseded.
- The ball reflects at the left and right playfield edges. Detected ball-center extrema are x ≈ 106 and x ≈ 1051 px, consistent with a 31 px radius inside x = 70...1110.
- Bounce direction is controlled by signed impact offset. Near-center catches become nearly vertical; a ball right of platform center leaves rightward and a ball left of center leaves leftward, subject to immediate wall reflections.
- The large platform is a true circle, approximately 263 px in diameter. The ball is approximately 62 px in diameter.
- The trail is historical motion, not a static guide: dots follow the previous arc and age from larger/brighter near the ball to smaller/dimmer farther back.
- The score remains fixed in the upper-middle region and there is no camera scrolling.

## Resolved platform-Y finding

The instruction copy says to drag left and right, but the visible platform center changes from approximately y = 1973 px at game entry to y = 1636 px at the first catch and later ranges roughly y = 1241...2017 px. The score and playfield border remain fixed, so this cannot be explained by a global camera shift.

Frame-by-frame inspection shows coordinated, direct-looking X/Y repositioning before catches. The corrected trainer therefore follows the video rather than the shorthand instruction copy and accepts two-dimensional dragging.

## Geometry measurements

| Item | Source measurement | Gameplay-width ratio | Notes |
|---|---:|---:|---|
| Gameplay viewport | ≈1040 × 1640 px | 1.000 | YouTube chrome excluded |
| Platform diameter | 262...264 px (median 264) | 0.252...0.254 | Constant when unobscured; occasional clipped/merged detections discarded |
| Ball diameter | 61...64 px | 0.059...0.062 | White circular body; median segmentation area ≈3,070 px² |
| Ball/platform diameter | ≈0.235 | — | Ball is just under one quarter of platform diameter |
| Platform center X | ≈140...1002 px | local 0.067...0.896 | Source sometimes permits slight visual clipping |
| Platform center Y | ≈1241...2017 px | full-screen bottom-origin 0.211...0.514 | Visibly variable; establishes genuine Y control |
| Ball center X | ≈106...1051 px | local 0.035...0.943 | Supports side-wall reflection |
| Ball center Y | visible ≈607...1881 px | top-origin 0.041...0.818 | Apex is sometimes hidden by the score |

The compiled trainer uses the measured 0.254 platform diameter and 0.060 ball diameter. The center starts at (0.500, 0.225), tracks touch X/Y, and is center-clamped to x = 0...1.0 and y = 0...0.55, allowing intentional edge clipping.

## Bounce measurements

Coordinates and velocities are source-video pixels and seconds. `Offset` is `(ballX - platformX) / 132 px`. Velocity fits use about 0.15 s on each side of contact. A `wall` note means the outgoing fit is contaminated by a nearby reflection; values remain useful for direction/speed context, not coefficient fitting.

| Bounce / score | Impact time | Ball X | Platform X | Offset | Incoming VX | Outgoing VX | Next bounce |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2.567 | 746 | 760 | -0.109 | +322 | -205 | 1.533 s |
| 2 | 4.100 | 414 | 418 | -0.035 | -242 | ≈0 | 0.700 s |
| 3 | 4.800 | 414 | 378 | +0.273 | ≈0 | +336 | 0.600 s |
| 4 | 5.400 | 685 | 719 | -0.263 | +463 | -549 | 0.600 s |
| 5 | 6.000 | 372 | 360 | +0.088 | -605 | +310 | 0.633 s |
| 15 | 13.200 | 607 | 456 | +1.143 | +1727 | -2747 (wall/side-contact ambiguity) | 0.400 s |
| 17 | 15.200 | 678 | 680 | -0.020 | +554 | -175 | 0.833 s |
| 18 | 16.033 | 530 | 532 | -0.010 | -158 | +53 | 0.867 s |
| 19 | 16.900 | 571 | 527 | +0.333 | +44 | +723 | 0.833 s |
| 20 | 17.733 | 972 | 907 | +0.496 | -109 | +42 (right wall) | 0.867 s |
| 30 | 25.567 | 720 | 668 | +0.397 | -2166 | +1542 | 0.666 s |
| 31 | 26.233 | 226 | 368 | -1.075 | -1734 | +2519 (left wall/side-contact ambiguity) | 0.800 s |
| 32 | 27.033 | 147 | 264 | -0.890 | -3069 | +3196 (left wall) | 0.834 s |
| 35 | 29.167 | 556 | 445 | +0.839 | +1339 | +2464 | 0.566 s |
| 36 | 29.733 | 678 | 734 | -0.424 | not reliable | -426 | 0.500 s |
| 37 | 30.233 | 466 | 393 | +0.558 | -486 | +2304 | 0.567 s |
| 38 | 30.800 | 620 | 538 | +0.623 | -1867 | +1467 | 0.467 s |
| 39 | 31.267 | 863 | 786 | +0.578 | -602 | +86 (right wall) | 0.433 s |
| 40 | 31.700 | 416 | 539 | -0.938 | -1808 | -1706 | 0.433 s |
| 41 | 32.133 | 545 | 574 | -0.222 | +1754 | not visible before result | — |

The cleanest coefficient evidence is bounces 2–5: offset -0.035 gives an almost vertical departure, +0.273 gives a clear rightward departure, -0.263 gives a similarly sized leftward departure, and +0.088 gives a weaker rightward departure. The trainer therefore uses a symmetric deterministic power function (linear at the compiled default), replaces rather than preserves incoming horizontal velocity, and defaults both platform-velocity transfer coefficients to zero. Platform motion still participates in collision detection through relative sweep.

## Representative trajectory arcs

The apex is the highest reliably visible detected ball point. `Y` uses source top-origin coordinates, so a smaller value is higher. The central score obscures some true apexes.

| Arc | Start | Visible apex | End | Horizontal displacement | Duration | Maximum visible height |
|---|---|---|---|---:|---:|---:|
| 1 → 2 | (746,1454) @ 2.567 | (665,850) @ 2.967* | (414,1209) @ 4.100 | -332 px | 1.533 s | y=850* |
| 2 → 3 | (414,1209) @ 4.100 | (414,859) @ 4.667* | (414,1114) @ 4.800 | +1 px | 0.700 s | y=859* |
| 3 → 4 | (414,1114) @ 4.800 | (466,900) @ 4.933 | (685,1108) @ 5.400 | +270 px | 0.600 s | y=900 |
| 17 → 18 | (678,1517) @ 15.200 | (583,878) @ 15.733* | (530,1683) @ 16.033 | -147 px | 0.833 s | y=878* |
| 19 → 20 | (571,1805) @ 16.900 | (842,663) @ 17.267* | (972,1803) @ 17.733 | +401 px | 0.833 s | y=663* |
| 29 → 30 | (589,1832) @ 24.767 | (346,841) @ 25.067* | (720,1823) @ 25.567 | +131 px net (wall) | 0.800 s | y=841* |
| 35 → 36 | (556,1881) @ 29.167 | (939,716) @ 29.400* | (678,1874) @ 29.733 | +122 px net (wall) | 0.566 s | y=716* |
| 38 → 39 | (620,1754) @ 30.800 | (909,664) @ 31.033* | (863,1720) @ 31.267 | +243 px net (wall) | 0.467 s | y=664* |
| 40 → 41 | (416,1865) @ 31.700 | (223,622) @ 31.933* | (545,1682) @ 32.133 | +130 px net (wall) | 0.433 s | y=622* |

`*` likely not the true apex because the score overlaps the ball or the track loses the ball briefly.

## Timing, progression, and source-rate uncertainty

The first scored catch occurs around 2.567 s and score 41 around 32.133 s. Identifying ceiling contacts separately from platform catches shows that many previously quoted “bounce durations” were actually platform→ceiling→platform trips. Early clean vertical ceiling cadence is about 0.32–0.38 s each way. Later raw catch-to-catch intervals shrink, but platform height, horizontal speed, wall chains, and source-frame duplication all move at the same time. That is not enough evidence for score-based gravity or impulse acceleration.

The trainer therefore uses constant gravity, bounce impulse, ceiling restitution, platform size, catch radius, and horizontal response at every score. Difficulty emerges from player-created impact offsets and resulting wall-reflected trajectories.

## Control model

No finger indicator is visible. Platform X and Y can each change by hundreds of pixels over short intervals without observable easing, which supports direct/absolute positioning more than velocity steering. The implementation uses:

`desiredPlatformCenter = (clamp(touchX, 0, width), clamp(touchY, 0, 0.55 × height))`

`actualPlatformCenter = desiredPlatformCenter`

Relative finger delta is not accumulated. Touch samples also provide two-axis platform velocity telemetry; transfer into the outgoing ball is configurable but disabled by default because impact-offset and platform-velocity effects cannot be separated confidently in the video.

## Collision model

Full circle-circle elastic collision would permit lower-side bounces that do not match the reference. The trainer transforms both swept segments into platform-relative space and intersects the relative ball-center segment against the Minkowski-expanded platform circle (`platformRadius + ballRadius + tolerance`). It accepts only an approaching contact on the upper-facing arc and additionally requires the relative ball center to be within the effective catch radius. This prevents tunneling, separating/repeat contacts, lower-side bounces, and phantom equatorial catches while allowing valid catches created by platform motion.

## Trail measurements

Representative frames show approximately 10–16 visible dots. On a clear vertical rise near the ceiling, the first ghost behind the ball samples at about 0.50–0.55 opacity against the dark field and the oldest still-visible ghosts remain around 0.35–0.40 — readable trajectory marks, not a near-zero fade. Newest ghosts are roughly 0.4–0.5 ball diameters; oldest about 0.2. Spacing is temporal: gaps expand as the ball accelerates. The compiled defaults sample every 0.050 s, retain at most 16 samples for 0.880 s, scale 0.520 → 0.220, and fade from 0.580 opacity to 0.240. Trail data never participates in physics.

## Initial and terminal state

- Gameplay appears without a countdown; at about 1.97 s the score is 0 and the ball is already descending.
- The detected initial ball center is approximately (597,1023) px, then moves down/right toward the first catch.
- The platform is initially near (0.50 width, 0.225 height from the bottom) before the demonstrated player moves it in both axes.
- After score 41 the video transitions to external result UI. The exact game-owned miss animation and hold duration cannot be isolated.

## Confidence summary

High confidence: object proportions, one-point scoring, one-miss failure, gravity plus an elastic physical ceiling at the visible upper line, impact-offset steering, two-dimensional direct-feeling platform control, side-wall reflection, bounded historical trail, stable camera, and no hard 15-second timer.

Ambiguous: exact collision forgiveness, exact gravity/impulse (source frames duplicate and the score occludes some contacts), exact impact curve, whether late-game speed-up is native progression or video/player effects, the source's precise control bounds beyond the observed run, and the precise result delay. Platform and ball fills are nearly flat on JPEG samples, with only restrained radial volume added to match the live reference’s slight disc shading.
