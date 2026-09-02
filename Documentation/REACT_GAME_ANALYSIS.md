# REACT Reference Analysis

## Core Objective

REACT is a visual reaction-time test. One target in a 3 × 3 field illuminates after an unpredictable delay. The player taps that target; the session score is the arithmetic mean of the successful reaction times. Lower is better.

## Grid Geometry

The recording is 1180 × 2556 and contains a portrait 60 Hz screen recording of a YouTube Short. Measurements below use the full video width while ignoring YouTube controls and creator overlays. In a clean app viewport, ratios are more transferable than the captured pixel positions.

- Columns are centered at approximately x = 326, 589, and 852 px.
- Rows are centered at approximately y = 1095, 1357, and 1619 px in screen-down recording coordinates.
- Center-to-center spacing is approximately 263 px horizontally and 262 px vertically.
- The inactive grid bounds are approximately x = 210...968 and y = 980...1734 px.
- Grid width / video width: 758 / 1180 = 0.642.
- Grid center X / video width: 589 / 1180 = 0.499.
- Grid center Y / full recording height: 1357 / 2556 = 0.531 from the top (0.469 from the bottom).

Confidence: high for captured pixels and width ratios; medium for transferring vertical position because the Short is overlaid by YouTube chrome.

## Circle Dimensions

Thresholding the inactive blue fill produces circle bounds of roughly 230...232 px. The implemented diameter ratio is therefore based on 232 / 1180 = 0.1966. Adjacent edge gap is about 31 px, or 0.134 circle diameters. The active target pulses from approximately 232 to 248 px during its first ~100 ms, then returns toward the inactive diameter; the color change itself is immediate.

Confidence: high.

## Grid Position

The grid is horizontally centered. Its captured center is slightly below the full recording midpoint and clearly below the instruction text. The trainer uses full-viewport geometry and a center-Y ratio measured from the bottom so it scales across iPhones.

Confidence: high for horizontal centering; medium for clean-viewport vertical calibration.

## Inactive State

Inactive targets are opaque dark blue/charcoal circles against a nearly black, slightly warm background. Representative decoded center colors are approximately RGB(39, 51, 61) for the circles and RGB(27, 23, 27) for the background.

Confidence: high, allowing for video compression.

## Active State

The active target changes immediately to bright turquoise/mint. A representative decoded active fill is approximately RGB(94, 209, 192). A small size pulse is present, but there is no evidence of a perception-delaying fade-in. The trainer prioritizes a single-frame color onset synchronized with its reaction timestamp.

Confidence: high.

## Round Flow

The observed flow is instruction cue → inactive grid/wait → one active target → tap → immediate reset and per-round time → next randomized wait. The small previous-round time remains around the grid during much of the next wait and disappears when the next target illuminates.

Confidence: high.

## Random Waiting Time

Detected active-target onsets are 3.6117, 5.3083, 8.9683, 10.3333, and 13.9100 s in the supplied recording. Using the displayed reaction results to estimate tap times gives subsequent tap-to-stimulus waits of approximately 1.42, 3.42, 1.05, and 3.29 s. The first grid becomes fully available at roughly 2.6 s, giving a first wait near 1.0 s.

The small sample supports a broad random interval but cannot identify a distribution. A continuous uniform distribution is the least complex defensible default. The initial trainer range is 1.0...3.5 s, which brackets the observed waits closely. There is no evidence that the first round uses a different range. Subsequent waiting appears to begin immediately after the tap; feedback does not add a fixed delay before random waiting.

Confidence: medium for the approximate range and immediate restart; low for the exact endpoints and distribution.

## Reaction-Time Measurement

The five displayed values are 273, 239, 312, 290, and 326 ms. Their exact arithmetic mean is 288 ms, matching the final screen. Video frames alone cannot reveal the source app's clock primitive. The trainer uses a monotonic high-resolution timestamp and never derives time from frames.

Confidence: high for displayed values and average; no direct evidence for the reference clock API.

## Touch Behaviour

The successful run shows only correct single touches. It contains no premature touch, wrong-target touch, multi-touch, or rapid-spam example. Therefore reference behavior for invalid input is unknown. The trainer defaults to restarting the current randomized wait after an early or wrong touch, records the invalid action, and evaluates only one touch for a stimulus. This preserves valid-round measurement without rewarding anticipation.

Confidence: inferred trainer policy, not a reference observation.

## Per-Round Feedback

Each successful tap immediately returns the target to inactive and shows a compact result such as `273 ms` near the right side of the grid. The value remains visible during the following wait and is replaced by the next result. There is no evidence that feedback blocks scheduling of the next random delay.

