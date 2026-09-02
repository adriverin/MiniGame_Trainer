# Piano Reference Analysis

Source: `ScreenRecording_09-01-2026 21-04-47_1.MP4` (42.9 s, 1180 × 2556 px, 60 Hz container with
~30 unique frames per second). The recording shows the YouTube Shorts player; only the game footage
inside the player was analysed. The game itself runs from t ≈ 3.73 s (first movement) to t ≈ 40.61 s
(freeze + red flash), i.e. ~36.9 s of play ending with a score of 157.

Method: frames were extracted with AVFoundation at 10 fps for the whole run and at 30–60 fps for
the start, one mid-game window and the game-over window. A script sampled the luminance along each
of the 4 lane centres to find white-tile edges frame by frame, giving tile heights, row pitches, speed
per second and the full lane sequence (141 rows). Screenshots were used to confirm colours, text and
layout.

Coordinate note: the Shorts player crops the source video. Measured lane pitch is 307 px while the
displayed video is 1180 px wide (4 × 307 = 1228), so the source is shown at ≈1.04× and clipped by
~24 px per side horizontally and, assuming the same scale, ~181 px top and bottom vertically. All
ratios below are therefore expressed relative to the *reconstructed source screen*: width 1228 px,
height ≈ 2662 px. This is an assumption; it changes the vertical ratios by a few percent at most and
every affected value is a configuration constant.

## Game Area

- Full-screen very dark purple background, RGB (26, 12, 51) ≈ `#1A0C33`.
- Tiles are drawn inside a clipped "playfield" that starts at a hard horizontal edge at
  y ≈ 310 px in the recording (≈ 491 px in source coordinates) → **playfield top ≈ 0.184 of screen
  height**. Tiles entering from above are clipped at this line; the background continues above it.
- No lane divider lines, no bottom bar, no other decoration is visible.
- The score is drawn centred horizontally, overlapping the top row of tiles: glyph box spans
  y = 390–513 px in the recording (≈ 0.214–0.261 of source height). Cap height ≈ 0.046 of screen
  height → bold system-like font of roughly 0.064 × screen height (~54 pt on a 852 pt tall iPhone).
  White text with a soft dark shadow so it stays readable over white tiles.

## Number of Lanes

- **4 lanes**, spanning the full screen width. Measured tile x-extents at one row: lane 1 = 286–586,
  lane 2 = 593–893 → lane pitch 307 px, tile width 300 px, seam 7 px.
- Lane usage over 141 rows is roughly uniform.

## Tile Dimensions

- Tile height: 502 px; row pitch (top of one row to top of the next): 509 px, consistently across the
  whole run (e.g. rows at 411 / 920 / 1429).
- Ratios (source coordinates): **row pitch ≈ 0.191 of screen height, tile height ≈ 0.189**,
  tile width ≈ 0.977 of lane width. Seam of ~7 px (≈ 2.3 % of lane width) between neighbouring tiles
  both horizontally and vertically.
- Tile aspect ratio (h / w) ≈ 1.67.
- Corners are square (≤ 1–2 px radius, i.e. none).
- Flat fill, no gradient or border: RGB (237, 237, 242) ≈ `#EDEDF2`.

## Tile States

1. **Active**: white tile, full opacity.
2. **Hit** (tapped): in the very next frame the tile drops to a faint translucent state. Measured
   colour over the background: (50, 48, 68) immediately after the tap → (34, 23, 57) after ~0.2 s and
   then constant. Interpreted as white at α ≈ 0.11 easing to α ≈ 0.04. The ghost keeps scrolling at
   the same speed and remains visible until it leaves the screen (ghosts are visible in the bottom
   rows of many frames). No scale, particle, or movement change.
3. **Missed**: only observed once, at game over (see Failure Condition). The whole screen flashes
   red and everything freezes; there is no special per-tile highlight distinguishable in the frames.

## Tile Movement

- Direction: top → bottom.
- Continuous motion; positions advance every frame with constant velocity between taps (e.g. 78, 111,
  95, 95, 79, 103, 95, 87, 111 px per 0.1 s at t ≈ 5 s; the jitter is screen-recording frame timing).
