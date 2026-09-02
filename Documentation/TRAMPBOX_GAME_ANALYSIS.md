# Trampbox Reference Analysis

## Core Objective

Guide an automatically bouncing black ball onto the next yellow platform. Each successful landing advances the path and awards one point; missing the next platform ends the run.

## Player Controls

The instruction shown by the reference says to drag left or right. The recording contains no touch indicator, so it does not distinguish absolute finger tracking from relative drag conclusively. Ball motion is smooth, can reverse during a bounce, and is not visibly ballistic in X. The trainer therefore uses relative horizontal drag to update a target X, with a configurable maximum tracking speed.

## Ball Behaviour

The ball bounces without a tap. Its apparent diameter stays approximately 7–8% of the playable viewport width. Horizontal steering remains available throughout the airborne portion. The ball is normally kept in the lower-middle gameplay band while the path advances toward the viewer.

## Bounce Trajectory

The visible vertical motion is a smooth, approximately symmetric arc. Bounce height does not visibly grow with score. Duration changes strongly: early cycles are about 0.60–0.65 s and late cycles settle around 0.30 s. A deterministic parabola is a close, calibratable approximation:

`verticalOffset = bounceHeight * 4 * phase * (1 - phase)`

where `phase` advances from 0 to 1 over the current bounce duration.

## Platform Behaviour

Platforms form an advancing path. During a bounce, the path moves toward the camera; after a landing the landed platform becomes the departure platform and a new far platform enters near the horizon. Platforms that pass the ball continue down and leave the frame. This is closest to a controlled hybrid camera/world model, not a conventional vertical platformer.

## Platform Dimensions

The recording is 1180×2556. Inspection was performed on proportional 390×844 frame extractions. The unobscured gameplay viewport in those samples is about 345 px wide (x≈23…368). The black ball is about 26–28 px in diameter (7.5–8.1% of gameplay width).

At a comparable near-camera depth, visible platform top widths are approximately:

- Score ≈43: about 82 px, or 24% of gameplay width.
- Score ≈75: about 58–62 px, or 17–18%.
- Score ≈164: about 43 px, or 12–13%.

Depth changes apparent size substantially, so only platforms near the landing band were compared. Platform side faces are darker ochre and are roughly 8–15% as deep as the top-face width, depending on perspective and rotation.

## Platform Spacing

Usually 6–8 useful platforms are visible from the landing band to the horizon. Their screen-space vertical spacing contracts toward the horizon. Consecutive centers can alternate strongly: observed near/mid-field shifts reach roughly 40–45% of viewport width early, while late sequences tend to remain within the shorter distance reachable during a 0.30 s cycle.

## Platform Generation

The sequence appears varied rather than fixed. Repeated centers and left/right alternation both occur. No evidence supports intentionally impossible jumps. The trainer generator will be seeded for tests and will clamp every next center to the distance the ball can travel during that score's bounce.

## Perspective / Camera

The path recedes toward a horizon near the upper quarter of the gameplay viewport. Far platforms are about one third the apparent scale of near platforms. Near platforms have visibly deeper side faces. The ball stays in a comparatively stable lower-middle vertical zone while platforms advance by approximately one path spacing during every bounce.

## Scoring

The large centered number advances by exactly one at each successful landing. Score changes line up with the beginning of the next bounce. Implemented rule: one valid landing on the next platform equals +1.

## Failure Condition

At score 176 the ball fails to land on the next platform, drops below the playable area, and the game leaves gameplay. No other failure condition is visible. Empty drags and aggressive steering are not failures by themselves.

## Difficulty Progression

Two changes are explicit in the reference instruction and visible throughout the run:

- Bounce duration decreases.
- Platform width decreases.

OCR-assisted score samples from the 60.10 fps recording:

| Approximate score | Video time | Local time per point |
| ---: | ---: | ---: |
| 10 | 9.25 s | 0.60–0.65 s |
| 20 | 15.50 s | 0.58–0.63 s |
| 40 | 26.50 s | 0.50–0.53 s |
| 50 | 31.25 s | 0.47–0.50 s |
| 80 | 44.00 s | 0.38–0.42 s |
| 100 | 50.75 s | 0.33–0.36 s |
| 120 | 56.75 s | 0.29–0.32 s |
| 140 | 62.75 s | 0.29–0.31 s |
| 160 | 68.75 s | 0.29–0.31 s |
| 176 | 73.75 s | 0.29–0.31 s |

The evidence supports an approximately linear reduction followed by a floor, rather than continuing acceleration. The initial trainer curve is `max(0.30, 0.68 - 0.0033 * score)` seconds.

Platform measurements likewise support a linear-looking narrowing that approaches a floor. The initial trainer curve is `max(0.11, 0.25 - 0.0008 * score)` times viewport width.

## Starting State

The source clip cuts from a video gallery into a run already around its first few points, so the exact pre-start UI is not observable. The game itself starts from a ball resting on a near platform and proceeds automatically. The trainer uses the app's familiar countdown, then begins the first automatic bounce.

