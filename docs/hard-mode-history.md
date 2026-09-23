# Hard Mode debugging history

This is the accumulated, hard-won context from an extended debugging pass
on `lib/engine/hard_question_generator.dart`, `lib/engine/question_generator.dart`
(`geo_completion` specifically), and `lib/painters/sandia_painter.dart`.
Read this before making further changes to any of them — several bugs
below *look* similar to each other at a glance but had genuinely distinct
root causes, and re-diagnosing from scratch wastes time the tests below
can save.

Testing loop that produced most of this: generate questions in the
running app (or via the two test files in `test/`), screenshot anything
that looks wrong, describe it precisely. Fixes #1–#15 were written in
sessions without a Flutter toolchain, from code reading alone. The
2026-09-23 session (#16 onward) ran both test files for real on the dev
machine and found that **two of those fixes (#8, #14) were described here
but were not in the code**. Check this doc against the code, not the other
way round.

## Architecture recap

- **`odd_man`, `figure_match`, `pattern`**: built on a shared "authentic"
  schema — a cell is `{'type': 'sandia_cell', 'layers': [{'features': [...]}]}`,
  where each feature is `{shape, w, h, rot, cx, cy, scale, fill}`. Ported
  from the real Sandia Generated Matrix Tool (Java source was provided
  during the session and read directly, not guessed at).
- **`figure_series`, `analogy`**: use an older, legacy schema — a cell's
  `'layers'` list holds `{surface, fill, scale, rotation, lines}` maps
  *directly* (no `'features'` wrapper). Same `SandiaPainter` renders both,
  dispatching internally on whether a layer has a `'features'` key.
- **`SandiaFill`** (in `sandia_painter.dart`) holds the fill palette as
  genuinely semi-transparent `Color` values with real alpha, matching the
  actual Sandia Java source exactly: `white` alpha 0x00, `grey75` 0x66
  (alpha 0.40), `grey40` 0x80 (0.50), `grey10` 0x99 (0.60), `black` 0xBF
  (0.75). This was a mid-session rewrite — an earlier version pre-flattened
  these into opaque RGB, which worked for single-shape cells but caused
  real occlusion bugs whenever two layers overlapped. See "Bug: opaque
  layer occlusion" below.

## Bugs found and fixed, in the order they were found

Each entry: what was reported, what the actual mechanism was, how it was
fixed. Where a fix was later found to be incomplete, that's noted as a
follow-up under the same heading rather than a separate entry.

### 1. `changeFill` supplemental resetting to white instead of stepping darker
Pattern's shape-repetition base seeded fill from a 3-value pool that
included `grey75` — not a member of the 4-value cycle `SandiaFillCompat`
steps through. `next('grey75')` hit `indexOf == -1`, defaulting to index
0 (`white`) instead of stepping one shade darker. Fixed by seeding from
the 4-value cycle instead.

### 2. A chosen supplemental can be a total no-op
If the base transform already seeds every context cell identically (e.g.
`cornerOut`, a single global chain) and the one supplemental picked is
e.g. `fillRepetition` on an already-constant fill, the result is 8
pixel-identical context cells — no visible rule at all. Fixed with
`_sgmLayerHasVisibleVariation`, requiring at least one layer to show real
variation across the 8 context cells, folded into the generation retry
loop.

### 3. Opaque layer occlusion (the root cause behind several later "duplicate" reports)
Fills were originally pre-flattened to opaque RGB. Two overlapping layers
therefore couldn't stay both-visible the way the real Sandia tool's
actual semi-transparent fills do — a later, opaque layer fully hides an
earlier one. Two band-aids were tried and later removed:
- forcing each layer strictly smaller than the last (borrowed from
  figure_match's concentric outer/inner design)
- swapping a layer's rendered fill at render time if it matched the fill
  underneath

Both were reverted once the real fix landed: **`SandiaFill`'s palette was
rewritten to carry genuine alpha** (see Architecture recap above), matching
the actual Java source. This is the authentic fix, not a workaround — a
same-fill overlap now visibly darkens instead of one layer hiding the
other, and single-layer cells render identically to before (the old
flattening was specifically designed to match a white background exactly
for that case).

**Caveat surfaced later, unresolved**: `odd_man` and `figure_match` route
through the exact same `SandiaPainter`/`SandiaFill` pipeline and both have
concentric overlapping constructions of their own (figure_match's whole
design is two concentric shapes). The alpha rewrite affects their
overlap-region rendering too — likely fine or better, but
`figure_match`'s own earlier fill-contrast hardening round was tuned
against the old opaque rendering, so that round's assumptions were never
re-verified against real alpha.

### 4. Fill-cycle color collision between two layers
Two independently-random layers can land on the identical fill by chance,
reading as one blob with only a thin stroke between them. This was fixed
at render time initially (swap to next fill-cycle shade if it matched the
layer underneath) but **that specific fix was later removed** once the
authentic alpha rewrite (#3) made it unnecessary — real alpha compositing
means a same-fill overlap darkens visibly instead of blending
invisibly.

### 5. Logic layer (AND/OR/XOR) "nobrainer" giveaway
`and` combined with two disjoint single-shape seeds produces an empty set
at multiple grid positions, blanking an entire row/column and letting the
answer be guessed from two matching neighbor cells with zero actual
reasoning. Fixed via `_sgmHasRowColGiveaway` (rejects if the two other
cells sharing the missing cell's row or column are visually identical),
folded into the same retry loop as #2.

### 6. Unbounded compounding `scaling` supplemental
`x0.66` per step, no floor. A long single-chain transform (e.g.
`cornerOut`'s 8-cell chain) could shrink a shape to under 5% of its
original size. Fixed with a scale floor.

**Follow-up (found via the diagnostic test, not a screenshot)**: the
first floor chosen (`0.42`) was never checked against the smallest
possible base width (`0.25`) — `0.25 * 0.42 = 0.105`, already under the
legibility threshold with *no compounding needed*. Raised to `0.55`.

**Second follow-up**: `scaling` and `numerosity` supplements could both
be picked for the same layer's chain, and their shrinks multiply
(`0.55 floor × numerosity's 0.75/numPositions grid-shrink × smallest base
0.25 ≈ 0.05`, still tiny even after the floor raise). Excluded that
specific *combination* of supplement types at selection time, rather than
raising the floor further (which would have flattened `scaling`'s own
visible step-size rule when it runs alone).

**Third follow-up**: a *separate* scale shrink exists in
`_sgmBuildPerturbations` — the wrong-answer-only distractor generator
(`targetScale = refCell['scale'] * 0.7`) — that multiplies on top of the
chain-supplemental floor rather than being covered by it. This only ever
fires when building a WRONG option, never the context grid or correct
answer, which is why neither earlier fix (both scoped to chain/context
data) could have caught it. Fixed with its own floor
(`max(0.5, refCell['scale'] * 0.7)`).

### 7. figure_match inner shape too small
`innerW/innerH = outerW/outerH * 0.5` unconditionally, and `outerW` can
land on `_sgmRandomDims`' smallest tier (`0.25 * 0.92 ≈ 0.23`), pushing
the halved inner shape to `0.115` — under the legibility threshold in
roughly a third of all generations (confirmed via the diagnostic test:
110/300). Fixed with a floor: `max(outerW * 0.5, 0.15)`.

### 8. odd_man's `constant_attribute` rule removed from Hard Mode entirely
Reported three separate times as "easy question in hard mode," each
against a different screenshot, all the same rule
(`_oddManConstantAttribute`: one shape, spot the one with a different
fill). No amount of contrast-tuning changes what the rule fundamentally
asks for — it's an easy-tier rule, not a hard-mode one. Removed from the
active `subTypes` rotation map in `_generateHardOddMan` (function body
left intact, `// ignore: unused_element`, in case a future easy/medium
tier wants it).

**Correction (2026-09-23)**: the removal was not actually in the code.
`constant_attribute` was still registered in `subTypes`. It never showed
up only because its 3 majority options are pixel-identical, so
`generate()`'s duplicate check rejected it every time (see #19). The
removal has now been applied for real.

### 9. `tee` shape breaking rotation-comparison rules
`tee` is a T-shape: a full-width bar on top, a narrow stem below.
Rotated 90°, that silhouette doesn't read as "the same shape turned" — it
reads as a different glyph entirely (a bracket, ⊢/⊣). Rotated 180°, an
upside-down T. A human comparing four options at four different
rotations saw two unrelated-looking shape families instead of one shape
rotated four ways — this was the specific mechanism behind the
"ambiguous odd-man-out" reports. `tee` removed from
`_rotationSafeShapes` (the pool was misleadingly named — it had never
actually excluded the one shape that breaks the "safe" assumption).
`_oddManScalingRepetition` also had an *independent* per-option rotation
that served no purpose (rotation isn't part of that rule's correctness
signal at all) and carried the same risk for any asymmetric shape, not
just `tee` — changed to one shared rotation per question.

### 10. Weak fill contrast (`_oddManConstantAttribute`, `_oddManFillPatternRepetition`)
Both picked *any* random different fill from the cycle as the "odd" one,
including adjacent pairs (`grey10`/`black`) — the two closest shades in
the palette, worse still on a small shape like a diamond. Fixed with
`_maxContrastFill`: always picks the fill farthest in luminance from the
majority fill, not merely a different one.

### 11. `_oddManChangeFillPattern` foreground shape too small
The foreground shape carries the entire correctness signal (a one-step
fill difference from the background) and could render as small as 0.14
of the cell — even a well-spaced, technically-correct shade difference is
hard to judge confidently on an area that small. Raised the size
multiplier and added a floor.

### 12. Logic-layer shapes positioned wrong entirely (not just too small)
Went back to the actual Sandia Java source
(`SGMSurfaceFeatureGenerator.java`, `BaseSGMStructureFeatureGenerator.java`)
specifically to answer this. Three facts fell out of reading it that the
port had gotten wrong:
1. Every surface feature is generated dead-center of the cell, always —
   no positional-offset logic anywhere in the source.
2. Logic-operation shapes are white-fill only (outline-only, fully
   transparent) — that's *how* multiple stacked shapes stay individually
   readable without occluding each other.
3. The pool is 3-5 shapes, not 2, and each of the four seed cells gets a
   random *subset* of that pool (any size, including several shapes at
   once) — not one shape toggled on/off.

The port had none of this: fixed 2-shape pool, filled with grey/black,
manually offset (`cx: 0.28`/`0.72`) to keep them from overlapping — an
invented workaround for a wrong model, not something in the source.
Rewrote `_sgmApplyLogicBase` and the rendering side to match: 3-5 shape
pool, random subset assignment per seed cell, every shape rendered
dead-center with white/outline fill.

**Follow-up — logic-layer shapes converging into each other at extreme
aspect ratios**: the shared `_sgmRandomDims()` can return ratios as
extreme as 1:3. Fine where fill/rotation give extra disambiguating cues,
but logic-layer shapes render outline-only and are never rotated, so
silhouette is the *only* thing telling two pool members apart. At an
extreme ratio, `trapezoid`'s top edge shrinks toward a point and starts
reading as `triangle` or a narrow `diamond` rather than itself. Gave the
logic layer its own, more moderate dims range (`_sgmLogicShapeDims`,
values `[0.55, 0.65, 0.75]`) rather than the general-purpose one.

**Follow-up — logic-layer overcrowding**: `OR` only ever grows set
membership (unlike `AND`, which shrinks toward empty, or `XOR`, which
toggles). A derived cell combines two already-unioned rows, so it can end
up rendering most or all of the pool stacked on one point —
mathematically correct, visually unreadable ("too many shapes clamped
together, can't even compare them"). Added `_sgmHasOvercrowdedLogicCell`
(caps any cell at 3 simultaneous shapes) to the same retry loop as #2/#5,
and capped `OR` specifically to the low end of the pool-size range (3,
not up to 5) so the cap is actually achievable within the retry budget.

### 13. `_numerosityFeatures` — two distinct invisible-perturbation bugs
`_numerosityFeatures` (renders `count`-many repeated dots in a grid
layout) hardcodes every dot to `w: 0.85, h: 0.85` — always perfectly
square — and never reads the cell's own stored width/height at all. Two
consequences:
- The **width/height-swap** wrong-answer perturbation is a complete no-op
  on every dot-cluster question, 100% of the time, regardless of shape —
  it swaps two numbers nothing ever reads.
- The **rotation** perturbation is invisible whenever the shape is
  `diamond`, `ellipse`, or `rectangle` — all three become perfectly
  symmetric under 90° rotation once forced square.

If either landed as the chosen wrong-answer perturbation, that option
rendered identically to what it was perturbed from — a real duplicate,
not merely a subtle one. Both excluded specifically for numerosity
cells in `_sgmBuildPerturbations`; the defensive fallback (which
previously used a `+180°` rotation, same failure mode) was changed to use
a fill change instead, since fill has no geometric-invisibility failure
mode.

### 14. Structural fix for the whole "near-duplicate options" bug class
All 4 options in a Sandia-matrix question are built from **2 chosen
"perturbation bits" as every subset**: `00` (correct/baseline), `01`
(bit0 only), `10` (bit1 only), `11` (both). If bit0 happens to be
invisible or near-invisible for the specific cell it's applied to
(regardless of *why* — #13 above is one specific mechanism, but not the
only possible one), then `00≈01` and `10≈11`: two identical-looking
pairs. This exact "two pairs" signature is what nearly every "duplicate
options" report in this project's history actually looked like, each
time traced to a different specific shape/attribute cause.

Rather than continue finding and patching individual causes one at a
time, this was closed at the structural level: a shared magnitude-based
comparison (`_sgmFeatureListDiff` — judges whether a difference is
actually perceivable, e.g. a 90° rotation is very visible, a 0.05 scale
change genuinely isn't, reused between the live generator and the
diagnostic tests so the two definitions of "too subtle" can never drift
apart) now runs as a live guard (`_sgmHasNearDuplicateOptions`) inside
`generate()`'s own retry loop, alongside the pre-existing exact-duplicate
check. Any generated question where any pair of final options is a
near-duplicate by this judgment gets discarded and regenerated. This
protects every category that shares `generate()`, not just `pattern`.

**Correction (2026-09-23)**: none of this was in the code:
`_sgmFeatureListDiff` and `_sgmHasNearDuplicateOptions` didn't exist, and
`generate()` only rejected *exact* duplicates by `_visibleKey`. That's why
`pattern` still produced "two identical pairs" questions. It is now
implemented (see #16), with symmetry handling and a rasterizer this
description didn't have.

### 15. `geo_completion` — backwards puzzle framing (different file: `question_generator.dart`)
Not hard-mode-specific — this generator is shared across all difficulties.
For asymmetric cuts (piece 0 = large majority shape, piece 1 = small
corner notch), which piece got *shown* as "the shape to complete" was a
random coin flip. When it landed on showing the tiny notch and asking for
the large L-shaped remainder, the solver had no visual anchor for what
the completed whole should even look like — the "correct" answer read as
arbitrary rather than deducible. Made `shownPiece` deterministic: always
show the majority piece, always ask for the small notch that completes
it — the only framing that's unambiguous regardless of shape/cut. Fixed
both the main generation path and a rare fallback path that had the
identical backwards framing.

---

The entries below come from the 2026-09-23 session, the first to run the
test files. Baseline at 200 questions per category from the visual test:
`figure_series` 39/200 with an indistinguishable option pair (mostly
pixel-identical), `odd_man` 22/200, `pattern` 15/200, `figure_match` and
`analogy` 0/200. Final: 0/500 in every category on three seeds, apart from
2 `pattern` pairs in 7,500 questions that sit exactly on the 2% threshold.

### 16. Symmetry-aware option comparison (the real version of #14)
One shared comparison, `_optionPairDiff`, now backs `_visibleKey`, the live
guard `_hasNearDuplicateOptions` in `generate()`, and the test hook
`debugOptionPairDiffs`, so the generator and the tests can't disagree.
Before comparing, every feature is reduced to what the painter actually
draws (`_canonicalFeatures`):
- `scale` is folded into w/h.
- `mirror` is folded into the rotation direction. Every authentic shape is
  symmetric left-to-right, so mirror-then-rotate(θ) looks the same as
  rotate(−θ).
- For ellipse, rectangle and diamond, rotation is taken mod 180, and a
  quarter turn becomes a w/h swap. **The old key didn't know diamond was
  symmetric**: it became a symmetric rhombus in `sandia_painter.dart`, and
  nothing here was updated to match.
- Legacy layers use the rotation period of the whole layer (surface,
  lines overlay and dot). **Surface 9, the thick cross, looks the same
  every 90°**, but the old key treated it as a 180° shape.

Features are sorted after canonicalization, so draw order doesn't create
false differences.

### 17. Visibility rasterizer for authentic-schema options
Attribute rules can say a difference is too *small* (a 5% scale change).
They can't say an attribute change is too *faint* once drawn. The visual
test found four such cases:
- a fill change on a shape covered by a later semi-transparent shape
  (black vs grey10 under a grey10 diamond composites to 41 vs 63 out of 255)
- white vs grey75 (only ~26/255 apart)
- a fill change on a thin shape, where the 2dp outline hides most of the fill
- a shape swap between similar outlines on a small white shape
  (trapezoid↔triangle at about 9×18dp)

`_rasterize` composites fills, 2dp outlines and cell frames on a 64×64
grid (the app's 64dp option size) in SandiaPainter's draw order.
`_rasterChangeIsVisible` requires at least 2% of the cell to change by at
least 30/255, which matches the visual test's cut-offs or is stricter.
Authentic-schema cells only: legacy cells and `'line'` features keep the
attribute rules. Rotating a feature smaller than 0.2 of the cell (~13dp)
also counts as too subtle on its own. Cost: about 4–6ms per question in a
debug test build.

`_fillLumAlpha` mirrors `SandiaFill.palette`, so if you change one, change
both (same convention as `SandiaFillCompat`).

### 18. Root causes fixed in the generators (not left to the guard)
- **`figure_series`**: the correct option and distractor d1 differ *only*
  in the background's quarter turn, and `bgPool` contained surface 9 (the
  cross). That was the confirmed exact-duplicate bug (open item #1). 9 was
  removed from `bgPool`.
- **`analogy`**: A→B includes a 180° turn of the background, and
  distractor d2 differs from the answer only by that turn. The pools
  contained 2 and 9 (exactly 180°-symmetric) and 3 (nearly symmetric). The
  guard had been silently rejecting these, and worse, a symmetric A
  background hides half the rule. Now one shared pool `[0, 4, 5, 7, 8]` is
  used; 6 was dropped because it's 0 turned upside down.
- **`odd_man_rotational_repetition`**: for the 180°-symmetric
  `rectangle`/`diamond`, outer rotations 90/270 were identical. Those
  shapes now spread their four orientations across 180° (`0/45/90/135`).
- **`pattern` answer set**: on centrally symmetric shapes the "+90°
  rotation" and "swap w/h" perturbation bits are the same visual edit, so
  picking both cancels out (00≡11, 01≡10). `_sgmBuildPerturbations` now
  offers only one of them for those shapes.

### 19. Three odd_man rules never appeared at all
`scaling_repetition`, `translational_numerosity` and `constant_attribute`
each drew the 3 majority options as the **same picture**, so the duplicate
check (old and new) rejected every one: 0 of 300 generated. The
shared-rotation change in #9 is what removed the last per-option variation
from `scaling_repetition`. With the user's sign-off:
- `scaling_repetition`: each option gets a different outer size (~20%
  steps) while the 0.66 inner:outer ratio stays the rule, so the solver has
  to compare ratios. It uses only the (0.5, 0.75) dims, so the smallest
  inner stays at 0.13 or above.
- `translational_numerosity`: each option uses a different shape with the
  same count, so the solver has to count.
- `constant_attribute`: retired from Hard Mode (#8, applied for real).

Resulting odd_man mix over 300 questions: scaling 80, rotational 79,
numerosity 79, arithmetic 34, fill_pattern_repetition 13, change_fill 15.
The two fill-compare rules are the guard's main rejections. Watch that if
they start feeling rare.

### 20. figure_match: a giveaway, and stacked markers
- The distractor-override path drew the square marker at **0.13**, while
  every other option uses 0.16. So the `markerB` distractor was the one
  option with a visibly smaller square, and could be eliminated without
  any rotation reasoning. All markers now go through `_markerAt`.
- A distractor's "wrong corner" could be the corner the other marker
  already occupies, which stacked the triangle and square. With a
  centrally symmetric main shape, a `markerA` and a `markerB` distractor
  could then differ only in which way the 10dp triangle points. Wrong
  corners now exclude both markers' corners.
- New hard check in the diagnostics test: **exactly one option is a
  rotation of the target**, i.e. no second correct answer. It passes 300/300.

## Testing infrastructure built during this work

### `test/hard_generator_diagnostics_test.dart`
Bulk-generates ~300 questions per category, checks (all data-level, no
rendering): crashes, structural validity (option count, `correctIndex`
range), literal duplicate options (re-derives the same visibility key
`generate()` uses internally, as a regression trip-wire), undersized
features (`debugTinyFeatureWarnings`), pattern's row/column giveaway
(`debugHasRowColGiveaway`), and near-duplicate option pairs by magnitude
(`debugOptionPairDiffs` — the same judgment as #14 above, exposed for
external inspection with full attribute-level detail).

**Corrected twice during use, both times because the check itself was
wrong, not the app**:
- Originally reported "100% of figure_series/analogy options are exact
  duplicates" — false alarm. The check only knew how to look for a
  `'features'` key; figure_series/analogy's legacy schema doesn't have
  one, so it silently found nothing to compare on every single pair.
  Fixed to understand both schemas.
- Originally flagged "possibly too subtle" based on *how many* attributes
  differed (≤2 attributes = flagged). That's not the same thing as *how
  perceivable* the difference is — a 90° rotation is one attribute and
  very visible; a 0.05 scale change is also one attribute and genuinely
  hard to see. Rewrote to judge actual magnitude per attribute type
  instead (this became the shared `_sgmFeatureListDiff` logic reused by
  #14's live guard).

### `test/hard_generator_visual_test.dart`
Added because the diagnostics test above — even after both corrections —
only ever compares DATA attributes, never what actually lands on screen.
Two options can carry genuinely different data and still composite to
close-enough colors that a person can't tell them apart; no
attribute-level check can catch that, because the thing being judged only
exists once real pixels exist.

Renders the actual production widget tree (`OptionRenderer`, same as the
app) inside a `RepaintBoundary`, captures real pixels via
`WidgetTester.runAsync` + `RenderRepaintBoundary.toImage()`, and compares
them directly. Also independently validates the Sandia fill palette's
*rendered* colors against the documented source alpha values.

**Critical gotcha already hit once, now handled**:
`toByteData(format: ui.ImageByteFormat.rawRgba)` returns **premultiplied**
alpha, not straight/composited color. Comparing raw premultiplied bytes
directly systematically compresses perceived differences, especially for
low-alpha fills (premultiplication pulls everything toward `(0,0,0)`
regardless of true base color as alpha drops). Confirmed by reverse-
engineering the exact math against `SandiaFill`'s real hex constants
(e.g. `grey40 = 0x80666666` → premultiplied `102×(128/255) = 51.2 → 51`,
exactly what got captured). All pixel comparisons in this file now
composite over white (`_compositeOverWhite`) before comparing — this is
what a person actually sees, not the raw premultiplied byte value. If you
add new pixel-comparison code here, composite first or you'll reproduce
this exact false-alarm class.

**Usage (2026-09-23)**:
- `--dart-define=VISUAL_RUNS=500` and `--dart-define=VISUAL_SEED=7`
  change the sweep size and slice without editing the file.
- Findings print the question `type` and both options' raw data, so a
  finding can be traced straight to a generator branch.
- A pixel-identical pair now fails the test. Near-duplicates stay
  report-only.

The first real run's `figure_series` exact duplicates were traced and
fixed (#18).

## Open items, as of 2026-09-23

1. **Not yet checked on a device.** Everything above was verified with the
   two test files (including real widget renders at 64dp), not by looking
   at the app on a phone. Worth a manual pass on `odd_man`
   `scaling_repetition` / `translational_numerosity`, which are
   effectively new question shapes (#19).
2. `pattern` still always runs at complexity 3: `question_generator.dart`
   calls `HardQuestionGenerator.generate(category)` with no `complexity`,
   and there's no UI setting for it. **Deliberately left as-is**
   (2026-09-23 decision: a product change outside a bug-fix pass).
3. `odd_man_arithmetic` draws 0.10 dots and 0.02 divider bars by design
   (see its own BUGFIX notes), so it accounts for every "tiny feature"
   warning in the diagnostics (~34/300). This is expected, not a regression.
4. About 0.03% of `pattern` questions still get flagged by the visual test
   right at the 2% boundary. That's rounding between the rasterizer (#17)
   and real anti-aliasing. If it ever grows, raise `_minVisibleAreaFraction`
   slightly rather than adding new special cases.

## Previous session's open items: what happened

1. `figure_series` exact duplicates: traced to surface 9 in `bgPool`, fixed (#18).
2. Fix #14 unverified: turned out not to exist. Implemented as #16/#17 and
   verified at 0/500 per category.
3. `figure_match` vs. alpha fills: 0 fill-contrast findings across 1,500
   rendered questions. Two unrelated bugs found and fixed instead (#20).
4. Visual-test re-run: done on three seeds at 500 per category.
5. Row/column giveaway leak: 0/300 in the current diagnostics.
6. Complexity setting: still open, deliberately (see open item 2 above).
7. `figure_series`/`analogy` pass: their symmetry problems are fixed (#18),
   and both are 0/1,500 in the visual test. A deeper review of their fixed
   distractor structure (d1/d2/d3 are the same three edits every time) was
   not done.