- Rows are contiguous: the top of row *n+1* is always 509 px above row *n*. There are no empty rows
  and no gaps, so spawn timing is fully determined by the speed (spawn interval = row pitch / speed).
- Speed measured per second (median of frame-to-frame deltas, px/s in recording coordinates) with the
  estimated score at that time:

  | t (s) | score | px/s |  | t (s) | score | px/s |
  |---|---|---|---|---|---|---|
  | 4 | 3 | 935 |  | 23 | 61 | 1920 |
  | 6 | 6 | 1000 |  | 26 | 74 | 2175 |
  | 9 | 13 | 1090 |  | 29 | 90 | 2429 |
  | 12 | 21 | 1210 |  | 32 | 106 | 2753 |
  | 15 | 31 | 1480 |  | 35 | 125 | 3000 |
  | 18 | 43 | 1575 |  | 38 | 146 | 3320 |
  | 21 | 53 | 1790 |  | 39 | 153 | 3105 |

- Least-squares fit: **v = 913 + 16.0 × score px/s** (RMS 92 px/s). A linear-in-time fit is clearly
  worse (RMS 122) because taps/s increases over time; a score-linear model matches best.
- In device-independent units: v ≈ **0.343 + 0.0060 × score screen-heights/s**, or
  1.79 + 0.0314 × score rows/s. At score 0 a row takes ≈ 0.56 s to travel one row pitch; at 150
  ≈ 0.15 s.
- No plateau/maximum speed is visible up to score 157.

## Spawn Pattern

- Rows spawn continuously above the playfield so that the column never has a gap.
- Initial state (before the first tap): two rows are pre-placed and stationary — the lowest row's top
  ≈ 0.86 row heights below the playfield top (bottom ≈ 1.86 rows down), the row above it is partly
  clipped. Movement begins on the first tap (see Timing).
- Each row contains **one white tile**, or **two white tiles in different lanes** ("double row").
  - Double rows never appear in the first 15 rows; afterwards 19 of 126 rows (≈ 15 %) are doubles.
    Frequency does not clearly ramp further (16 % / 10 % / 20 % in thirds).
  - Both tiles of a double row must be tapped; each is worth 1 point.
  - Two consecutive double rows occur (rows 19–20, 74–75, 138–139).
- Lane rules observed over 141 rows:
  - A single tile is **never** in the same lane as the previous row's single tile (0 of ~110
    single→single transitions).
  - Double rows are unrestricted: they can include the previous row's lane (7 of 19 do).
  - A single row after a double row can reuse one of the double's lanes (5 of 16).
  - Consistent model: pick a *primary* lane ≠ previous primary lane; with probability *p* add an
    *extra* lane uniformly from the remaining three lanes. The primary lane is what the next row
    avoids.
- Up to 4 rows (3.4 row pitches of playfield) are visible; with doubles that is up to ~7 tiles.

## Scoring

- Each tapped tile = **+1**. Verified by frame pairs (e.g. 155 → 157 across one interval in which two
  tiles were consumed) and by counting vanishing tiles per frame, which reproduces the displayed
  3 (t=5 s) and 153 (t=40 s) exactly.
- Score is shown immediately, centred at the top, large bold white.
- After game over the platform shows "157 PUNTOS" (raw score) and separately "119 Puntos – Top 1 %
  mundial" (a platform-level reward that is not part of the game and is not reproduced).

## Failure Condition

- In-game description (translated): "White tiles move downward – tap each one before it exits at
  the bottom. If you miss a tile or tap empty space, it's over!" → **first mistake ends the game**;
  no lives, no timer.
- Observed end: at t = 40.61 s the scene freezes and the background flashes red (26,12,51 →
  74,10,41, fading back over ~0.6 s), then a game-over overlay appears ~0.7 s later. At the freeze,
  the lowest untapped white tile's bottom edge is at y = 2037 px (recording) ≈ 0.833 of source screen
  height. The last successful tap (0.12 s earlier) was on a tile whose bottom was ≤ 2030 px. The
  four other white tiles above it were also untapped (the player had fallen behind at ~6.5 rows/s).