## Visual Feedback

Feedback is deliberately restrained: the score updates immediately and the platform path advances. There are no visible explosions or large particles on successful landings. Yellow top faces, darker side faces, the black ball, and a purple depth background provide the core readability.

## Game-Over Behaviour

The missed ball visibly falls away. The surrounding reference app then replaces gameplay with an attempt/continue screen. In MiniGame Trainer, the fall is retained briefly and then the shared Results screen is shown.

## High-Confidence Observations

- Automatic bouncing; no jump tap.
- Continuous left/right drag steering.
- Exactly +1 per successful next-platform landing.
- Missed platform and falling below the play area causes failure.
- Bounce cycles become faster with score and stop accelerating near 0.30 s.
- Platforms narrow substantially with score.
- The path advances toward the viewer and is perspective-scaled.
- The run reaches 176 before the miss.

## Assumptions / Ambiguities

- Touches are not rendered, so the precise reference transfer function is unknown. Relative drag-to-target is selected because it permits repositioning without requiring the finger to cover the ball.
- Platform rotations are visually present in the reference, but exact 3D orientation is not important to the steering skill. The trainer uses original, consistent pseudo-3D geometry rather than random tumbling.
- The source is embedded in a YouTube Short with overlays. Measurements use the visible gameplay viewport and carry a few pixels of uncertainty.
- The exact collision forgiveness cannot be measured from a single successful run. Ball-overlap collision with a configurable tolerance is the initial choice.
- The exact start and pre-game countdown are not present in the clip.

## Measurements From Video

- Source: 80.919 s, 1180×2556, nominal 60.098 fps.
- Gameplay is visible from roughly 3 s until the miss after score 176 at roughly 74 s.
- Score 18 at 14.25 s, 43 at 28.00 s, 75 at 42.00 s, 118 at 56.25 s, 164 at 70.00 s, and 176 at 73.75 s.
- Far platform scale is approximately 0.33–0.38 of near platform scale.
- Horizon lies near 22–25% of the gameplay height; the landing band is around 68–72%.
- Ball diameter is approximately 7.5–8.1% of gameplay width.
- Near platform width decreases from approximately 24% to approximately 12–13% of gameplay width over the sampled run.
- Approximately 6–8 forward platforms are simultaneously readable.

## Initial Configuration

The implementation starts from the measured relationships above: ball radius 3.7% of scene width, bounce duration 0.68→0.30 s, bounce height 21% of scene height, near logical landing width 25%→11% of scene width, horizon at 23% of scene height, landing band at 70%, far projected-width scale 0.40, eight forward platforms, and reachability-limited horizontal offsets. Visual top depth is projected independently from logical collision width and grows from 18% of projected width at the horizon to 54% at the landing band; the visible side grows from 5.5% to 14%.

# Implementation vs Reference Comparison

This comparison was added for the visual-fidelity pass. The original reference was resampled from its 1180×2556, 60.10 fps recording. Yellow-face connected components were measured on proportional 389×844 frames after excluding the YouTube controls; the useful gameplay viewport is approximately x=23…367 (344 px wide) and y=120…710 (590 px high). The new physical-play recording mentioned in the review request was not present in the attachment manifest, so implementation measurements use the supplied observation (thin-line platforms), the pre-pass simulator capture at 1206×2622, and the exact projection code. No measurements are attributed to an unavailable file.

## Early comparison (score approximately 7–10)

Reference frame at 7.24 s:

| Zone | Reference component | Width / viewport | Depth / viewport | Depth / width |
| --- | ---: | ---: | ---: | ---: |
| Far | 38×12 px | 11.0% | 2.0% | 0.32 |
| Upper-middle | 43×14 px | 12.5% | 2.4% | 0.33 |
| Middle | 59×25 px | 17.2% | 4.2% | 0.42 |
| Approach/landing | 91×55 px | 26.5% | 9.3% | 0.60 |
| Foreground | 104×111 px | 30.2% | 18.8% | rotated/tumbling |

The pre-pass implementation capture kept eight platforms, with widths from 9.4% to 24.5% of screen width, so horizontal sizing was broadly credible. Their total visible depths were only 0.5–1.3% of screen height and approximately 11% of width at every depth. The near reference block is roughly six times deeper on screen and changes aspect ratio strongly with depth.

## Mid comparison (score approximately 75)

Reference frame at 42.21 s:

| Zone | Reference component | Width / viewport | Depth / viewport | Depth / width |
| --- | ---: | ---: | ---: | ---: |
| Far | 21×6 px | 6.1% | 1.0% | 0.29 |
| Upper-middle | 31×12 px | 9.0% | 2.0% | 0.39 |
| Middle | 37×18 px | 10.8% | 3.1% | 0.49 |
| Approach | 46×26 px | 13.4% | 4.4% | 0.57 |
| Landing | 61×44 px | 17.7% | 7.5% | 0.72 |
| Foreground | 50×36 px, plus edge-on fragment | 14.5% | 6.1% | rotating out |

