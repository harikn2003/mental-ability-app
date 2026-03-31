import 'dart:math';

import 'reasoning_question.dart';

/// QuestionGenerator
/// Single vocabulary: FigurePainter data keys.
/// All 10 question types, deterministic distractors.
///
/// Repeat prevention: tracks (category, variant, key params) as a string
/// signature. After 50 questions the history is cleared automatically.
class QuestionGenerator {
  static final _r = Random();

  // Shapes that look visually different when rotated (asymmetric)
  static const _rotateable = [2, 3, 7]; // triangle, diamond, arrow
  // Shapes that also look different at 90° (skip circle=0 which looks same)
  static const _allNonCircle = [1, 2, 3, 4, 5, 6, 7, 8];
  static const _highlyAsymmetric = [2, 7, 8]; // triangle, arrow, L-shape

  // ── Repeat prevention ─────────────────────────────────────────────────────
  static final Set<String> _history = {};
  static int _totalGenerated = 0;

  static String _sig(String cat, Map<String, dynamic> params) =>
      '$cat:${params.entries.map((e) => '${e.key}=${e.value}').join(',')}';

  /// Call at the start of each new quiz session for fresh variety.
  static void resetSession() {
    _history.clear();
    _totalGenerated = 0;
  }

  static bool _seen(String sig) => _history.contains(sig);
  static void _markSeen(String sig) {
    _history.add(sig);
    _totalGenerated++;
    // Safety valve: if history grows very large, trim oldest half
    if (_history.length > 800) {
      final toRemove = _history.take(400).toList();
      _history.removeAll(toRemove);
    }
  }