- Interpretation: a tile is **missed when its bottom edge crosses a miss line at ≈ 0.833 of the
  screen height**. This is the most defensible reading; a "wrong tap" cause cannot be excluded
  because touches are not visible in the recording. Both the line position and the rule are
  configurable.

## Difficulty Progression

- Speed: linear in score (see Tile Movement). Implemented as
  `speed = min(initialSpeed + score × speedIncreasePerPoint, maximumSpeed)` in screen-heights/s.
- Spawn rate follows speed automatically (contiguous rows).
- Double rows unlock at ~row/score 15 with ≈ 15 % probability afterwards.
- No other progression (no lane count change, no tile size change) is visible.

## Timing

- Ready screen ("Toca las teclas" – "Tap the keys") with the two initial rows already visible,
  a pulsing white dot hint on the lowest tile and the score "0". Tiles are stationary.
- Movement starts on the first tap (t ≈ 3.73 s). The first tile was consumed 0.76 s later, so the
  starting tap did not consume a tile (or was not on one).
- Hit → ghost transition happens within one recorded frame (≤ 33 ms); no input lag visible.
- Game over: instantaneous freeze + red flash; overlay ~0.7 s later.
- No countdown in the reference. (The trainer adds a 3-2-1 countdown before the ready state per the
  product spec; it can be disabled in DEBUG.)

## Visual Feedback

- Successful tap: immediate opacity drop of the tile (see Tile States). No sound could be evaluated
  (recording audio was not analysed; the trainer uses original simple sounds/haptics, off by
  default for sound).
- Game over: full-screen red tint flash.
- Score text updates instantly.

## Unknown / Ambiguous Behaviors

| Topic | What is unknown | Trainer default | Config key |
|---|---|---|---|
| Miss line | Exact y; depends on Shorts crop assumption | 0.833 of scene height, tile bottom edge | `missLineRatio`, `missRule` |
| Wrong tap | Whether tapping a ghost tile counts as empty space | yes → game over | `consumedTileTapEndsGame` |
| Taps above playfield | Whether tapping the header area fails | ignored | `ignoreTapsOutsidePlayfield` |
| Tap order | Whether an upper tile may be tapped before a lower one | allowed | `requireLowestRowFirst` |
| Double unlock | Score vs row based, exact threshold | score ≥ 15 | `doubleTileUnlockScore` |
| Double probability | 15 % ± 5 % | 0.15 | `doubleTileProbability` |
| Max speed | No plateau observed to score 157 | 2.0 screen-heights/s (≈ score 276) | `maximumSpeed` |
| Start tap | Whether the start tap can also hit a tile | starts only | `startTapConsumesTile` |
| Vertical ratios | Crop offset of the Shorts player (±0.02) | as measured | `playfieldTopRatio`, `rowHeightRatio` |

## Initial Estimated Configuration

```text
laneCount                 = 4
rowHeightRatio            = 0.191   (of scene height; tile height = row − seam)
tileWidthRatio            = 1.0     (of lane width; seam subtracted)
tileSeamRatio             = 0.023   (of lane width; horizontal and vertical seam)
playfieldTopRatio         = 0.184   (of scene height; tiles clipped above)
missLineRatio             = 0.833   (of scene height; tile bottom crossing = miss)
initialSpeed              = 0.343   (scene heights / s)
speedIncreasePerPoint     = 0.0060  (scene heights / s per point)
maximumSpeed              = 2.0     (scene heights / s)
initialRowCount           = 2
initialLowestRowTopOffset = 0.86    (row heights below playfield top)
doubleTileUnlockScore     = 15
doubleTileProbability     = 0.15
pointsPerTile             = 1
endCondition              = firstMistake
hitTileInitialOpacity     = 0.11
hitTileRestingOpacity     = 0.04
hitTileFadeDuration       = 0.20 s
gameOverFlashDuration     = 0.60 s
gameOverHoldDuration      = 0.80 s
scoreCenterYRatio         = 0.2375 (of scene height)
scoreFontSizeRatio        = 0.064  (of scene height)
countdownDuration         = 3 s (trainer addition, 3-2-1-GO)
```
