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

  static bool _seen(String sig) => _history.contains(sig);
  static void _markSeen(String sig) {
    _history.add(sig);
    _totalGenerated++;
    if (_totalGenerated % 120 == 0) _history
        .clear(); // reset every 120 questions
  }

  static ReasoningQuestion generate(String category) {
    switch (category) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'pattern':
        return _r.nextBool() ? _matrixShapeCycle() : _matrixDotRotation();
      case 'figure_series':
        return [_seriesRotation, _seriesDots, _seriesFillToggle][_r.nextInt(
            3)]();
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
      final v = _r.nextInt(5); // 5 clean variants
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
      // Rule: 3 have no inner shape, 1 has a small inner shape.
      // All same outer shape + rotation + fill.
        default:
          {
            final s = _r.nextInt(4) + 1; // 1-4
            final rot = _r.nextInt(4);
            final filled = false; // outline so inner is visible
            final innerS = _r.nextInt(3) + 1; // 1=circle 2=square 3=triangle
            sigKey = 'oddE:s$s,r$rot,i$innerS,cp$cp';
            opts = List.generate(4, (i) =>
                _f(s, rot: rot, filled: filled, inner: i == cp ? innerS : 0));
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
  static ReasoningQuestion _matrixShapeCycle() {
    for (int attempt = 0; attempt < 20; attempt++) {
      // Use only asymmetric shapes so rotation is visible in every row
      const rowShapes = [1, 2, 3]; // square, triangle, diamond
      final baseRot = _r.nextInt(4);
      final sigKey = 'matShape:br$baseRot';
      if (_seen(sigKey)) continue;

      final cells = <Map<String, dynamic>>[];
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          cells.add(_f(rowShapes[row],
            rot: (baseRot + col) % 4,
            filled: row == 1,
          ));
        }
      }

      // Answer: row2(diamond), col2 = (baseRot+2)%4, outline
      final ans = _f(3, rot: (baseRot + 2) % 4, filled: false);
      final res = _pack(ans, [
        _f(3, rot: (baseRot + 1) % 4, filled: false), // wrong rotation
        _f(3, rot: (baseRot + 2) % 4, filled: true), // wrong fill
        _f(2, rot: (baseRot + 2) % 4, filled: false), // wrong shape
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[8] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_shape_cycle',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
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
    for (int attempt = 0; attempt < 20; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final filled = _r.nextBool();
      final sigKey = 'matDot:s$shape,f$filled';
      if (_seen(sigKey)) continue;

      final cells = <Map<String, dynamic>>[];
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          cells.add(_f(shape, rot: col % 4, filled: filled, dots: col));
        }
      }

      final ans = _f(shape, rot: 2, filled: filled, dots: 2);
      final res = _pack(ans, [
        _f(shape, rot: 1, filled: filled, dots: 2),
        _f(shape, rot: 2, filled: !filled, dots: 2),
        _f(shape, rot: 2, filled: filled, dots: 1),
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[8] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_dot_rotation',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    // Fallback with different shape
    final shape = _rotateable[_r.nextInt(_rotateable.length)];
    final cells = <Map<String, dynamic>>[];
    for (int row = 0; row < 3; row++)
      for (int col = 0; col < 3; col++)
        cells.add(_f(shape, rot: col % 4, dots: col));
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 4a. SERIES — clockwise rotation
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesRotation() {
    for (int attempt = 0; attempt < 20; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final filled = _r.nextBool();
      final start = _r.nextInt(4);
      final sigKey = 'serRot:s$shape,f$filled,st$start';
      if (_seen(sigKey)) continue;

      final seq = List.generate(
          3, (i) => _f(shape, rot: (start + i) % 4, filled: filled));
      final ans = _f(shape, rot: (start + 3) % 4, filled: filled);

      // Distinct distractors: fill-flipped, 2-steps-back, 1-step-back
      // Avoid (start+4)%4 = start which could equal sequence[0]
      final r = _pack(ans, [
        _f(shape, rot: (start + 3) % 4, filled: !filled),
        // same rot, wrong fill
        _f(shape, rot: (start + 2) % 4, filled: filled),
        // one step back
        _f(shape, rot: (start + 1) % 4, filled: filled),
        // two steps back
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
    for (int attempt = 0; attempt < 20; attempt++) {
      final shape = _r.nextInt(4) + 1; // 1-4 (no circle)
      final filled = _r.nextBool();
      final sigKey = 'serDots:s$shape,f$filled';
      if (_seen(sigKey)) continue;

      final seq = List.generate(3, (i) => _f(shape, dots: i, filled: filled));
      final ans = _f(shape, dots: 3, filled: filled);

      // Distractors: same shape different dot counts, one with fill flipped
      final r = _pack(ans, [
        _f(shape, dots: 2, filled: filled),
        // one less (already in seq but valid distractor)
        _f(shape, dots: 3, filled: !filled),
        // right dots, wrong fill
        _f(shape, dots: 1, filled: filled),
        // two less
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
        [_f(1, dots: 2), _f(1, dots: 3, filled: true), _f(1, dots: 1)]);
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
    for (int attempt = 0; attempt < 20; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final startFill = _r.nextBool();
      final startRot = _r.nextInt(4);
      final sigKey = 'serFill:s$shape,sf$startFill,sr$startRot';
      if (_seen(sigKey)) continue;

      bool fill(int i) => i.isEven ? startFill : !startFill;

      final seq = List.generate(
          3, (i) => _f(shape, rot: (startRot + i) % 4, filled: fill(i)));
      final ans = _f(shape, rot: (startRot + 3) % 4, filled: fill(3));

      // Safe distractors — none equals the answer
      // D1: right rotation, wrong fill
      // D2: one step back in rotation (=seq[2]), right fill
      // D3: two steps back, right fill
      final r = _pack(ans, [
        _f(shape, rot: (startRot + 3) % 4, filled: !fill(3)),
        // wrong fill
        _f(shape, rot: (startRot + 2) % 4, filled: fill(2)),
        // seq[2] rotation
        _f(shape, rot: (startRot + 1) % 4, filled: fill(3)),
        // different rotation, right fill
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
  // 5. ANALOGY  A:B :: C:?   Rule: rotate +90°, flip fill
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _analogy() {
    for (int attempt = 0; attempt < 20; attempt++) {
      final sh1 = _rotateable[_r.nextInt(_rotateable.length)];
      // sh2 must be different and also asymmetric so the rule is visible
      int sh2;
      do {
        sh2 = _rotateable[_r.nextInt(_rotateable.length)];
      } while (sh2 == sh1);

      final fillA = _r.nextBool();
      final rotA = _r.nextInt(4);
      final fillC = _r.nextBool();
      final rotC = _r.nextInt(4);
      final fillD = !fillC;
      final rotD = (rotC + 1) % 4;
      final sigKey = 'analogy:s1$sh1,s2$sh2,rA$rotA,rC$rotC';
      if (_seen(sigKey)) continue;

      final ans = _f(sh2, rot: rotD, filled: fillD);
      final r = _pack(ans, [
        _f(sh2, rot: (rotD + 1) % 4, filled: fillD), // wrong rotation
        _f(sh2, rot: rotD, filled: !fillD), // wrong fill
        _f(sh2, rot: (rotD + 2) % 4, filled: !fillD), // both wrong
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'analogy',
        type: 'analogy',
        puzzle: {
          'type': 'analogy',
          'A': _f(sh1, rot: rotA, filled: fillA),
          'B': _f(sh1, rot: (rotA + 1) % 4, filled: !fillA),
          'C': _f(sh2, rot: rotC, filled: fillC),
        },
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final ans = _f(3, rot: 1, filled: true);
    final r = _pack(ans, [
      _f(3, rot: 2, filled: true),
      _f(3, rot: 1),
      _f(3, rot: 3, filled: true)
    ]);
    return ReasoningQuestion(category: 'analogy',
        type: 'analogy',
        puzzle: {
          'type': 'analogy',
          'A': _f(2, rot: 0),
          'B': _f(2, rot: 1, filled: true),
          'C': _f(3, rot: 0, filled: false)
        },
        options: r.opts,
        correctIndex: r.idx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. GEO COMPLETION
  //
  // Design: A 2×2 grid of cells is shown. Some cells are filled (shaded),
  // some are empty. The grid follows a rule — e.g. diagonal cells are filled,
  // or a specific L-shape pattern. One cell is replaced with "?".
  // The student picks which of 4 options correctly fills the missing cell.
  //
  // The option is a single cell: either filled or empty.
  // Distractors are always the opposite fill state so the answer is binary
  // but the reasoning requires understanding the grid pattern.
  //
  // Grid patterns (which cells are filled, indexed TL=0,TR=1,BL=2,BR=3):
  //   Pattern 0: diagonal  [0,3]        → TL+BR filled
  //   Pattern 1: diagonal  [1,2]        → TR+BL filled
  //   Pattern 2: top row   [0,1]        → TL+TR filled
  //   Pattern 3: bottom row[2,3]        → BL+BR filled
  //   Pattern 4: left col  [0,2]        → TL+BL filled
  //   Pattern 5: right col [1,3]        → TR+BR filled
  //   Pattern 6: L-shape   [0,1,2]      → all except BR
  //   Pattern 7: L-shape   [1,2,3]      → all except TL
  //   Pattern 8: single    [0]          → only TL filled
  //   Pattern 9: single    [3]          → only BR filled
  //
  // Missing cell is always one of the FILLED cells — answer is always "filled".
  // This makes the correct answer non-trivially deducible from the pattern.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _geoCompletion() {
    // filled cell indices for each pattern (0=TL,1=TR,2=BL,3=BR)
    const patterns = [
      [0, 3], // diagonal 1
      [1, 2], // diagonal 2
      [0, 1], // top row
      [2, 3], // bottom row
      [0, 2], // left col
      [1, 3], // right col
      [0, 1, 2], // L top-left
      [1, 2, 3], // L bottom-right
      [0, 1, 3], // L top-right
      [0, 2, 3], // L bottom-left
    ];

    for (int attempt = 0; attempt < 30; attempt++) {
      final patIdx = _r.nextInt(patterns.length);
      final filled = List<int>.from(patterns[patIdx]);
      // Pick which filled cell to hide as "?"
      final hideIdx = _r.nextInt(filled.length);
      final hideCell = filled[hideIdx];
      final sigKey = 'geo2:p$patIdx,h$hideCell';
      if (_seen(sigKey)) continue;

      // Build the 4-cell grid: true=filled, false=empty, null=question mark
      final cells = List<bool?>.generate(4, (i) {
        if (i == hideCell) return null; // the "?" cell
        return filled.contains(i);
      });

      // Correct answer: a filled cell (because the hidden cell was filled)
      // Wrong answers: an empty cell (the cell should NOT be empty)
      // We encode options as {'type':'geo_cell','filled':bool}
      final correct = {'type': 'geo_cell', 'filled': true};
      final wrong1 = {'type': 'geo_cell', 'filled': false};
      // Add two more wrongs that are also empty but with a visual mark
      // to make them look different: use small dot or cross indicator
      final wrong2 = {'type': 'geo_cell', 'filled': false, 'mark': 'dot'};
      final wrong3 = {'type': 'geo_cell', 'filled': false, 'mark': 'cross'};

      final pos = _r.nextInt(4);
      final opts = [wrong1, wrong2, wrong3];
      opts.shuffle(_r);
      opts.insert(pos, correct);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'geo_completion',
        type: 'geo_completion',
        puzzle: {'type': 'geo_completion', 'cells': cells, 'pattern': patIdx},
        options: opts,
        correctIndex: pos,
      );
    }
    // Fallback: top-row pattern, hide TL
    final cells = <bool?>[null, true, false, false];
    final opts = [
      {'type': 'geo_cell', 'filled': true},
      {'type': 'geo_cell', 'filled': false},
      {'type': 'geo_cell', 'filled': false, 'mark': 'dot'},
      {'type': 'geo_cell', 'filled': false, 'mark': 'cross'},
    ]
      ..shuffle(_r);
    final pos = opts.indexWhere((o) => o['filled'] == true);
    return ReasoningQuestion(
      category: 'geo_completion',
      type: 'geo_completion',
      puzzle: {'type': 'geo_completion', 'cells': cells, 'pattern': 2},
      options: opts,
      correctIndex: pos,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. MIRROR SHAPE
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _mirrorShape() {
    for (int attempt = 0; attempt < 20; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final rot = _r.nextInt(4);
      final filled = _r.nextBool();
      final sigKey = 'mirror:s$shape,r$rot,f$filled';
      if (_seen(sigKey)) continue;

      final ans = _f(shape, rot: rot, filled: filled, mirror: true);
      final r = _pack(ans, [
        _f(shape, rot: rot, filled: filled, mirror: false),
        // original (no flip)
        _f(shape, rot: (rot + 1) % 4, filled: filled, mirror: false),
        // rotated, not flipped
        _f(shape, rot: (rot + 2) % 4, filled: filled, mirror: true),
        // flipped + rotated
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_shape',
        type: 'mirror_shape',
        puzzle: {
          'type': 'mirror_shape',
          'target': _f(shape, rot: rot, filled: filled, mirror: false),
        },
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final r = _pack(_f(2, rot: 0, mirror: true),
        [_f(2), _f(2, rot: 1), _f(2, rot: 2, mirror: true)]);
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
    final sub = _r.nextInt(3);
    const letters = [
      'B',
      'C',
      'D',
      'E',
      'F',
      'J',
      'K',
      'L',
      'P',
      'R',
      'S',
      'Z'
    ];
    const digits = ['2', '3', '4', '5', '6', '7'];

    for (int attempt = 0; attempt < 20; attempt++) {
      late Map<String, dynamic> base;
      late String sigKey;
      switch (sub) {
        case 0:
          final ch = letters[_r.nextInt(letters.length)];
          sigKey = 'mirText:$ch';
          base = {'content': ch, 'is_clock': false};
          break;
        case 1:
          final ch = digits[_r.nextInt(digits.length)];
          sigKey = 'mirText:$ch';
          base = {'content': ch, 'is_clock': false};
          break;
        default:
          final h = _r.nextInt(12) + 1;
          final m2 = [0, 15, 30, 45][_r.nextInt(4)];
          sigKey = 'mirText:${h}h${m2}m';
          base = {'is_clock': true, 'clock_hour': h, 'clock_minute': m2};
      }
      if (_seen(sigKey)) continue;

      Map<String, dynamic> mk(bool h, bool v) =>
          {...base, 'type': 'mirror_text', 'mirror_h': h, 'mirror_v': v};

      final combos = [
        mk(false, false),
        mk(true, false),
        mk(false, true),
        mk(true, true)
      ];
      combos.shuffle(_r);
      int correct = combos.indexWhere((c) =>
      c['mirror_h'] == true && c['mirror_v'] == false);
      if (correct < 0) correct = 0;

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
        correctIndex: correct,
      );
    }
    Map<String, dynamic> mk(bool h, bool v) =>
        {
          'content': 'B',
          'is_clock': false,
          'type': 'mirror_text',
          'mirror_h': h,
          'mirror_v': v
        };
    final combos = [
      mk(false, false),
      mk(true, false),
      mk(false, true),
      mk(true, true)
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
        options: combos,
        correctIndex: combos.indexWhere((c) =>
        c['mirror_h'] == true &&
            c['mirror_v'] == false));
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
    final foldAxis = _r.nextInt(2);

    // Pre-defined hole positions always inside the visible (non-folded) quadrant
    // axis=0: hole in left half (x < 0.5), any y
    // axis=1: hole in top half  (y < 0.5), any x
    final positions = foldAxis == 0
        ? [
      {'x': 0.22, 'y': 0.28}, {'x': 0.22, 'y': 0.50}, {'x': 0.22, 'y': 0.72},
      {'x': 0.33, 'y': 0.22}, {'x': 0.33, 'y': 0.50}, {'x': 0.33, 'y': 0.78},
      {'x': 0.25, 'y': 0.40}, {'x': 0.30, 'y': 0.60},
    ]
        : [
      {'x': 0.28, 'y': 0.22}, {'x': 0.50, 'y': 0.22}, {'x': 0.72, 'y': 0.22},
      {'x': 0.22, 'y': 0.33}, {'x': 0.50, 'y': 0.33}, {'x': 0.78, 'y': 0.33},
      {'x': 0.40, 'y': 0.25}, {'x': 0.60, 'y': 0.30},
    ];
    positions.shuffle(_r);

    final hp = positions[0];
    final hx = (hp['x'] as num).toDouble();
    final hy = (hp['y'] as num).toDouble();
    final sigKey = 'punch:ax$foldAxis,x${hx.toStringAsFixed(2)},y${hy
        .toStringAsFixed(2)}';

    // ── Build all 4 option types ────────────────────────────────────────────

    // CORRECT: unfold along actual fold axis
    // axis=0 (vertical): mirror x  → (x,y) + (1-x, y)
    // axis=1 (horizontal): mirror y → (x,y) + (x, 1-y)
    final correctHoles = foldAxis == 0
        ? [{'x': hx, 'y': hy}, {'x': 1.0 - hx, 'y': hy}]
        : [{'x': hx, 'y': hy}, {'x': hx, 'y': 1.0 - hy}];

    // WRONG A: unfold along OPPOSITE axis (classic confusion)
    final wrongA_holes = foldAxis == 0
        ? [{'x': hx, 'y': hy}, {'x': hx, 'y': 1.0 - hy}] // mirror y instead
        : [{'x': hx, 'y': hy}, {'x': 1.0 - hx, 'y': hy}]; // mirror x instead

    // WRONG B: unfold along BOTH axes (as if doubly folded → 4 holes)
    final wrongB_holes = [
      {'x': hx, 'y': hy},
      {'x': 1.0 - hx, 'y': hy},
      {'x': hx, 'y': 1.0 - hy},
      {'x': 1.0 - hx, 'y': 1.0 - hy},
    ];

    // WRONG C: single hole only — student forgot that unfolding mirrors it
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
    // Only use clearly distinct shapes with visible difference at small sizes
    const _embShapes = [1, 2, 3, 7]; // square, triangle, diamond, arrow

    for (int attempt = 0; attempt < 30; attempt++) {
      final targetShape = _embShapes[_r.nextInt(_embShapes.length)];
      final targetFilled = _r.nextBool();
      final sigKey = 'embed2:s$targetShape,f$targetFilled';
      if (_seen(sigKey)) continue;

      final target = _f(targetShape, filled: targetFilled);

      // Companion for the correct option — different shape, different fill
      int companion;
      do {
        companion = _embShapes[_r.nextInt(_embShapes.length)];
      }
      while (companion == targetShape);
      final companionFilled = !targetFilled;
      final offset = _r.nextInt(4) + 1;

      final correct = {
        'type': 'embedded_option',
        'shapes': [target, _f(companion, filled: companionFilled)],
        'offset': offset,
        'contains_target': true,
      };

      // 3 wrong options — pairs that don't include the target shape
      final wrongs = <Map<String, dynamic>>[];
      final usedPairs = <String>{'$targetShape-$companion'};
      int safety = 0;
      while (wrongs.length < 3 && safety < 40) {
        safety++;
        int sA, sB;
        do {
          sA = _embShapes[_r.nextInt(_embShapes.length)];
        }
        while (sA == targetShape);
        do {
          sB = _embShapes[_r.nextInt(_embShapes.length)];
        }
        while (sB == targetShape || sB == sA);
        final pairKey = [sA, sB].toList()
          ..sort();
        final pk = pairKey.join('-');
        if (usedPairs.contains(pk)) continue;
        usedPairs.add(pk);
        final off2 = _r.nextInt(4) + 1;
        final fA = _r.nextBool();
        wrongs.add({
          'type': 'embedded_option',
          'shapes': [_f(sA, filled: fA), _f(sB, filled: !fA)],
          'offset': off2,
          'contains_target': false,
        });
      }

      // If we couldn't get 3 unique pairs, fill remainder
      while (wrongs.length < 3) {
        wrongs.add({
          'type': 'embedded_option',
          'shapes': [_f(3, filled: false), _f(1, filled: true)],
          'offset': 2,
          'contains_target': false,
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
    final target = _f(2, filled: false); // triangle
    final pos = _r.nextInt(4);
    final opts = <Map<String, dynamic>>[
      {
        'type': 'embedded_option',
        'shapes': [_f(3, filled: false), _f(1, filled: true)],
        'offset': 1,
        'contains_target': false
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(1, filled: false), _f(7, filled: true)],
        'offset': 2,
        'contains_target': false
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(7, filled: false), _f(3, filled: true)],
        'offset': 3,
        'contains_target': false
      },
    ];
    opts.insert(pos, {
      'type': 'embedded_option',
      'shapes': [target, _f(3, filled: true)],
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