Confidence: high for content and overlap with waiting; medium for exact fade timing.

## Number of Rounds

The actual demonstrated session contains five successful rounds. The trainer default is therefore configurable `roundCount = 5`.

Confidence: high.

## Final Score

Final score is the full-precision mean of the round reactions, rounded only for millisecond display. For the reference sample: `(273 + 239 + 312 + 290 + 326) / 5 = 288 ms`.

Confidence: high.

## Failure / Invalid Input Behaviour

Not demonstrated. No leaderboard or percentile behavior is inferred. Early and wrong touches are explicit configurable rules in the trainer. The initial rule restarts the same valid round after a fresh random wait; an optional debug penalty rule can record a configured penalty duration and advance the round.

Confidence: unknown reference behavior.

## Results Presentation

The reference lists all five rounds, then a large `PROMEDIO 288 ms`. It subsequently presents unrelated competitive/ranking screens. The trainer reuses the generic result screen, labels the primary value `Average`, includes the `ms` unit, and reports objective metrics only.

Confidence: high.

## High-Confidence Observations

- Exactly one of nine circular targets is active at a time.
- The targets form a regular 3 × 3 grid.
- Active onset is a strong turquoise/blue contrast change.
- Reaction results are expressed as integer milliseconds.
- The active target resets immediately after a successful tap.
- Five results are collected in the demonstrated run.
- Lower average reaction time is better.
- The five displayed values average to exactly 288 ms.

## Ambiguities

- Exact random-delay endpoints and probability distribution.
- Whether the first-round delay uses a distinct distribution.
- Early, wrong, simultaneous, and spam-touch rules.
- Whether immediate target-position repeats are prevented.
- Exact lifetime/fade curve of per-round text.
- Whether the subtle active-target pulse is intentional game animation or partly capture/display behavior.

## Reference Contradictions

The Spanish instruction text says the average is calculated after **3 rounds**, while the actual gameplay and result list visibly contain **5 rounds**. This is not resolved by the clip. The trainer keeps the count configurable and defaults to 5 because that is the demonstrated behavior.

## Video Measurements

Source: HEVC Main, 1180 × 2556, nominal 60 fps, 1310 frames, 21.7817 s.

| Measurement | Value | Confidence |
| --- | ---: | --- |
| Stimulus 1 onset | 3.6117 s | high (first mint frame) |
| Stimulus 2 onset | 5.3083 s | high |
| Stimulus 3 onset | 8.9683 s | high |
| Stimulus 4 onset | 10.3333 s | high |
| Stimulus 5 onset | 13.9100 s | high |
| Target sequence (0...8) | 8, 4, 3, 5, 6 | high |
| Inactive diameter | ~232 px / 0.1966 width | high |
| Horizontal center gap | ~263 px | high |
| Vertical center gap | ~262 px | high |
| Edge gap / diameter | ~0.134 | high |
| Overall grid width / video width | ~0.642 | high |
| Grid center X / width | ~0.499 | high |
| Grid center Y from bottom / full height | ~0.469 | medium |
| Inactive fill | ~RGB(39, 51, 61) | high |
| Active fill | ~RGB(94, 209, 192) | high |
| Estimated post-tap waits | ~1.42, 3.42, 1.05, 3.29 s | medium |
| Estimated supported random range | ~1.0...3.5 s | medium/low |

Duplicate adjacent capture frames show that the source gameplay often updates near 30 Hz inside a 60 Hz recording. This does not constrain trainer measurement, which must remain timestamp-based at either 60 or 120 Hz.

## Initial Configuration

- `roundCount`: 5
- `minimumStimulusDelay`: 1.0 s
- `maximumStimulusDelay`: 3.5 s
- delay distribution: continuous uniform
- first-round delay: same distribution as later rounds
- `circleDiameterRatio`: 0.197 of scene width
- `horizontalGapToDiameterRatio`: 0.135
- `verticalGapToDiameterRatio`: 0.135
- `gridCenterXRatio`: 0.5
- `gridCenterYRatio`: 0.469 from scene bottom
- `feedbackDuration`: 0.45 s minimum state hold; the last result remains visible until the next stimulus
- `earlyTapRule`: restart the same round with a new random wait
- `wrongTapRule`: restart the same round with a new random wait
- `invalidTapPenalty`: 1.0 s when the optional penalty rule is selected
- `preventImmediateRepeat`: false; all nine positions remain uniformly eligible
- `randomSeed`: nil in production; fixed seed supported for debug/tests
- start flow: tap to start, then an uncued random wait; no countdown