The unchanged logical width curve gives 19.0% at score 75 before depth projection, consistent with the measured landing width. The previous shared scalar made middle and far platforms narrow and line-like. The revised width curve uses a 0.40 far scale and exponent 0.90, while the top-depth ratio grows independently from 0.18 to 0.54.

## Late comparison (score approximately 164)

Reference frame at 70.18 s:

| Zone | Reference component | Width / viewport | Depth / viewport | Depth / width |
| --- | ---: | ---: | ---: | ---: |
| Far | 15×4 px | 4.4% | 0.7% | 0.27 |
| Upper-middle | 22×9 px | 6.4% | 1.5% | 0.41 |
| Middle | 27×12 px | 7.8% | 2.0% | 0.44 |
| Approach | 31×19 px | 9.0% | 3.2% | 0.61 |
| Landing | 41×30 px | 11.9% | 5.1% | 0.73 |
| Foreground | 50×43 px and 15×41 px | 14.5% | 7.3% | enlarged/rotated |

The unchanged width formula yields 11.9% at score 164, essentially matching the measured late landing width. This is strong evidence not to alter gameplay difficulty. The discrepancy was the visual depth and lifecycle.

## Ball apparent diameter

Across mid and late reference frames, the black ball is approximately 26–28 px across, or 7.6–8.1% of the 344 px gameplay width. The configured diameter is 7.4% of scene width. That is within measurement and crop uncertainty, so `ballRadiusRatio = 0.037` remains unchanged.

## Platform scale, spacing, and horizon

- Reference platform widths remain readable from roughly 4–11% at the far end, depending on score, and grow to roughly 12–27% at the landing band.
- Seven or eight distinct forward/active components can usually be separated.
- Reference gaps expand markedly toward the player. The pre-pass first-step spacing was 11.5% of screen height; it is now 15% while later gaps still converge exponentially toward the 23% horizon.
- Horizon and landing band remain at 23% and 70%; the recordings support those locations more strongly than changing them.
- Width, top depth, side depth, vertical position, and orientation now use separate projection functions rather than one non-uniform node scale.

## Platform orientation and foreground lifecycle

Incoming reference platforms have restrained, non-identical orientations. The active landing surface becomes visually stable at the landing band. After use, platforms cease being collision objects, enlarge toward 1.75×, travel 42% of screen height downward, drift 18% of screen width laterally, rotate approximately 105°, fade, and are removed. This produces the large oblique and nearly edge-on foreground blocks measured in all three score ranges without changing `TrampboxGameLogic` collision geometry.

## Before-pass implementation measurements

The pre-pass 1206×2622 simulator frame produced eight platform components:

```text
113×13, 119×13, 129×15, 143×16,
163×18, 191×22, 233×26, 295×34 px
```

Every platform stayed near an 0.11 depth/width aspect ratio. This quantitatively explains the reported thin horizontal lines. Reference depth/width grows from roughly 0.27–0.33 far away to 0.60–0.73 near the player, then becomes unconstrained as used slabs tumble.

## Post-pass simulator verification

The corrected build was run with DEBUG-only auto-steering and frozen 0.15 s after landings at scores 10, 80, and 160. Measurements below use the complete 1206×2622 SpriteKit viewport. Components are ordered from horizon to foreground; the final component in each row is the departing platform.

| Score | Corrected yellow components | Stable depth / width range | Reference range at comparable score |
| ---: | --- | ---: | ---: |
| 10 | 128×35, 135×40, 144×47, 160×57, 182×77, 208×98, 247×149, 286×198 px | 0.27→0.60 | 0.32→0.60 |
| 80 | 99×28, 103×30, 112×37, 122×43, 140×61, 164×82, 193×117, 219×152 px | 0.28→0.61 | 0.29→0.72 |
| 160 | 64×19, 68×20, 73×25, 81×31, 93×39, 110×58, 131×82, 144×100 px | 0.30→0.63 | 0.27→0.73 |

The former fixed 0.11 aspect ratio is gone. Far platforms remain compact but visibly planar, middle platforms read as rectangles, and the near/departing faces reach the reference's substantial slab range. Corrected far widths are 10.6% at score 10, 8.2% at score 80, and 5.3% at score 160; the corresponding reference samples are approximately 11.0%, 6.1%, and 4.4%. Corrected near/departing widths are 23.7%, 18.2%, and 11.9%, compared with approximately 30.2%, 14.5–17.7%, and 11.9–14.5% in the sampled reference phases. Variation is expected because a platform continuously advances during each bounce and the foreground component is already rotating.

All three captures retain seven to eight readable yellow forms from horizon through departure. The score-10 and score-80 captures show the used block enlarged, rotated, and moving toward a lower side; the score-160 capture shows it partly leaving the bottom-right edge. The ball diameter remains 7.4% of viewport width, versus the measured reference range of 7.6–8.1%. These checks support preserving ball size and both gameplay difficulty curves.