  static ReasoningQuestion generate(String category) {
    switch (category) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'pattern':
        {
          final pv = _r.nextInt(3);
          if (pv == 0) return _matrixShapeCycle();
          if (pv == 1) return _matrixDotRotation();
          return _matrixInnerShape();
        }
      case 'figure_series':
        return [
          _seriesRotation,
          _seriesDots,
          _seriesFillToggle,
          _seriesRotFill,
          _seriesInner,
          _seriesDotsRot,
          _seriesMorph
        ][_r.nextInt(7)]();
      case 'analogy':
        return _analogy();
      case 'geo_completion':
        return _geoCompletion();
      case 'mirror_shape':
        return _mirrorShape();
      case 'mirror_text':
        return _mirrorText();
      case 'punch_hole':
        return _punchHole();
      case 'embedded':
        return _embedded();
      default:
        return _matrixShapeCycle();
    }
  }

  // ── Shape data helper ─────────────────────────────────────────────────────
  static Map<String, dynamic> _f(int shape, {
    bool filled = false, int rot = 0, bool mirror = false,
    int dots = 0, int inner = 0, int lines = 0, int missingCorner = 0,
  }) => {
    'shape': shape,
    'filled': filled,
    'rotation': rot,
    'mirror': mirror,
    'dots': dots,
    'inner': inner,
    'lines': lines,
    'missingCorner': missingCorner,
  };

  /// Compact string key for a shape map — used to detect duplicate options.
  static String _key(Map<String, dynamic> m) {
    // ── Punch hole options ─────────────────────────────────────────────────
    if (m.containsKey('holes') && m.containsKey('unfolded')) {
      final holes = (m['holes'] as List)
          .map((h) => '(${(h["x"] as num).toStringAsFixed(2)},${(h["y"] as num)
          .toStringAsFixed(2)})')
          .toList()
        ..sort();
      return 'punch|ax:${m["fold_axis"]}|holes:${holes.join("-")}';
    }
    // ── Mirror text options ────────────────────────────────────────────────
    if (m.containsKey('mirror_h') || m.containsKey('is_clock')) {
      final ch = m['content'] ?? 'clk:${m["clock_hour"]}:${m["clock_minute"]}';
      return 'txt|$ch|h:${m["mirror_h"]}|v:${m["mirror_v"]}';
    }
    // ── Geo cell options ───────────────────────────────────────────────────
    if (m['type'] == 'geo_cell') {
      return 'geocell|f:${m["filled"]}|mk:${m["mark"] ?? "none"}';
    }
    // ── Embedded option ────────────────────────────────────────────────────
    if (m['type'] == 'embedded_option') {
      final shapes = (m['shapes'] as List)
          .map((s) => '${s["shape"]}-${s["filled"]}-${s["rotation"] ?? 0}')
          .join('+');
      return 'emb|$shapes|off:${m["offset"]}';
    }
    // ── Shape options ──────────────────────────────────────────────────────
    final int s = m['shape'] ?? 0;
    int rot = m['rotation'] ?? 0;
    bool mir = m['mirror'] ?? false;
    if (s == 0 || s == 1 || s == 4 || s == 6) {
      rot = 0;
      mir = false;
    }
    if (s == 3 || s == 5) rot = rot % 2;
    return '$s,${m["filled"]},$rot,$mir,${m["dots"]},${m["inner"]},${m["lines"]},${m["missingCorner"]}';
  }

  /// Insert [correct] at a random position among [wrongs].
  /// Removes any wrong that is visually identical to [correct] first.
  /// Returns options list (always 4) + correct index.
  static ({List<Map<String, dynamic>> opts, int idx}) _pack(
      Map<String, dynamic> correct,
      List<Map<String, dynamic>> wrongs,) {
    final ck = _key(correct);
    // Deduplicate: remove wrongs that match correct or each other
    final seen = <String>{ck};
    final deduped = <Map<String, dynamic>>[];
    for (final w in wrongs) {
      final k = _key(w);
      if (!seen.contains(k)) {
        seen.add(k);
        deduped.add(w);
      }
    }
    // If we lost wrongs due to dedup, generate type-appropriate fallbacks
    final bool isPunchHole = correct.containsKey('holes');
    final bool isMirrorText = correct.containsKey('mirror_h') ||
        correct.containsKey('is_clock');
    int safety = 0;
    while (deduped.length < 3 && safety < 50) {
      safety++;
      Map<String, dynamic> fallback;
      if (isPunchHole) {
        // Generate another punch-hole option with random hole count
        final hx = 0.2 + _r.nextDouble() * 0.2;
        final hy = 0.2 + _r.nextDouble() * 0.6;
        final ax = correct['fold_axis'] as int? ?? 0;
        final n = _r.nextInt(3) + 1; // 1-3 holes
        fallback = {
          'type': 'punch_hole', 'unfolded': true, 'fold_axis': ax,
          'holes': List.generate(n, (i) =>
          {
            'x': hx + i * 0.15, 'y': hy,
          }),
        };
      } else if (isMirrorText) {
        // Another mirror_text combo
        final ch = ['B', 'R', 'F', 'J'][_r.nextInt(4)];
        fallback = {'type': 'mirror_text', 'content': ch, 'is_clock': false,
          'mirror_h': _r.nextBool(), 'mirror_v': _r.nextBool()};
      } else {
        fallback = _f(
          _allNonCircle[_r.nextInt(_allNonCircle.length)],
          rot: _r.nextInt(4), filled: _r.nextBool(),
        );
      }
      final fk = _key(fallback);
      if (!seen.contains(fk)) {
        seen.add(fk);
        deduped.add(fallback);
      }
    }

    final pos = _r.nextInt(4);
    final list = List<Map<String, dynamic>>.from(deduped)
      ..insert(pos, correct);
    return (opts: list, idx: pos);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. ODD MAN OUT
  // ═══════════════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════════════
  // ODD MAN OUT — one and only one property differs across the 4 options.
  //
  // Rule: EXACTLY ONE property is the "odd" property. Everything else is
  //       identical across all four options so the student can't be confused
  //       about what the rule is.
  //
  // Variant A — FILL:  3 outline, 1 filled (or vice versa).
  //             All same shape. All same rotation (no rotation noise).
  //
  // Variant B — SHAPE: 3 identical shape, 1 clearly different shape.
  //             All same fill. All same rotation.
  //             Constraint: base shape must be visually distinct from odd shape
  //             even at the same rotation (so no circle vs hexagon confusion).
  //
  // Variant C — DOTS:  3 with 1 dot, 1 with 3 dots.
  //             All same shape. All same rotation.
  //
  // Variant D — ROTATION (mirror-like): All same shape + fill + dot count.
  //             3 share the same rotation, 1 is rotated 180° differently.
  //             Only uses highly asymmetric shapes (triangle/arrow/L) so the
  //             rotation difference is instantly visible.
  //
  // Variant E — SIZE OF INNER DETAIL: 3 have no inner shape, 1 has an inner shape.
  //             Adds visual complexity without rotation ambiguity.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _oddMan() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final v = _r.nextInt(8); // 8 variants (A-E original, F-H composite)
      final cp = _r.nextInt(4);
      List<Map<String, dynamic>> opts;
      String sigKey;

      switch (v) {

      // ── A: FILL ──────────────────────────────────────────────────────────
      // Rule: 3 same fill, 1 different fill.
      // All same shape + same rotation — fill is the ONLY difference.
        case 0:
          {
            final s = _r.nextInt(6) + 1; // 1-6, avoid circle
            final rot = _r.nextInt(4);
            final maj = _r.nextBool(); // majority fill
            sigKey = 'oddA:s$s,r$rot,maj$maj,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: rot, filled: i == cp ? !maj : maj));
          break;
          }

      // ── B: SHAPE ─────────────────────────────────────────────────────────
      // Rule: 3 same shape, 1 different shape.
      // All same fill + same rotation — shape is the ONLY difference.
      // Constraint: the odd shape must not look like the base at any rotation.
        case 1:
          {
            // Pick base from clearly distinct shape pairs
            const pairs = [
              [2, 5], // triangle vs pentagon
              [3, 6], // diamond vs hexagon
              [7, 1], // arrow vs square
              [8, 4], // L-shape vs cross
              [2, 3], // triangle vs diamond
              [7, 8], // arrow vs L-shape
            ];
            final pair = pairs[_r.nextInt(pairs.length)];
            final base = pair[0] as int;
            final odd = pair[1] as int;
            final rot = _r.nextInt(4);
            final filled = _r.nextBool();
            sigKey = 'oddB:b$base,o$odd,r$rot,f$filled,cp$cp';
            opts = List.generate(4, (i) =>
                _f(i == cp ? odd : base, rot: rot, filled: filled));
          break;
          }

      // ── C: DOTS ──────────────────────────────────────────────────────────
      // Rule: 3 have N dots, 1 has clearly different dot count.
      // All same shape + same rotation — dots is the ONLY difference.
        case 2:
          {
            final s = _r.nextInt(5) + 1; // 1-5
            final rot = _r.nextInt(4);
            // Use 1 vs 3 (never 0 vs 1 — too subtle; never 2 vs 3 — too close)
            final majD = 1;
            final oddD = 3;
            sigKey = 'oddC:s$s,r$rot,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: rot, dots: i == cp ? oddD : majD));
          break;
          }

      // ── D: ROTATION ──────────────────────────────────────────────────────
      // Rule: 3 share same rotation, 1 is rotated 90° differently.
      // All same shape + fill + dots — rotation is the ONLY difference.
      // Uses only highly asymmetric shapes so the difference is obvious.
        case 3:
          {
            final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
            final filled = _r.nextBool();
            final majRot = _r.nextInt(4);
            // oddRot must look clearly different — use +1 step (90°)
            final oddRot = (majRot + 1) % 4;
            sigKey = 'oddD:s$s,f$filled,mr$majRot,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: i == cp ? oddRot : majRot, filled: filled));
          break;
          }

      // ── E: INNER SHAPE ───────────────────────────────────────────────────
        case 4:
          {
            final s = _r.nextInt(4) + 1;
            final rot = _r.nextInt(4);
            final filled = false;
            final innerS = _r.nextInt(3) + 1;
            sigKey = 'oddE:s$s,r$rot,i$innerS,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: rot, filled: filled, inner: i == cp ? innerS : 0));
          break;
          }

      // ── F: DIFFERENT INNER SHAPE ──────────────────────────────────────────
      // Rule: 3 figures have same outer + same inner shape.
      // 1 figure has same outer but a DIFFERENT inner shape.
      // Tests whether student notices the inner element change.
        case 5:
          {
            final outer = _r.nextInt(4) + 1;
            final rot = _r.nextInt(4);
            final majInner = _r.nextInt(4) + 1; // inner for 3
            int oddInner;
            do {
              oddInner = _r.nextInt(4) + 1;
            } while (oddInner == majInner);
            sigKey = 'oddF:o$outer,r$rot,mi$majInner,oi$oddInner,cp$cp';
            opts = List.generate(4, (i) =>
                _f(outer, rot: rot, filled: false,
                    inner: i == cp ? oddInner : majInner));
            break;
          }

      // ── G: DIFFERENT DOT COUNT ────────────────────────────────────────────
      // Rule: 3 have same dots+rotation+fill. 1 has different DOT COUNT.
      // Clearer than oddC (which uses 1 vs 3 always) — this varies the counts.
        case 6:
          {
            final s = _r.nextInt(6) + 1;
            final rot = _r.nextInt(4);
            final filled = _r.nextBool();
            final majD = _r.nextInt(3); // 0,1, or 2
            final oddD = majD == 0 ? 3 : 0; // clearly different count
            sigKey = 'oddG:s$s,r$rot,f$filled,md$majD,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: rot, filled: filled, dots: i == cp ? oddD : majD));
            break;
          }

      // ── H: COMPOSITE FILL RULE ────────────────────────────────────────────
      // Rule: 3 have outer=outline + inner=filled.
      // 1 (odd) has outer=filled + inner=outline (both inverted).
      // Tests whether student notices the fill relationship between elements.
        default:
          {
            final outer = _r.nextInt(4) + 1;
            final inner = _r.nextInt(3) + 1;
            final rot = _r.nextInt(4);
            sigKey = 'oddH:o$outer,i$inner,r$rot,cp$cp';
            // majority: outer=stroke inner=filled → encoded as filled=false, inner positive
            // odd: outer=filled inner=stroke → filled=true, inner positive but visually inverted
            opts = List.generate(4, (i) =>
                _f(outer, rot: rot, filled: i == cp, inner: inner));
            break;
          }
      }

      if (_seen(sigKey)) continue;
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'odd_man',
        type: 'odd_v$v',
        puzzle: {'type': 'odd_man'},
        options: opts,
        correctIndex: cp,
      );
    }
    // Fallback
    final s = _r.nextInt(4) + 1;
    final cp = _r.nextInt(4);
    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_v0',
      puzzle: {'type': 'odd_man'},
      options: List.generate(4, (i) => _f(s, filled: i == cp)),
      correctIndex: cp,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. FIGURE MATCH
  //
  // The target is shown with a COMBINATION of properties (shape + rotation +
  // fill + optional dots). Distractors are picked from a POOL of wrong-answer
  // types so each question instance looks different.
  //
  // Distractor pool (3 picked randomly per question):
  //   TYPE A — same shape, +1 rotation step, same fill, same dots
  //   TYPE B — same shape, +2 rotation steps, same fill, same dots
  //   TYPE C — same shape, same rotation, FLIPPED fill, same dots
  //   TYPE D — same shape, +1 rotation, FLIPPED fill, same dots
  //   TYPE E — same shape, same rotation, same fill, +1 dot (different detail)
  //   TYPE F — DIFFERENT shape (similar complexity), same rotation, same fill
  //   TYPE G — same shape, +3 rotation steps (+270°), same fill, same dots
  //   TYPE H — same shape, +2 rotation, FLIPPED fill, different dots
  //
  // 3 distractors are chosen randomly from the pool so the same target can
  // appear with different wrong options across sessions.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _figureMatch() {
    // KEY DESIGN RULE:
    // Figure match ONLY uses shapes that look visibly different when rotated
    // (asymmetric shapes). Symmetric shapes like square/hexagon/cross look
    // identical at all rotations — rotation-based distractors become useless.
    //
    // Shapes used: 2=triangle(R), 3=diamond, 7=arrow, 8=L-shape
    // These are all highly asymmetric — a 90° rotation is instantly obvious.
    //
    // Distractor strategy — always pick from DIFFERENT categories:
    //   • One rotation distractor  (+1 or +3 step — visually distinct)
    //   • One fill distractor      (same shape+rot, opposite fill)
    //   • One shape distractor     (different asymmetric shape, same rot+fill)
    // This ensures all 4 options look clearly different from each other.
    //
    // Dots (0–2) add variety so the same shape+rot combination produces
    // different-looking questions across sessions.

    // Only asymmetric shapes — rotation is always visually meaningful
    const _asymShapes = [2, 3, 7, 8]; // triangle, diamond, arrow, L-shape

    // For each shape, which other shape looks most similar (hardest distractor)
    const _lookalike = {2: 3, 3: 2, 7: 8, 8: 7};

    for (int attempt = 0; attempt < 30; attempt++) {
      final s = _asymShapes[_r.nextInt(_asymShapes.length)];
      final rot = _r.nextInt(4);
      final filled = _r.nextBool();
      final dots = _r.nextInt(3); // 0, 1, or 2

      // rotStep: 1 or 3 (avoid 2 — diamond at +2 looks too similar)
      final rotStep = _r.nextBool() ? 1 : 3;
      final sigKey = 'figMatch:s$s,r$rot,f$filled,d$dots,rs$rotStep';
      if (_seen(sigKey)) continue;

      final target = _f(s, rot: rot, filled: filled, dots: dots);
      final dRot = _f(s, rot: (rot + rotStep) % 4, filled: filled, dots: dots);
      final dFill = _f(s, rot: rot, filled: !filled, dots: dots);
      final dShape = _f(
          _lookalike[s] ?? ((s % 4) + 1), rot: rot, filled: filled, dots: dots);

      final res = _pack(target, [dRot, dFill, dShape]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_match',
        type: 'figure_match',
        puzzle: {'type': 'figure_match', 'target': target},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    // Fallback — triangle is always asymmetric
    final target = _f(2, rot: 0, filled: false);
    final res = _pack(target, [
      _f(2, rot: 1, filled: false),
      _f(3, rot: 0, filled: false),
      _f(2, rot: 0, filled: true),
    ]);
    return ReasoningQuestion(
      category: 'figure_match',
      type: 'figure_match',
      puzzle: {'type': 'figure_match', 'target': target},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3a. PATTERN — shape cycle
  // Row 0: square(1), Row 1: triangle(2), Row 2: diamond(3)
  // Fill: row0=outline, row1=filled, row2=outline
  // Rotation advances +90° per column
  // ═══════════════════════════════════════════════════════════════════════════
  // Shape-set options: each is [row0shape, row1shape, row2shape]
  // Row rule: same shape throughout each row, rotation advances by +step each col,
  // fill alternates by row (row0=outline, row1=filled, row2=outline).
  static const _matShapeSets = [
    [1, 2, 3], // square, triangle, diamond
    [2, 7, 8], // triangle, arrow, L-shape
    [3, 7, 2], // diamond, arrow, triangle
    [1, 8, 3], // square, L-shape, diamond
    [5, 2, 7], // pentagon, triangle, arrow
    [8, 1, 7], // L-shape, square, arrow
  ];

  static ReasoningQuestion _matrixShapeCycle() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final setIdx = _r.nextInt(_matShapeSets.length);
      final shapes = _matShapeSets[setIdx];
      final baseRot = _r.nextInt(4);
      final step = _r.nextBool() ? 1 : -1; // CW or CCW rotation
      // Missing cell can be any of the 9 cells, but not position 0
      // (top-left is the anchor — removing it makes the pattern unreadable)
      final missing = _r.nextInt(8) + 1; // 1-8
      final misRow = missing ~/ 3;
      final misCol = missing % 3;

      final sigKey = 'matSC:set$setIdx,br$baseRot,st${step > 0
          ? 1
          : 0},m$missing';
      if (_seen(sigKey)) continue;

      // Build full 3×3
      Map<String, dynamic> cell(int row, int col) =>
          _f(
            shapes[row],
            rot: ((baseRot + col * step) % 4 + 4) % 4,
            filled: row == 1,
          );

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
          cells.add(cell(r, c));

      final ans = cell(misRow, misCol);
      final ansShape = shapes[misRow];
      final ansRot = ans['rotation'] as int;
      final ansFill = ans['filled'] as bool;

      final res = _pack(ans, [
        _f(ansShape, rot: (ansRot + 1) % 4, filled: ansFill),
        // +1 rotation
        _f(ansShape, rot: ansRot, filled: !ansFill),
        // wrong fill
        _f(shapes[(misRow + 1) % 3], rot: ansRot, filled: ansFill),
        // wrong shape
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[missing] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_shape_cycle',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': missing},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    return _matrixDotRotation();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3b. PATTERN — dot & rotation (same shape, dots=col, rot=col×90°)
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _matrixDotRotation() {
    // Two sub-variants:
    // A: dots increase 0→1→2 per column, rotation fixed per column (classic)
    // B: rotation increases per column, dots increase per row — both rules apply
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final filled = _r.nextBool();
      final subV = _r.nextInt(2); // 0=dots-only, 1=dots+rotation
      final startD = _r.nextInt(2); // start dots at 0 or 1
      final startR = _r.nextInt(4);
      // Missing cell: pick from non-trivial positions (not col 0 — too easy)
      final missing = _r.nextInt(6) + 3; // positions 3-8
      final misRow = missing ~/ 3;
      final misCol = missing % 3;

      final sigKey = 'matDot:s$shape,f$filled,sv$subV,sd$startD,sr$startR,m$missing';
      if (_seen(sigKey)) continue;

      Map<String, dynamic> cell(int row, int col) {
        final d = (startD + col).clamp(0, 3);
        final rot = subV == 1 ? (startR + col) % 4 : startR;
        return _f(shape, rot: rot, filled: filled, dots: d);
      }

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
          cells.add(cell(r, c));

      final ans = cell(misRow, misCol);
      final ansRot = ans['rotation'] as int;
      final ansD = ans['dots'] as int;

      final res = _pack(ans, [
        _f(shape, rot: (ansRot + 1) % 4, filled: filled, dots: ansD),
        // wrong rotation
        _f(shape, rot: ansRot, filled: !filled, dots: ansD),
        // wrong fill
        _f(shape, rot: ansRot, filled: filled, dots: (ansD - 1).clamp(0, 3)),
        // one less dot
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[missing] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_dot_rotation',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': missing},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    final shape = _rotateable[_r.nextInt(_rotateable.length)];
    final cells = <Map<String, dynamic>>[];
    for (int r = 0; r < 3; r++)
      for (int c = 0; c < 3; c++)
        cells.add(_f(shape, rot: c % 4, dots: c));
    final ans = _f(shape, rot: 2, dots: 2);
    final res = _pack(ans, [
      _f(shape, rot: 1, dots: 2),
      _f(shape, rot: 2, filled: true, dots: 2),
      _f(shape, rot: 2, dots: 1)
    ]);
    final display = List<Map<String, dynamic>>.from(cells)
      ..[8] = {'empty': true};
    return ReasoningQuestion(category: 'pattern',
        type: 'matrix_dot_rotation',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
        options: res.opts,
        correctIndex: res.idx);
  }

  // ── 3c. PATTERN — inner shape progression ────────────────────────────────
  // Each row: same outer shape, fixed fill. Inner shape advances per column.
  // Col 0: inner=shape_A, col 1: inner=shape_B, col 2: inner=shape_C
  // Row rule: outer shape changes per row (same as shape cycle but with inners).
  static ReasoningQuestion _matrixInnerShape() {
    const outerShapes = [
      1,
      3,
      5
    ]; // square, diamond, pentagon — good containers
    // Inner shape sequences — clearly different from each other
    const innerSeqs = [
      [2, 7, 8], // triangle, arrow, L
      [1, 2, 3], // square, triangle, diamond
      [4, 2, 7], // cross, triangle, arrow
      [3, 8, 2], // diamond, L, triangle
    ];
    for (int attempt = 0; attempt < 30; attempt++) {
      final outerSet = _r.nextInt(outerShapes.length);
      final innerSet = _r.nextInt(innerSeqs.length);
      final missing = _r.nextInt(8) + 1;
      final mRow = missing ~/ 3;
      final mCol = missing % 3;
      final sigKey = 'matInner:os$outerSet,is$innerSet,m$missing';
      if (_seen(sigKey)) continue;

      final inners = innerSeqs[innerSet];
      Map<String, dynamic> cell(int row, int col) =>
          _f(outerShapes[row % outerShapes.length],
              filled: false,
              inner: inners[col] + 1); // +1 because inner=0 means no inner

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
          cells.add(cell(r, c));

      final ans = cell(mRow, mCol);
      final ansOuter = outerShapes[mRow % outerShapes.length];
      final ansInner = inners[mCol];

      final res = _pack(ans, [
        _f(ansOuter, filled: false, inner: inners[(mCol + 1) % 3] + 1),
        // wrong inner
        _f(ansOuter, filled: true, inner: ansInner + 1),
        // wrong fill
        _f(outerShapes[(mRow + 1) % outerShapes.length], filled: false,
            inner: ansInner + 1),
        // wrong outer
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[missing] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_inner_shape',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': missing},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    return _matrixShapeCycle();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4a. SERIES — clockwise rotation
  // ═══════════════════════════════════════════════════════════════════════════
  // All asymmetric shapes — clearly different at each 90° rotation
  static const _serRotShapes = [
    2,
    3,
    7,
    8,
    5
  ]; // triangle, diamond, arrow, L, pentagon

  static ReasoningQuestion _seriesRotation() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = _serRotShapes[_r.nextInt(_serRotShapes.length)];
      final filled = _r.nextBool();
      final start = _r.nextInt(4);
      final dots = _r.nextInt(3); // 0,1,2 — adds variety to same shape+rot
      final sigKey = 'serRot2:s$shape,f$filled,st$start,d$dots';
      if (_seen(sigKey)) continue;

      // Also cycle inner shape if subV==1 — adds compound change
      final subV2 = _r.nextInt(2); // 0=rot+dots only, 1=rot+dots+inner cycles
      final innerCy = subV2 == 1 ? (_r.nextInt(3) + 1) : 0; // 1-3 or none

      final seq = List.generate(3, (i) =>
          _f(shape, rot: (start + i) % 4, filled: filled,
              dots: dots, inner: subV2 == 1 ? ((innerCy + i - 1) % 3 + 1) : 0));
      final ansInner = subV2 == 1 ? ((innerCy + 3 - 1) % 3 + 1) : 0;
      final ans = _f(shape, rot: (start + 3) % 4,
          filled: filled,
          dots: dots,
          inner: ansInner);

      final r = _pack(ans, [
        _f(shape, rot: (start + 3) % 4,
            filled: !filled,
            dots: dots,
            inner: ansInner), // wrong fill
        _f(shape, rot: (start + 2) % 4,
            filled: filled,
            dots: dots,
            inner: ansInner), // one step back
        _f(shape, rot: (start + 3) % 4,
            filled: filled,
            dots: (dots + 1).clamp(0, 2),
            inner: ansInner), // wrong dots
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_rotation',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final seq = List.generate(3, (i) => _f(2, rot: i));
    final r = _pack(_f(2, rot: 3),
        [_f(2, rot: 3, filled: true), _f(2, rot: 2), _f(2, rot: 1)]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_rotation',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4b. SERIES — dot addition (0→1→2→3)
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesDots() {
    // sub=0: ascending  (start → start+1 → start+2 → ?)  answer = start+3
    // sub=1: descending (start → start-1 → start-2 → ?)  answer = start-3
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = _r.nextInt(6) + 1; // 1-6 (more shape variety)
      final filled = _r.nextBool();
      final sub = _r.nextBool() ? 0 : 1; // ascending or descending
      // Ascending: start 0 or 1 (so answer is 3 or 4, both valid)
      // Descending: start 3 or 4 (so answer is 0 or 1)
      final start = sub == 0
          ? _r.nextInt(2) // 0 or 1
          : _r.nextInt(2) + 3; // 3 or 4
      final step = sub == 0 ? 1 : -1;
      final ansD = (start + step * 3).clamp(0, 4);
      final sigKey = 'serDots2:s$shape,f$filled,sb$sub,st$start';
      if (_seen(sigKey)) continue;

      final seq = List.generate(3, (i) =>
          _f(shape, dots: (start + step * i).clamp(0, 4), filled: filled));
      final ans = _f(shape, dots: ansD, filled: filled);

      final d1 = (ansD + 1).clamp(0, 4);
      final d2 = (ansD - 1).clamp(0, 4);
      final d3 = (ansD + step).clamp(0, 4); // continues wrong direction

      final r = _pack(ans, [
        _f(shape, dots: d1, filled: filled),
        _f(shape, dots: d2, filled: filled),
        _f(shape, dots: ansD, filled: !filled), // right dots wrong fill
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_dots',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final seq = List.generate(3, (i) => _f(1, dots: i));
    final r = _pack(_f(1, dots: 3),
        [_f(1, dots: 2), _f(1, dots: 3, filled: true), _f(1, dots: 4)]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_dots',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4c. SERIES — fill toggles each step, rotation advances each step
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesFillToggle() {
    // Expanded: use all 5 asymmetric shapes + dots for extra variety
    const _fillShapes = [
      2,
      3,
      7,
      8,
      5
    ]; // triangle, diamond, arrow, L, pentagon
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = _fillShapes[_r.nextInt(_fillShapes.length)];
      final startFill = _r.nextBool();
      final startRot = _r.nextInt(4);
      final dots = _r.nextInt(3);
      final sigKey = 'serFill2:s$shape,sf$startFill,sr$startRot,d$dots';
      if (_seen(sigKey)) continue;

      bool fill(int i) => i.isEven ? startFill : !startFill;

      final seq = List.generate(3, (i) =>
          _f(shape, rot: (startRot + i) % 4, filled: fill(i), dots: dots));
      final ans = _f(
          shape, rot: (startRot + 3) % 4, filled: fill(3), dots: dots);

      final r = _pack(ans, [
        _f(shape, rot: (startRot + 3) % 4, filled: !fill(3), dots: dots),
        // wrong fill
        _f(shape, rot: (startRot + 2) % 4, filled: fill(2), dots: dots),
        // seq[2] rotation
        _f(shape, rot: (startRot + 3) % 4,
            filled: fill(3),
            dots: (dots + 1).clamp(0, 2)),
        // wrong dots
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_fill_toggle',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    bool fill(int i) => i.isEven;
    final seq = List.generate(3, (i) => _f(2, rot: i, filled: fill(i)));
    final r = _pack(_f(2, rot: 3, filled: fill(3)), [
      _f(2, rot: 3, filled: !fill(3)),
      _f(2, rot: 2, filled: fill(2)),
      _f(2, rot: 1, filled: fill(3))
    ]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_fill_toggle',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4d. SERIES — shape morphs (gains one side each step)
  // tri(3)→sq(4)→pent(5)→? [hex(6)]
  // Also: rotation advances AND fill toggles simultaneously
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesMorph() {
    // Shape sequences by side count
    const morphSeqs = [
      [2, 1, 5, 6], // tri → sq → pent → hex
      [1, 5, 6, 2], // sq → pent → hex → tri (wraps)
      [5, 6, 2, 1], // pent → hex → tri → sq
      [6, 2, 1, 5], // hex → tri → sq → pent
    ];

    for (int attempt = 0; attempt < 30; attempt++) {
      final seqIdx = _r.nextInt(morphSeqs.length);
      final shapes = morphSeqs[seqIdx];
      final startRot = _r.nextInt(4);
      final startFill = _r.nextBool();
      final sigKey = 'serMorph:sq$seqIdx,sr$startRot,sf$startFill';
      if (_seen(sigKey)) continue;

      // Rule: shape changes + rotation advances 90° + fill toggles each step
      bool fill(int i) => i.isEven ? startFill : !startFill;
      final seq = List.generate(3, (i) =>
          _f(
              shapes[i], rot: (startRot + i) % 4, filled: fill(i)));
      final ans = _f(shapes[3], rot: (startRot + 3) % 4, filled: fill(3));

      final r = _pack(ans, [
        _f(shapes[3], rot: (startRot + 3) % 4, filled: !fill(3)),
        // wrong fill
        _f(shapes[2], rot: (startRot + 3) % 4, filled: fill(3)),
        // previous shape
        _f(shapes[3], rot: (startRot + 2) % 4, filled: fill(3)),
        // wrong rotation
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_morph',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final seq = List.generate(3, (i) => _f([2, 1, 5][i], rot: i));
    final r = _pack(_f(6, rot: 3),
        [_f(6, rot: 3, filled: true), _f(5, rot: 3), _f(6, rot: 2)]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_morph',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ── 4d. SERIES — rotation + fill toggle simultaneously ──────────────────
  // Each step: shape rotates +90° AND fill flips. Two rules at once.
  // Harder than seriesRotation or seriesFillToggle individually.
  static ReasoningQuestion _seriesRotFill() {
    const shapes = [2, 3, 7, 8, 5];
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = shapes[_r.nextInt(shapes.length)];
      final startR = _r.nextInt(4);
      final startF = _r.nextBool();
      final dots = _r.nextInt(3);
      final sigKey = 'serRF:s$shape,sr$startR,sf$startF,d$dots';
      if (_seen(sigKey)) continue;

      final seq = List.generate(3, (i) =>
          _f(shape, rot: (startR + i) % 4,
              filled: i.isEven ? startF : !startF,
              dots: dots));
      final ansR = (startR + 3) % 4;
      final ansF = 3.isEven
          ? startF
          : !startF; // step 3 (0-indexed) is odd → !startF
      final ans = _f(shape, rot: ansR, filled: ansF, dots: dots);

      final r = _pack(ans, [
        _f(shape, rot: ansR, filled: !ansF, dots: dots),
        // right rot wrong fill
        _f(shape, rot: (ansR + 1) % 4, filled: ansF, dots: dots),
        // wrong rot right fill
        _f(shape, rot: (ansR + 1) % 4, filled: !ansF, dots: dots),
        // both wrong
      ]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_rot_fill',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final seq = List.generate(3, (i) => _f(2, rot: i, filled: i.isEven));
    final r = _pack(_f(2, rot: 3, filled: false), [
      _f(2, rot: 3, filled: true),
      _f(2, rot: 2, filled: false),
      _f(2, rot: 0, filled: false)
    ]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_rot_fill',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ── 4e. SERIES — inner shape changes each step ────────────────────────────
  // Outer shape stays fixed. Inner shape cycles through 3 different shapes.
  // Tests whether student notices inner-shape changes (common in real exam).
  static ReasoningQuestion _seriesInner() {
    const outers = [
      1,
      3,
      5,
      6
    ]; // square, diamond, pentagon, hexagon — good containers
    const innerSeqs = [
      [1, 2, 3], // square → triangle → diamond
      [2, 4, 7], // triangle → cross → arrow
      [3, 2, 8], // diamond → triangle → L
      [5, 1, 2], // pentagon → square → triangle
      [7, 3, 5], // arrow → diamond → pentagon
    ];
    for (int attempt = 0; attempt < 30; attempt++) {
      final outer = outers[_r.nextInt(outers.length)];
      final seq = innerSeqs[_r.nextInt(innerSeqs.length)];
      final filled = _r.nextBool();
      final sigKey = 'serInner:o$outer,s${seq.join('-')},f$filled';
      if (_seen(sigKey)) continue;

      final figures = List.generate(
          3, (i) => _f(outer, filled: filled, inner: seq[i] + 1));
      // Answer: next inner in the cycle (wrap around)
      final ansInner = seq[(seq.length) % seq.length]; // cycles back to first
      // Actually answer is 4th: use the pattern to continue
      // seq is length 3 — 4th would cycle: seq[0] again? No — it's a progression.
      // Better: pick the inner that doesn't appear in seq (the 4th different one)
      final allInners = [1, 2, 3, 4, 5, 6, 7, 8];
      final usedInners = seq.toSet();
      final nextCandidates = allInners
          .where((i) => !usedInners.contains(i))
          .toList();
      final ansI = nextCandidates[_r.nextInt(nextCandidates.length)];
      final ans = _f(outer, filled: filled, inner: ansI + 1);

      // Distractors: one uses a shape already in sequence, one uses different outer
      final r = _pack(ans, [
        _f(outer, filled: filled, inner: seq[0] + 1), // repeats first inner
        _f(outer, filled: filled, inner: seq[1] + 1), // repeats second inner
        _f(outer, filled: !filled, inner: ansI + 1), // right inner, wrong fill
      ]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_inner',
        puzzle: {'type': 'series', 'sequence': figures},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final figs = [_f(1, inner: 2), _f(1, inner: 3), _f(1, inner: 4)];
    final r = _pack(_f(1, inner: 5),
        [_f(1, inner: 2), _f(1, inner: 3), _f(1, filled: true, inner: 5)]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_inner',
        puzzle: {'type': 'series', 'sequence': figs},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ── 4f. SERIES — dots increase AND rotation advances together ────────────
  // Dots go 0→1→2→3 while rotation goes 0→1→2→3. Both change each step.
  static ReasoningQuestion _seriesDotsRot() {
    const shapes = [2, 3, 7, 8];
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = shapes[_r.nextInt(shapes.length)];
      final filled = _r.nextBool();
      final startD = _r.nextInt(2); // 0 or 1
      final startR = _r.nextInt(4);
      final sigKey = 'serDR:s$shape,f$filled,sd$startD,sr$startR';
      if (_seen(sigKey)) continue;

      final seq = List.generate(3, (i) =>
          _f(shape, rot: (startR + i) % 4,
              dots: (startD + i).clamp(0, 4),
              filled: filled));
      final ansD = (startD + 3).clamp(0, 4);
      final ansR = (startR + 3) % 4;
      final ans = _f(shape, rot: ansR, dots: ansD, filled: filled);

      final r = _pack(ans, [
        _f(shape, rot: ansR, dots: ansD, filled: !filled),
        // wrong fill
        _f(shape, rot: (ansR + 1) % 4, dots: ansD, filled: filled),
        // wrong rot
        _f(shape, rot: ansR, dots: (ansD - 1).clamp(0, 4), filled: filled),
        // wrong dots
      ]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_dots_rot',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final seq = List.generate(3, (i) => _f(2, rot: i, dots: i));
    final r = _pack(_f(2, rot: 3, dots: 3), [
      _f(2, rot: 3, dots: 3, filled: true),
      _f(2, rot: 2, dots: 3),
      _f(2, rot: 3, dots: 2)
    ]);
    return ReasoningQuestion(category: 'figure_series',
        type: 'series_dots_rot',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. ANALOGY  A:B :: C:?
  //
  // 5 distinct rules — randomly selected per question:
  //   Rule 0: rotate +90°, flip fill       (classic)
  //   Rule 1: rotate +180°, keep fill
  //   Rule 2: rotate +90°, add 1 dot
  //   Rule 3: flip fill only (no rotation change)
  //   Rule 4: rotate +90°, flip fill, add inner shape
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _analogy() {
    const _allAsym = [2, 3, 7, 8]; // triangle, diamond, arrow, L-shape

    for (int attempt = 0; attempt < 40; attempt++) {
      final rule = _r.nextInt(8); // 0-4 existing, 5-7 new

      // Pick two distinct asymmetric shapes for A/B pair and C/D pair
      final sh1 = _allAsym[_r.nextInt(_allAsym.length)];
      int sh2;
      do {
        sh2 = _allAsym[_r.nextInt(_allAsym.length)];
      } while (sh2 == sh1);

      final fillA = _r.nextBool();
      final rotA = _r.nextInt(4);
      final dotsA = rule == 2 ? _r.nextInt(3) : 0; // dots used in rule 2
      final innA = rule == 4 ? 0 : 0;

      // Apply rule to get B from A
      int rotB = 0;
      bool fillB = false;
      int dotsB = 0;
      int innB = 0;
      int sh1B = sh1; // for rules that morph the shape
      switch (rule) {
        case 0:
          rotB = (rotA + 1) % 4;
          fillB = !fillA;
          dotsB = dotsA;
          innB = 0;
          break;
        case 1:
          rotB = (rotA + 2) % 4;
          fillB = fillA;
          dotsB = dotsA;
          innB = 0;
          break;
        case 2:
          rotB = (rotA + 1) % 4;
          fillB = fillA;
          dotsB = (dotsA + 1).clamp(0, 3);
          innB = 0;
          break;
        case 3:
          rotB = rotA;
          fillB = !fillA;
          dotsB = dotsA;
          innB = 0;
          break;
        case 5:
          rotB = rotA;
          fillB = fillA;
          dotsB = dotsA;
          innB = 0;
          break;
        case 6:
          rotB = (rotA + 1) % 4;
          fillB = fillA;
          dotsB = (dotsA + 2).clamp(0, 4);
          innB = 0;
          break;
        case 7:
          rotB = (rotA + 2) % 4;
          fillB = fillA;
          dotsB = dotsA;
          innB = innA;
          break;
        default: // rule 4: adds inner shape
          rotB = (rotA + 1) % 4;
          fillB = !fillA;
          dotsB = 0;
          innB = _r.nextInt(3) + 1;
          break;
      }

      // C is a fresh random state for sh2
      final rotC = _r.nextInt(4);
      final fillC = _r.nextBool();
      final dotsC = rule == 2 ? _r.nextInt(3) : 0;

      // Apply same rule to get D from C
      int rotD = 0;
      bool fillD = false;
      int dotsD = 0;
      int innD = 0;
      int sh2D = sh2; // for rules that morph the shape
      switch (rule) {
        case 0:
          rotD = (rotC + 1) % 4;
          fillD = !fillC;
          dotsD = dotsC;
          innD = 0;
          break;
        case 1:
          rotD = (rotC + 2) % 4;
          fillD = fillC;
          dotsD = dotsC;
          innD = 0;
          break;
        case 2:
          rotD = (rotC + 1) % 4;
          fillD = fillC;
          dotsD = (dotsC + 1).clamp(0, 3);
          innD = 0;
          break;
        case 3:
          rotD = rotC;
          fillD = !fillC;
          dotsD = dotsC;
          innD = 0;
          break;
        case 4:
          rotD = (rotC + 1) % 4;
          fillD = !fillC;
          dotsD = 0;
          innD = innB;
          break;
        case 5:
          rotD = rotC;
          fillD = fillC;
          dotsD = dotsC;
          innD = 0;
          break;
        case 6:
          rotD = (rotC + 1) % 4;
          fillD = fillC;
          dotsD = (dotsC + 2).clamp(0, 4);
          innD = 0;
          break;
        default:
          rotD = (rotC + 2) % 4;
          fillD = fillC;
          dotsD = dotsC;
          innD = innA;
          break;
      }

      final sigKey = 'analogy2:s1$sh1,s2$sh2,rA$rotA,rC$rotC,rule$rule';
      if (_seen(sigKey)) continue;

      final ans = _f(sh2D, rot: rotD, filled: fillD, dots: dotsD, inner: innD);

      // Distractors test each part of the rule independently
      final res = _pack(ans, [
        _f(sh2D, rot: (rotD + 1) % 4, filled: fillD, dots: dotsD, inner: innD),
        // wrong rot
        _f(sh2D, rot: rotD, filled: !fillD, dots: dotsD, inner: innD),
        // wrong fill
        _f(sh2D, rot: rotD,
            filled: fillD,
            dots: (dotsD - 1).clamp(0, 3),
            inner: innD),
        // wrong dots
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'analogy',
        type: 'analogy_r$rule',
        puzzle: {
          'type': 'analogy',
          'A': _f(sh1, rot: rotA, filled: fillA, dots: dotsA, inner: innA),
          'B': _f(sh1B, rot: rotB, filled: fillB, dots: dotsB, inner: innB),
          'C': _f(sh2, rot: rotC, filled: fillC, dots: dotsC),
        },
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    // Fallback
    final ans = _f(3, rot: 1, filled: true);
    final res = _pack(ans, [
      _f(3, rot: 2, filled: true),
      _f(3, rot: 1),
      _f(3, rot: 3, filled: true)
    ]);
    return ReasoningQuestion(category: 'analogy',
        type: 'analogy_r0',
        puzzle: {
          'type': 'analogy',
          'A': _f(2, rot: 0),
          'B': _f(2, rot: 1, filled: true),
          'C': _f(3, rot: 0)
        },
        options: res.opts,
        correctIndex: res.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. GEO COMPLETION (real Navodaya format)
  //
  // A geometric shape (square/triangle/circle) is split into 2 pieces.
  // The question shows piece 0. Student picks which of 4 options is piece 1
  // (the complement that completes the full shape).
  //
  // Wrong options:
  //   wrong1 — same piece as question (mirror trap: student picks same side)
  //   wrong2 — same shape, different cut, piece 1 (looks valid but wrong fit)
  //   wrong3 — different shape, piece 1 (completely wrong)
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _geoCompletion() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final shape = _r.nextInt(3); // 0=square 1=triangle 2=circle
      final maxCut = shape == 0 ? 8 : 4;
      final cut = _r.nextInt(maxCut);
      final sigKey = 'geo3:sh$shape,c$cut';
      if (_seen(sigKey)) continue;

      final qPiece = {
        'type': 'geo_piece',
        'shape': shape,
        'cut': cut,
        'piece': 0
      };
      final correct = {
        'type': 'geo_piece',
        'shape': shape,
        'cut': cut,
        'piece': 1
      };
      final wrong1 = {
        'type': 'geo_piece',
        'shape': shape,
        'cut': cut,
        'piece': 0
      };
      final altCut = (cut + 1 + _r.nextInt(maxCut - 1)) % maxCut;
      final wrong2 = {
        'type': 'geo_piece',
        'shape': shape,
        'cut': altCut,
        'piece': 1
      };
      final altShape = (shape + 1 + _r.nextInt(2)) % 3;
      final altMaxCut = altShape == 0 ? 8 : 4;
      final wrong3 = {
        'type': 'geo_piece',
        'shape': altShape,
        'cut': _r.nextInt(altMaxCut),
        'piece': 1
      };

      final res = _pack(correct, [wrong1, wrong2, wrong3]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'geo_completion',
        type: 'geo_jigsaw',
        puzzle: {'type': 'geo_completion', 'piece': qPiece},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    final q = {'type': 'geo_piece', 'shape': 0, 'cut': 2, 'piece': 0};
    final a = {'type': 'geo_piece', 'shape': 0, 'cut': 2, 'piece': 1};
    final res = _pack(a, [
      {'type': 'geo_piece', 'shape': 0, 'cut': 2, 'piece': 0},
      {'type': 'geo_piece', 'shape': 0, 'cut': 1, 'piece': 1},
      {'type': 'geo_piece', 'shape': 1, 'cut': 0, 'piece': 1},
    ]);
    return ReasoningQuestion(
      category: 'geo_completion',
      type: 'geo_jigsaw',
      puzzle: {'type': 'geo_completion', 'piece': q},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. MIRROR SHAPE
  // ═══════════════════════════════════════════════════════════════════════════
  // All asymmetric shapes available for mirror questions
  static const _mirrorShapes = [
    2,
    7,
    8
  ]; // triangle, arrow, L-shape (all truly asymmetric under horizontal mirror)

  static ReasoningQuestion _mirrorShape() {
    // Root cause of repeating options: wrong1/wrong2/wrong3 all used the SAME
    // shape with small rotation/fill changes — for some rotations these look
    // identical visually (e.g. diamond rot+2 = diamond rot+0 looks same).
    //
    // Fix: each wrong option uses a DIFFERENT shape from the answer shape.
    // This guarantees all 4 cards look clearly distinct regardless of rotation.
    //
    // Option layout:
    //   CORRECT — target shape, mirror:true,  same rot+fill   (the real mirror)
    //   WRONG 1 — DIFFERENT shape, mirror:true,  same rot+fill (different shape, mirrored)
    //   WRONG 2 — target shape,   mirror:false, same rot+fill  (original, no flip)
    //   WRONG 3 — DIFFERENT shape, mirror:false, same rot+fill (different shape, no flip)

    for (int attempt = 0; attempt < 60; attempt++) {
      final shape = _mirrorShapes[_r.nextInt(_mirrorShapes.length)];
      final rot = _r.nextInt(4);
      final filled = _r.nextBool();
      final sigKey = 'mirror5:s$shape,r$rot,f$filled';
      if (_seen(sigKey)) continue;

      // Pick two different shapes for wrong options — must differ from each other
      // and from the target shape
      final otherShapes = _mirrorShapes.where((s) => s != shape).toList()
        ..shuffle(_r);
      final altShape1 = otherShapes[0]; // for wrong1 (different shape, mirrored)
      final altShape2 = otherShapes[1]; // for wrong3 (different shape, not mirrored)

      final target = _f(
          shape, rot: rot, filled: filled, mirror: false); // shown in puzzle
      final ans = _f(shape, rot: rot,
          filled: filled,
          mirror: true); // CORRECT: mirror of target
      final wrong1 = _f(altShape1, rot: rot,
          filled: filled,
          mirror: true); // wrong shape, mirrored
      final wrong2 = _f(shape, rot: (rot + 1) % 4,
          filled: filled,
          mirror: false); // target shape rotated 90°, no mirror
      final wrong3 = _f(altShape2, rot: rot,
          filled: !filled,
          mirror: false); // wrong shape, fill flipped

      final r = _pack(ans, [wrong1, wrong2, wrong3]);
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_shape',
        type: 'mirror_shape',
        puzzle: {'type': 'mirror_shape', 'target': target},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final r = _pack(
        _f(2, rot: 0, mirror: true),
        [_f(7, rot: 0, mirror: true), _f(2, rot: 0), _f(8, rot: 0)]
    );
    return ReasoningQuestion(category: 'mirror_shape',
        type: 'mirror_shape',
        puzzle: {'type': 'mirror_shape', 'target': _f(2)},
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. MIRROR TEXT
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _mirrorText() {
    final sub = _r.nextInt(
        4); // 0=single letter, 1=word, 2=number string, 3=clock
    // Single asymmetric letters (symmetric ones like A,H,I,M,O,T,U,V,W,X look same mirrored)
    const letters = [
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'J',
      'K',
      'L',
      'N',
      'P',
      'Q',
      'R',
      'S',
      'Y',
      'Z'
    ];
    // Words and short strings from actual Navodaya exam papers
    const words = ['FAN', 'RUN', 'UNR', 'NKU', 'CLASS', 'KOON', 'VERBAL',
      'STROKE', 'BUZZER', 'FORTIFY', 'VINAY', 'MALA', 'LITY',
      'NIAL', 'GARH', 'VIR', 'STU', 'DIAN', 'HEN', 'FIX',
      'KR', 'AB', 'NAME', 'RICE', 'BIRD', 'LEAF', 'FACE', 'GOLD'];
    // Number strings that appear in Navodaya exams
    const numbers = [
      '634',
      '2475',
      '1869',
      '3748',
      '9261',
      '5432',
      '7813',
      '4096',
      '2634',
      '1478',
      '5923',
      '3867'
    ];
    const digits = ['2', '3', '4', '5', '6', '7'];

    for (int attempt = 0; attempt < 20; attempt++) {
      late Map<String, dynamic> base;
      late String sigKey;
      switch (sub) {
        case 0: // single asymmetric letter
          final ch = letters[_r.nextInt(letters.length)];
          sigKey = 'mirText:$ch';
          base = {'content': ch, 'is_clock': false};
          break;
        case 1: // word / short string (most common in real exam)
          final w = words[_r.nextInt(words.length)];
          sigKey = 'mirText:$w';
          base = {'content': w, 'is_clock': false};
          break;
        case 2: // number string
          final n = numbers[_r.nextInt(numbers.length)];
          sigKey = 'mirText:$n';
          base = {'content': n, 'is_clock': false};
          break;
        default: // clock
          final h = _r.nextInt(12) + 1;
          final m2 = [0, 15, 30, 45][_r.nextInt(4)];
          sigKey = 'mirText:${h}h${m2}m';
          base = {'is_clock': true, 'clock_hour': h, 'clock_minute': m2};
      }
      if (_seen(sigKey)) continue;

      // Real Navodaya format: only LEFT-RIGHT mirror tested.
      // 4 options: correct mirror + 3 wrong variants that look clearly different.
      //
      // For letters/words: wrong options use different rotation offsets so each
      // option card looks distinct (not 4 nearly-identical copies).
      // For clocks: wrong options are different times (hour/minute shifted).
      //
      // mirror_v removed — vertical flip is nearly invisible for most letters
      // and doesn't appear in actual Navodaya papers.

      final List<Map<String, dynamic>> combos;
      final int correctIdx;

      if (base['is_clock'] == true) {
        // Clock: correct=mirrored, wrongs=different times (not mirrored)
        final h = base['clock_hour'] as int;
        final m2 = base['clock_minute'] as int;
        final mk = (int dh, int dm, bool mir) =>
        {
          ...base, 'type': 'mirror_text',
          'clock_hour': ((h + dh - 1) % 12) + 1,
          'clock_minute': (m2 + dm) % 60,
          'mirror_h': mir, 'mirror_v': false,
        };
        final correct = mk(0, 0, true); // correct mirror
        final wrong1 = mk(0, 0, false); // original (no mirror)
        final wrong2 = mk(3, 0, true); // mirrored, different hour
        final wrong3 = mk(0, 15, false); // different minute, no mirror
        final all = [correct, wrong1, wrong2, wrong3]..shuffle(_r);
        correctIdx = all.indexOf(correct);
        combos = all;
      } else {
        // Letter/word/number: correct=mirrored, wrongs use rotation
        // We show the same content but one option is mirrored and 3 are not,
        // but each "not mirrored" option has a slightly different visual treatment
        // via rotation — this makes them look clearly distinct.
        //
        // For single-char content the rotation trick doesn't work — use
        // similar-looking alternate letters as distractors.
        final content = base['content'] as String;
        final isSingle = content.length == 1;

        // Similar-looking letter pairs for single-char distractors
        const lookalike = {
          'B': ['D', 'P', 'R'], 'C': ['G', 'D', 'O'], 'D': ['B', 'O', 'C'],
          'E': ['F', 'B', '3'], 'F': ['E', 'P', 'T'], 'G': ['C', 'O', 'Q'],
          'J': ['L', 'I', '1'], 'K': ['R', 'X', 'H'], 'L': ['J', 'I', '1'],
          'N': ['M', 'H', 'Z'], 'P': ['B', 'F', 'R'], 'Q': ['O', 'G', 'C'],
          'R': ['P', 'B', 'K'], 'S': ['5', 'Z', '2'], 'Y': ['V', 'T', '7'],
          'Z': ['S', 'N', '2'], '2': ['S', 'Z', '5'], '3': ['E', 'B', '8'],
          '4': ['9', 'A', 'H'], '5': ['S', '2', '6'], '6': ['9', 'b', 'G'],
          '7': ['Y', 'T', 'L'], '9': ['6', '4', 'P'],
        };

        Map<String, dynamic> mkW(String c, bool mir) =>
            {
              ...base, 'content': c, 'type': 'mirror_text',
              'mirror_h': mir, 'mirror_v': false,
            };

        late List<Map<String, dynamic>> all;
        if (isSingle) {
          // For single chars: all 4 show SAME letter with different mirror/flip combos
          // This matches real exam format — student must identify LEFT-RIGHT mirror only
          final correct = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': true,
            'mirror_v': false
          }; // correct
          final wrong1 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': false,
            'mirror_v': false
          }; // original
          final wrong2 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': false,
            'mirror_v': true
          }; // vertical flip
          final wrong3 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': true,
            'mirror_v': true
          }; // both flipped
          all = [correct, wrong1, wrong2, wrong3]..shuffle(_r);
          correctIdx = all.indexOf(correct);
        } else {
          // Word/number: all 4 show same content, only 1 is correctly mirrored
          // Other 3 have mirror_h=false so student must spot the real left-right flip
          // To make them visually different, vary the content slightly for 2 of them
          // Real Navodaya format: all 4 options show the SAME word.
          // Student identifies which option is the correct LEFT-RIGHT mirror.
          // wrong1 = original (no flip) — clearly different from mirror ✓
          // wrong2 = mirrored + flipped vertically (wrong axis) — looks wrong ✓
          // wrong3 = original with wrong rotation — rotated 180° ✓
          // All 4 are visually distinct because mirror_h flips left↔right
          // which is obvious for asymmetric letters.
          final correct = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': true,
            'mirror_v': false
          };
          final wrong1 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': false,
            'mirror_v': false
          }; // original
          final wrong2 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': false,
            'mirror_v': true
          }; // vertical flip
          final wrong3 = {
            ...base,
            'type': 'mirror_text',
            'mirror_h': true,
            'mirror_v': true
          }; // both flipped
          all = [correct, wrong1, wrong2, wrong3]..shuffle(_r);
          correctIdx = all.indexOf(correct);
        }
        combos = all;
      }

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_text',
        type: 'mirror_text_$sub',
        puzzle: {
          ...base,
          'type': 'mirror_text',
          'mirror_h': false,
          'mirror_v': false
        },
        options: combos,
        correctIndex: correctIdx,
      );
    }
    // Fallback
    final fb = [
      {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': true,
        'mirror_v': false
      },
      {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': false
      },
      {
        'content': 'D',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': true,
        'mirror_v': false
      },
      {
        'content': 'P',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': false
      },
    ]
      ..shuffle(_r);
    return ReasoningQuestion(category: 'mirror_text',
        type: 'mirror_text_0',
        puzzle: {
          'content': 'B',
          'is_clock': false,
          'type': 'mirror_text',
          'mirror_h': false,
          'mirror_v': false
        },
        options: fb,
        correctIndex: fb.indexWhere((c) =>
        c['content'] == 'B' && c['mirror_h'] == true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. PUNCH HOLE
  // Fixed: wrongs now use same axis but different positions (not opposite axis)
  // ═══════════════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════════════
  // PUNCH HOLE
  //
  // How it works visually:
  //   • Puzzle shows folded paper with 1 punched hole.
  //   • Student must pick which unfolded result is correct.
  //
  // Distractor strategy — all 4 options are valid-looking punch hole results
  // (no shapes / figures). They differ in WHERE the symmetric holes land:
  //
  //   CORRECT  → holes mirrored on the actual fold axis
  //   WRONG A  → holes mirrored on the OPPOSITE axis  (common mistake)
  //   WRONG B  → both axes mirrored (double-fold result — too many holes)
  //   WRONG C  → only 1 hole shown (student forgot unfolding doubles it)
  //
  // Fold types:
  //   axis=0: vertical fold   (paper folded left→right, crease is vertical centre)
  //   axis=1: horizontal fold (paper folded top→bottom, crease is horizontal centre)
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _punchHole() {
    // foldType: 0=vertical single fold, 1=horizontal single fold,
    //           2=double fold (vertical then horizontal → 4 holes when unfolded)
    final foldType = _r.nextInt(3);
    final foldAxis = foldType == 2 ? 2 : foldType; // axis for PunchPainter

    // Pre-defined hole positions always inside the visible (non-folded) quadrant
    // axis=0: hole in left half (x < 0.5), any y
    // axis=1: hole in top half  (y < 0.5), any x
    // For double fold: hole must be in top-left quadrant (x<0.5, y<0.5)
    final positions = foldType == 2
        ? [
      {'x': 0.22, 'y': 0.22}, {'x': 0.22, 'y': 0.38},
      {'x': 0.35, 'y': 0.22}, {'x': 0.35, 'y': 0.35},
      {'x': 0.28, 'y': 0.28}, {'x': 0.42, 'y': 0.30},
      {'x': 0.30, 'y': 0.42}, {'x': 0.40, 'y': 0.40},
    ]
        : foldType == 0
        ? [
      {'x': 0.18, 'y': 0.25}, {'x': 0.18, 'y': 0.50}, {'x': 0.18, 'y': 0.75},
      {'x': 0.28, 'y': 0.20}, {'x': 0.28, 'y': 0.50}, {'x': 0.28, 'y': 0.80},
      {'x': 0.35, 'y': 0.35}, {'x': 0.35, 'y': 0.65},
      {'x': 0.22, 'y': 0.38}, {'x': 0.22, 'y': 0.62},
      {'x': 0.30, 'y': 0.28}, {'x': 0.30, 'y': 0.72},
    ]
        : [
      {'x': 0.25, 'y': 0.18}, {'x': 0.50, 'y': 0.18}, {'x': 0.75, 'y': 0.18},
      {'x': 0.20, 'y': 0.28}, {'x': 0.50, 'y': 0.28}, {'x': 0.80, 'y': 0.28},
      {'x': 0.35, 'y': 0.35}, {'x': 0.65, 'y': 0.35},
      {'x': 0.38, 'y': 0.22}, {'x': 0.62, 'y': 0.22},
      {'x': 0.28, 'y': 0.30}, {'x': 0.72, 'y': 0.30},
    ];
    positions.shuffle(_r);

    final hp = positions[0];
    final hx = (hp['x'] as num).toDouble();
    final hy = (hp['y'] as num).toDouble();
    final sigKey = 'punch:ft$foldType,x${hx.toStringAsFixed(2)},y${hy
        .toStringAsFixed(2)}';

    // ── Build all 4 option types ────────────────────────────────────────────

    // CORRECT: unfold along actual fold axis/axes
    final correctHoles = foldType == 2
        ? [ // double fold → 4 holes (mirror both axes)
      {'x': hx, 'y': hy},
      {'x': 1.0 - hx, 'y': hy},
      {'x': hx, 'y': 1.0 - hy},
      {'x': 1.0 - hx, 'y': 1.0 - hy},
    ]
        : foldType == 0
        ? [{'x': hx, 'y': hy}, {'x': 1.0 - hx, 'y': hy}]
        : [{'x': hx, 'y': hy}, {'x': hx, 'y': 1.0 - hy}];

    // ── Distractors with VARIED positions so they don't look the same ────────
    // Pick a nearby alternative hole position (different from the actual hole)
    // for use in structural distractors — avoids all 4 options looking like
    // "same paper, just different dot positions"
    final altPositions = List<Map<String, num>>.from(positions)
        .where((p) =>
    (p['x']! - hx).abs() > 0.05 || (p['y']! - hy).abs() > 0.05)
        .toList()
      ..shuffle(_r);
    final altHx = altPositions.isNotEmpty
        ? (altPositions[0]['x'] as num).toDouble() : (hx + 0.1).clamp(
        0.15, 0.45);
    final altHy = altPositions.isNotEmpty
        ? (altPositions[0]['y'] as num).toDouble() : (hy + 0.1).clamp(
        0.15, 0.85);

    // WRONG A: opposite axis / only vertical mirror for double fold
    final wrongA_holes = foldType == 2
        ? [
      {'x': hx, 'y': hy},
      {'x': 1.0 - hx, 'y': hy}
    ] // only mirrored x (forgot y)
        : foldType == 0
        ? [{'x': hx, 'y': hy}, {'x': hx, 'y': 1.0 - hy}]
        : [{'x': hx, 'y': hy}, {'x': 1.0 - hx, 'y': hy}];

    // WRONG B: correct axis but different position
    final wrongB_holes = foldType == 2
        ? [{'x': altHx, 'y': altHy}, {'x': 1.0 - altHx, 'y': altHy},
      {'x': altHx, 'y': 1.0 - altHy}, {'x': 1.0 - altHx, 'y': 1.0 - altHy}]
        : foldType == 0
        ? [{'x': altHx, 'y': altHy}, {'x': 1.0 - altHx, 'y': altHy}]
        : [{'x': altHx, 'y': altHy}, {'x': altHx, 'y': 1.0 - altHy}];

    // WRONG C: single hole only (forgot unfolding multiplies holes)
    final wrongC_holes = [{'x': hx, 'y': hy}];

    Map<String, dynamic> _opt(List<Map<String, dynamic>> holes) =>
        {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': foldAxis,
          'holes': holes,
        };

    final correct = _opt(correctHoles);
    final wrongs = [
      _opt(wrongA_holes),
      _opt(wrongB_holes),
      _opt(wrongC_holes),
    ];

    final r = _pack(correct, wrongs);
    _markSeen(sigKey);
    return ReasoningQuestion(
      category: 'punch_hole',
      type: 'punch_hole',
      puzzle: {
        'type': 'punch_hole',
        'folded': true,
        'fold_axis': foldAxis,
        'holes': [{'x': hx, 'y': hy}],
      },
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  static List<Map<String, dynamic>> _unfold(Map<String, double> h, int axis) {
    final x = h['x']!;
    final y = h['y']!;
    if (axis == 0) return [{'x': x, 'y': y}, {'x': 1.0 - x, 'y': y}];
    return [{'x': x, 'y': y}, {'x': x, 'y': 1.0 - y}];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. EMBEDDED FIGURE
  //
  // Design: Show a simple TARGET shape (triangle, square, diamond, arrow).
  // Ask: "Which of the 4 options contains this shape hidden inside it?"
  //
  // Implementation: Each option is a COMPOSITE figure — two shapes overlaid
  // or adjacently placed. Exactly one option contains the target shape as
  // one of its two components. The other three contain different shape pairs
  // that do NOT include the target.
  //
  // Data format for options:
  //   {'type': 'embedded_option', 'shapes': [shapeA, shapeB], 'offset': 1-4}
  //   shapeA, shapeB are normal FigurePainter data maps.
  //   offset controls where shape B is placed relative to A (1=TR,2=BR,3=BL,4=TL)
  //
  // The correct option always has the TARGET as shapeA and a random companion
  // as shapeB. Wrong options have two non-target shapes.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _embedded() {
    // Key improvement over v1:
    // Each option now shows 3 shapes (a small cluster), not 2.
    // The correct option contains the target as one of its 3.
    // Wrong options contain 3 shapes that DON'T include the target.
    // The target position within the cluster is random (not always shapeA).
    // This makes the question genuinely require visual search, not just
    // "which option has 2 shapes and one of them looks like the target?"

    const _embShapes = [1, 2, 3, 7, 8]; // square, triangle, diamond, arrow, L

    for (int attempt = 0; attempt < 40; attempt++) {
      final targetShape = _embShapes[_r.nextInt(_embShapes.length)];
      final targetFilled = _r.nextBool();
      final targetRot = _r.nextInt(4); // target can be rotated — harder
      final targetPos = _r.nextInt(3); // where in the triple the target sits
      final sigKey = 'embed3:s$targetShape,f$targetFilled,r$targetRot,tp$targetPos';
      if (_seen(sigKey)) continue;

      final target = _f(targetShape, filled: targetFilled, rot: targetRot);

      // Build correct option: 3 shapes, target is at random position targetPos
      List<Map<String, dynamic>> correctShapes(int tp) {
        final shapes = <Map<String, dynamic>>[];
        final used = <int>{targetShape};
        for (int i = 0; i < 3; i++) {
          if (i == tp) {
            shapes.add(target);
          } else {
            int s;
            do {
              s = _embShapes[_r.nextInt(_embShapes.length)];
            }
            while (used.contains(s));
            used.add(s);
            shapes.add(_f(s, filled: _r.nextBool(), rot: _r.nextInt(4)));
          }
        }
        return shapes;
      }

      final correct = {
        'type': 'embedded_option',
        'shapes': correctShapes(targetPos),
        'offset': _r.nextInt(4) + 1,
        'contains_target': true,
      };

      // Wrong options: 3 shapes, none is the target shape
      final wrongs = <Map<String, dynamic>>[];
      final usedTriples = <String>{};
      int safety = 0;
      while (wrongs.length < 3 && safety < 60) {
        safety++;
        final used = <int>{targetShape};
        final triple = <Map<String, dynamic>>[];
        bool valid = true;
        for (int i = 0; i < 3; i++) {
          int s;
          int tries = 0;
          do {
            s = _embShapes[_r.nextInt(_embShapes.length)];
            tries++;
          } while (used.contains(s) && tries < 10);
          if (used.contains(s)) {
            valid = false;
            break;
          }
          used.add(s);
          triple.add(_f(s, filled: _r.nextBool(), rot: _r.nextInt(4)));
        }
        if (!valid) continue;
        final key = triple.map((t) => t['shape']).toList()
          ..sort();
        final tk = key.join('-');
        if (usedTriples.contains(tk)) continue;
        usedTriples.add(tk);
        wrongs.add({
          'type': 'embedded_option',
          'shapes': triple,
          'offset': _r.nextInt(4) + 1,
          'contains_target': false,
        });
      }

      while (wrongs.length < 3) {
        wrongs.add({
          'type': 'embedded_option',
          'shapes': [_f(3), _f(1, filled: true), _f(8)],
          'offset': 2, 'contains_target': false,
        });
      }

      final pos = _r.nextInt(4);
      final opts = List<Map<String, dynamic>>.from(wrongs)
        ..insert(pos, correct);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'embedded',
        type: 'embedded',
        puzzle: {'type': 'embedded', 'target': target},
        options: opts,
        correctIndex: pos,
      );
    }
    // Fallback
    final target = _f(2, filled: false, rot: 0);
    final pos = _r.nextInt(4);
    final opts = <Map<String, dynamic>>[
      {
        'type': 'embedded_option',
        'shapes': [_f(3), _f(1, filled: true), _f(8)],
        'offset': 1,
        'contains_target': false
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(1), _f(7, filled: true), _f(3)],
        'offset': 2,
        'contains_target': false
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(7), _f(3, filled: true), _f(1)],
        'offset': 3,
        'contains_target': false
      },
    ];
    opts.insert(pos, {
      'type': 'embedded_option',
      'shapes': [target, _f(3, filled: true), _f(8)],
      'offset': 2,
      'contains_target': true
    });
    return ReasoningQuestion(
      category: 'embedded',
      type: 'embedded',
      puzzle: {'type': 'embedded', 'target': target},
      options: opts,
      correctIndex: pos,
    );
  }
}