import 'dart:convert';
import 'dart:math';

import 'reasoning_question.dart';

/// QuestionGenerator
/// Single vocabulary: FigurePainter data keys.
/// All 10 question types, deterministic distractors.
///
/// Repeat prevention: tracks (category, variant, key params) as a string
/// signature. After 50 questions the history is cleared automatically.
class QuestionGenerator {
  // Random source. Made non-final so tests can seed the generator for
  // deterministic behavior.
  static Random _r = Random();
  static const bool _jnvstHardMode = true;

  /// When enabled generator will print a structured JSON line for any
  /// generated question whose options contain visually-duplicate keys.
  /// This is intended for device-side diagnostic logging and is false by
  /// default to avoid noisy logs in normal runs.
  static bool debugDuplicateLogging = false;

  // Shapes that look visually different when rotated (asymmetric)
  static const _rotateable = [2, 3, 7]; // triangle, diamond, arrow
  // Shapes that also look different at 90° (skip circle=0 which looks same)
  static const _allNonCircle = [1, 2, 3, 4, 5, 6, 7, 8];
  static const _highlyAsymmetric = [2, 7, 8]; // triangle, arrow, L-shape

  // ── Repeat prevention ─────────────────────────────────────────────────────
  static final Set<String> _history = {};
  static final Set<String> _questionHistory = {};
  static int _totalGenerated = 0;

  static String _sig(String cat, Map<String, dynamic> params) =>
      '$cat:${params.entries.map((e) => '${e.key}=${e.value}').join(',')}';

  /// Call at the start of each new quiz session for fresh variety.
  static void resetSession() {
    _history.clear();
    _questionHistory.clear();
    _totalGenerated = 0;
  }

  /// Seed the internal RNG (useful for deterministic tests).
  /// Note: calling this during a live session will affect randomness.
  static void seed(int s) {
    _r = Random(s);
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

  static void importHistory(Iterable<String> signatures) {
    _history.addAll(signatures);
    if (_history.length > 800) {
      final toRemove = _history.take(_history.length - 600).toList();
      _history.removeAll(toRemove);
    }
  }

  static List<String> exportHistory({int maxItems = 400}) {
    if (_history.length <= maxItems) return _history.toList();
    return _history.skip(_history.length - maxItems).toList();
  }

  static String _canonical(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return '{${entries.map((e) => '${e.key}:${_canonical(e.value)}').join(
          ',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_canonical).join(',')}]';
    }
    return value.toString();
  }

  static String _questionSignature(ReasoningQuestion q) {
    final optionSigs =
    q.options.map((o) => _canonical(Map<String, dynamic>.from(o))).toList()
      ..sort();
    return _canonical({
      'category': q.category,
      'type': q.type,
      'puzzle': q.puzzle,
      // Sort option signatures so mere option-order shuffles are not treated as unique.
      'options': optionSigs,
    });
  }

  static bool _markQuestionIfNew(ReasoningQuestion q) {
    final sig = _questionSignature(q);
    if (_questionHistory.contains(sig)) return false;
    _questionHistory.add(sig);
    if (_questionHistory.length > 1200) {
      final toRemove = _questionHistory.take(500).toList();
      _questionHistory.removeAll(toRemove);
    }
    return true;
  }

  /// Weighted picker used to bias generation toward harder JNVST-like variants.
  static int _pickWeighted(List<int> weightedValues) {
    return weightedValues[_r.nextInt(weightedValues.length)];
  }

  static ReasoningQuestion generate(String category) {
    for (int attempt = 0; attempt < 80; attempt++) {
      final q = _generateRaw(category);
      // Diagnostic logging: detect visual-duplicate options and emit a
      // structured JSON blob so device logs (adb/flutter logs) can be
      // searched for duplicate events.
      if (debugDuplicateLogging) {
        try {
          final keys = q.options.map((o) =>
              _visibleKey(Map<String, dynamic>.from(o))).toList();
          if (keys
              .toSet()
              .length < 4) {
            final dupCounts = <String, int>{};
            for (final k in keys)
              dupCounts[k] = (dupCounts[k] ?? 0) + 1;
            final dupKeys = dupCounts.entries.where((e) => e.value > 1).map((
                e) => e.key).toList();
            final out = {
              'event': 'duplicate_options_detected',
              'category': category,
              'type': q.type,
              'correctIndex': q.correctIndex,
              'keys': keys,
              'duplicate_keys': dupKeys,
              'options': q.options,
              'seed_snapshot': _r.nextInt(1 << 30),
              // lightweight entropy snapshot
            };
            // Print with a stable prefix so logs can be grepped easily.
            print('DUPLICATE_DETECTED: ${JsonEncoder.withIndent('').convert(
                out)}');
          }
        } catch (e, st) {
          // Don't let logging break generation in production; print minimal info.
          print('DUPLICATE_LOG_ERROR: $e $st');
        }
      }
      if (_markQuestionIfNew(q)) return q;
    }
    // Safety valve: if a category is fully exhausted in a long session, return
    // the latest generated instance instead of stalling generation.
    final fallback = _generateRaw(category);
    _markQuestionIfNew(fallback);
    return fallback;
  }

  static ReasoningQuestion _generateRaw(String category) {
    switch (category) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'pattern':
        {
          final pv = _jnvstHardMode
              ? _pickWeighted([3, 2, 3, 1, 3, 2, 0])
              : _r.nextInt(3);
          if (pv == 0) return _matrixShapeCycle();
          if (pv == 1) return _matrixDotRotation();
          if (pv == 2) return _matrixInnerShape();
          return _matrixDualRule();
        }
      case 'figure_series':
        return (_jnvstHardMode
            ? [
                _seriesRotFill,
                _seriesDotsRot,
                _seriesMorph,
                _seriesAltDual,
                _seriesInner,
                _seriesDots,
                _seriesRotation,
                _seriesAltDual,
              ]
            : [
                _seriesRotation,
                _seriesDots,
                _seriesFillToggle,
                _seriesRotFill,
                _seriesInner,
                _seriesDotsRot,
                _seriesMorph,
              ])[_jnvstHardMode ? _r.nextInt(8) : _r.nextInt(7)]();
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
  static Map<String, dynamic> _f(
    int shape, {
    bool filled = false,
    int rot = 0,
    bool mirror = false,
    int dots = 0,
    int inner = 0,
    int lines = 0,
    int missingCorner = 0,
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
      final holes =
          (m['holes'] as List)
              .map(
                (h) =>
                    '(${(h["x"] as num).toStringAsFixed(2)},${(h["y"] as num).toStringAsFixed(2)})',
              )
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
    // -- Geo jigsaw piece options
    if (m['type'] == 'geo_piece') {
      return 'geopiece|s:${m["shape"]}|c:${m["cut"]}|p:${m["piece"]}';
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

  /// Visible signature used to reject series questions that only differ in
  /// ways the painter renders poorly (for example, rotating a square).
  static String _visibleKey(Map<String, dynamic> m) {
    final copy = Map<String, dynamic>.from(m);
    final s = copy['shape'] ?? 0;
    if (s == 0 || s == 1 || s == 4) copy['rotation'] = 0;
    if (s == 3 || s == 5) copy['rotation'] = (copy['rotation'] ?? 0) % 2;
    return _key(copy);
  }

  static bool _hasVisibleVariation(List<Map<String, dynamic>> seq) {
    return seq
        .map(_visibleKey)
        .toSet()
        .length > 1;
  }

  /// Insert [correct] at a random position among [wrongs].
  /// Removes any wrong that is visually identical to [correct] first.
  /// Returns options list (always 4) + correct index.
  static ({List<Map<String, dynamic>> opts, int idx}) _pack(
    Map<String, dynamic> correct,
    List<Map<String, dynamic>> wrongs,
  ) {
    // Ensure we always return exactly 4 visually-distinct options.
    // Use _key to detect visual duplicates and generate safe fallbacks when
    // necessary. Also clone maps when returning so callers don't accidentally
    // mutate shared instances.
    final ck = _key(correct);
    final seen = <String>{ck};
    final deduped = <Map<String, dynamic>>[];

    // Add unique wrongs from the provided pool
    for (final w in wrongs) {
      final k = _key(w);
      if (!seen.contains(k)) {
        seen.add(k);
        deduped.add(Map<String, dynamic>.from(w));
      }
    }

    // Helper to produce a type-appropriate fallback option
    Map<String, dynamic> _makeFallback(Map<String, dynamic> sample) {
      final bool isPunchHole = sample.containsKey('holes') ||
          sample['type'] == 'punch_hole';
      final bool isMirrorText =
          sample.containsKey('mirror_h') || sample.containsKey('is_clock') ||
              sample['type'] == 'mirror_text';
      final bool isGeoPiece = sample['type'] == 'geo_piece';

      if (isPunchHole) {
        final hx = 0.18 + _r.nextDouble() * 0.6;
        final hy = 0.18 + _r.nextDouble() * 0.6;
        final ax = sample['fold_axis'] as int? ?? 0;
        final n = _r.nextInt(3) + 1;
        return {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': ax,
          'holes': List.generate(n, (i) =>
          {
            'x': (hx + i * 0.12).clamp(0.05, 0.95),
            'y': (hy + i * 0.08).clamp(0.05, 0.95)
          }),
        };
      }
      if (isMirrorText) {
        return {
          'type': 'mirror_text',
          'content': sample['content'] ?? sample['clock_hour']?.toString() ??
              'A',
          'is_clock': sample['is_clock'] ?? false,
          'clock_hour': sample['clock_hour'],
          'clock_minute': sample['clock_minute'],
          'mirror_h': _r.nextBool(),
          'mirror_v': _r.nextBool(),
        };
      }
      if (isGeoPiece) {
        final sh = sample['shape'] as int? ?? 0;
        final maxCut = sh == 0 ? 8 : 4;
        return {
          'type': 'geo_piece',
          'shape': sh,
          'cut': _r.nextInt(maxCut),
          'piece': _r.nextInt(2),
        };
      }

      // Generic shape fallback
      return _f(
        _allNonCircle[_r.nextInt(_allNonCircle.length)],
        rot: _r.nextInt(4),
        filled: _r.nextBool(),
      );
    }

    // Fill up to 3 wrongs with unique fallbacks if needed
    int safety = 0;
    while (deduped.length < 3 && safety < 80) {
      safety++;
      final fallback = _makeFallback(correct);
      final fk = _key(fallback);
      if (!seen.contains(fk)) {
        seen.add(fk);
        deduped.add(fallback);
      }
    }

    // If deduped somehow exceeded 3 (shouldn't normally), trim to 3
    if (deduped.length > 3) deduped.removeRange(3, deduped.length);

    // Insert correct at a random position among the 4 slots
    final pos = _r.nextInt(4);
    final finalList = List<Map<String, dynamic>>.from(deduped);
    finalList.insert(pos, Map<String, dynamic>.from(correct));

    // As a last-ditch safeguard ensure all 4 options are visually distinct;
    // if any duplicates remain, replace them deterministically with generated
    // fallbacks until uniqueness is achieved or attempts exhausted.
    safety = 0;
    while (finalList
        .map(_key)
        .toSet()
        .length < 4 && safety < 40) {
      safety++;
      for (int i = 0; i < finalList.length && finalList
          .map(_key)
          .toSet()
          .length < 4; i++) {
        final k = _key(finalList[i]);
        // if this key collides with another, replace it
        if (finalList
            .map(_key)
            .where((x) => x == k)
            .length > 1) {
          final replacement = _makeFallback(correct);
          final rk = _key(replacement);
          if (!finalList.map(_key).contains(rk)) finalList[i] = replacement;
        }
      }
    }

    return (opts: finalList, idx: pos);
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
            opts = List.generate(
              4,
              (i) => _f(s, rot: rot, filled: i == cp ? !maj : maj),
            );
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
            opts = List.generate(
              4,
              (i) => _f(i == cp ? odd : base, rot: rot, filled: filled),
            );
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
            opts = List.generate(
              4,
              (i) => _f(s, rot: rot, dots: i == cp ? oddD : majD),
            );
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
            opts = List.generate(
              4,
              (i) => _f(s, rot: i == cp ? oddRot : majRot, filled: filled),
            );
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
            opts = List.generate(
              4,
              (i) =>
                  _f(s, rot: rot, filled: filled, inner: i == cp ? innerS : 0),
            );
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
            opts = List.generate(
              4,
              (i) => _f(
                outer,
                rot: rot,
                filled: false,
                inner: i == cp ? oddInner : majInner,
              ),
            );
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
            opts = List.generate(
              4,
              (i) =>
                  _f(s, rot: rot, filled: filled, dots: i == cp ? oddD : majD),
            );
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
            opts = List.generate(
              4,
              (i) => _f(outer, rot: rot, filled: i == cp, inner: inner),
            );
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
        _lookalike[s] ?? ((s % 4) + 1),
        rot: rot,
        filled: filled,
        dots: dots,
      );

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

      final sigKey =
          'matSC:set$setIdx,br$baseRot,st${step > 0 ? 1 : 0},m$missing';
      if (_seen(sigKey)) continue;

      // Build full 3×3
      Map<String, dynamic> cell(int row, int col) => _f(
        shapes[row],
        rot: ((baseRot + col * step) % 4 + 4) % 4,
        filled: row == 1,
      );

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) cells.add(cell(r, c));

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

      final sigKey =
          'matDot:s$shape,f$filled,sv$subV,sd$startD,sr$startR,m$missing';
      if (_seen(sigKey)) continue;

      Map<String, dynamic> cell(int row, int col) {
        final d = (startD + col).clamp(0, 3);
        final rot = subV == 1 ? (startR + col) % 4 : startR;
        return _f(shape, rot: rot, filled: filled, dots: d);
      }

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) cells.add(cell(r, c));

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
      for (int c = 0; c < 3; c++) cells.add(_f(shape, rot: c % 4, dots: c));
    final ans = _f(shape, rot: 2, dots: 2);
    final res = _pack(ans, [
      _f(shape, rot: 1, dots: 2),
      _f(shape, rot: 2, filled: true, dots: 2),
      _f(shape, rot: 2, dots: 1),
    ]);
    final display = List<Map<String, dynamic>>.from(cells)
      ..[8] = {'empty': true};
    return ReasoningQuestion(
      category: 'pattern',
      type: 'matrix_dot_rotation',
      puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // ── 3c. PATTERN — inner shape progression ────────────────────────────────
  // Each row: same outer shape, fixed fill. Inner shape advances per column.
  // Col 0: inner=shape_A, col 1: inner=shape_B, col 2: inner=shape_C
  // Row rule: outer shape changes per row (same as shape cycle but with inners).
  static ReasoningQuestion _matrixInnerShape() {
    const outerShapes = [
      1,
      3,
      5,
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
      Map<String, dynamic> cell(int row, int col) => _f(
        outerShapes[row % outerShapes.length],
        filled: false,
        inner: inners[col],
      );

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) cells.add(cell(r, c));

      final ans = cell(mRow, mCol);
      final ansOuter = outerShapes[mRow % outerShapes.length];
      final ansInner = inners[mCol];

      final res = _pack(ans, [
        _f(ansOuter, filled: false, inner: inners[(mCol + 1) % 3]),
        // wrong inner
        _f(ansOuter, filled: true, inner: ansInner),
        // wrong fill
        _f(
          outerShapes[(mRow + 1) % outerShapes.length],
          filled: false,
          inner: ansInner,
        ),
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

  // ── 3d. PATTERN — dual-rule matrix (row shape + col rotation + checker fill)
  static ReasoningQuestion _matrixDualRule() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final setIdx = _r.nextInt(_matShapeSets.length);
      final shapes = _matShapeSets[setIdx];
      final baseRot = _r.nextInt(4);
      final startDots = _r.nextInt(2); // 0/1 so values stay in visible range
      final missing = _r.nextInt(8) + 1;
      final mRow = missing ~/ 3;
      final mCol = missing % 3;

      final sigKey = 'matDual:set$setIdx,br$baseRot,sd$startDots,m$missing';
      if (_seen(sigKey)) continue;

      Map<String, dynamic> cell(int row, int col) => _f(
        shapes[row],
        rot: (baseRot + col) % 4,
        filled: (row + col).isOdd,
        dots: (startDots + row + col).clamp(0, 4),
      );

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          cells.add(cell(r, c));
        }
      }

      final ans = cell(mRow, mCol);
      final ansShape = ans['shape'] as int;
      final ansRot = ans['rotation'] as int;
      final ansFill = ans['filled'] as bool;
      final ansDots = ans['dots'] as int;

      final res = _pack(ans, [
        _f(ansShape, rot: (ansRot + 1) % 4, filled: ansFill, dots: ansDots),
        _f(ansShape, rot: ansRot, filled: !ansFill, dots: ansDots),
        _f(
          shapes[(mRow + 1) % 3],
          rot: ansRot,
          filled: ansFill,
          dots: (ansDots - 1).clamp(0, 4),
        ),
      ]);

      final display = List<Map<String, dynamic>>.from(cells)
        ..[missing] = {'empty': true};
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'pattern',
        type: 'matrix_dual_rule',
        puzzle: {'type': 'matrix', 'cells': display, 'missing': missing},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    return _matrixDotRotation();
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
    5,
  ]; // triangle, diamond, arrow, L, pentagon

  static ReasoningQuestion _seriesRotation() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 7, 8][_r.nextInt(4)];
      final filled = _r.nextBool();
      final start = _r.nextInt(4);
      final dots = _r.nextInt(3); // 0,1,2 — adds variety to same shape+rot
      final sigKey = 'serRot2:s$shape,f$filled,st$start,d$dots';
      if (_seen(sigKey)) continue;

      // Also cycle inner shape if subV==1 — adds compound change
      final subV2 = _r.nextInt(2); // 0=rot+dots only, 1=rot+dots+inner cycles
      final innerCy = subV2 == 1 ? (_r.nextInt(3) + 1) : 0; // 1-3 or none

      final seq = List.generate(
        3,
        (i) => _f(
          shape,
          rot: (start + i) % 4,
          filled: filled,
          dots: dots,
          inner: subV2 == 1 ? ((innerCy + i - 1) % 3 + 1) : 0,
        ),
      );
      if (!_hasVisibleVariation(seq)) continue;
      final ansInner = subV2 == 1 ? ((innerCy + 3 - 1) % 3 + 1) : 0;
      final ans = _f(
        shape,
        rot: (start + 3) % 4,
        filled: filled,
        dots: dots,
        inner: ansInner,
      );

      final r = _pack(ans, [
        _f(
          shape,
          rot: (start + 3) % 4,
          filled: !filled,
          dots: dots,
          inner: ansInner,
        ), // wrong fill
        _f(
          shape,
          rot: (start + 2) % 4,
          filled: filled,
          dots: dots,
          inner: ansInner,
        ), // one step back
        _f(
          shape,
          rot: (start + 3) % 4,
          filled: filled,
          dots: (dots + 1).clamp(0, 2),
          inner: ansInner,
        ), // wrong dots
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
    final r = _pack(_f(2, rot: 3), [
      _f(2, rot: 3, filled: true),
      _f(2, rot: 2),
      _f(2, rot: 1),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_rotation',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4b. SERIES — dot addition (0→1→2→3)
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesDots() {
    // sub=0: ascending  (start → start+1 → start+2 → ?)  answer = start+3
    // sub=1: descending (start → start-1 → start-2 → ?)  answer = start-3
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 5, 7, 8][_r.nextInt(5)];
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

      final seq = List.generate(
        3,
        (i) => _f(shape, dots: (start + step * i).clamp(0, 4), filled: filled),
      );
      if (!_hasVisibleVariation(seq)) continue;
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
    final r = _pack(_f(1, dots: 3), [
      _f(1, dots: 2),
      _f(1, dots: 3, filled: true),
      _f(1, dots: 4),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_dots',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4c. SERIES — fill toggles each step, rotation advances each step
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesFillToggle() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 5, 7, 8][_r.nextInt(5)];
      final startFill = _r.nextBool();
      final startRot = _r.nextInt(4);
      final dots = _r.nextInt(3);
      final sigKey = 'serFill2:s$shape,sf$startFill,sr$startRot,d$dots';
      if (_seen(sigKey)) continue;

      bool fill(int i) => i.isEven ? startFill : !startFill;

      final seq = List.generate(
        3,
        (i) => _f(shape, rot: (startRot + i) % 4, filled: fill(i), dots: dots),
      );
      if (!_hasVisibleVariation(seq)) continue;
      final ans = _f(
        shape,
        rot: (startRot + 3) % 4,
        filled: fill(3),
        dots: dots,
      );

      final r = _pack(ans, [
        _f(shape, rot: (startRot + 3) % 4, filled: !fill(3), dots: dots),
        // wrong fill
        _f(shape, rot: (startRot + 2) % 4, filled: fill(2), dots: dots),
        // seq[2] rotation
        _f(
          shape,
          rot: (startRot + 3) % 4,
          filled: fill(3),
          dots: (dots + 1).clamp(0, 2),
        ),
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
      _f(2, rot: 1, filled: fill(3)),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_fill_toggle',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
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
      final seq = List.generate(
        3,
        (i) => _f(shapes[i], rot: (startRot + i) % 4, filled: fill(i)),
      );
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
    final r = _pack(_f(6, rot: 3), [
      _f(6, rot: 3, filled: true),
      _f(5, rot: 3),
      _f(6, rot: 2),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_morph',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ── 4d. SERIES — rotation + fill toggle simultaneously ──────────────────
  // Each step: shape rotates +90° AND fill flips. Two rules at once.
  // Harder than seriesRotation or seriesFillToggle individually.
  static ReasoningQuestion _seriesRotFill() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 7, 8][_r.nextInt(4)];
      final startR = _r.nextInt(4);
      final startF = _r.nextBool();
      final dots = _r.nextInt(3);
      final sigKey = 'serRF:s$shape,sr$startR,sf$startF,d$dots';
      if (_seen(sigKey)) continue;

      final seq = List.generate(
        3,
        (i) => _f(
          shape,
          rot: (startR + i) % 4,
          filled: i.isEven ? startF : !startF,
          dots: dots,
        ),
      );
      if (!_hasVisibleVariation(seq)) continue;
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
      _f(2, rot: 0, filled: false),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_rot_fill',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ── 4e. SERIES — inner shape changes each step ────────────────────────────
  // Outer shape stays fixed. Inner shape cycles through 3 different shapes.
  // Tests whether student notices inner-shape changes (common in real exam).
  static ReasoningQuestion _seriesInner() {
    const outers = [
      3,
      5,
      7,
      8,
    ]; // clearer containers for the inner progression
    const innerSeqs = [
      [2, 7, 8, 3], // triangle -> arrow -> L -> diamond
      [7, 2, 5, 8], // arrow -> triangle -> pentagon -> L
      [8, 3, 2, 7], // L -> diamond -> triangle -> arrow
      [5, 8, 7, 2], // pentagon -> L -> arrow -> triangle
    ];
    for (int attempt = 0; attempt < 30; attempt++) {
      final outer = outers[_r.nextInt(outers.length)];
      final seq = innerSeqs[_r.nextInt(innerSeqs.length)];
      final filled = _r.nextBool();
      final sigKey = 'serInner:o$outer,s${seq.join('-')},f$filled';
      if (_seen(sigKey)) continue;

      final figures = List.generate(
        3,
            (i) => _f(outer, filled: filled, inner: seq[i]),
      );
      if (!_hasVisibleVariation(figures)) continue;
      final ansInner = seq[3];
      final ans = _f(outer, filled: filled, inner: ansInner);

      // Distractors: one uses a shape already in sequence, one uses different outer
      final r = _pack(ans, [
        _f(outer, filled: filled, inner: seq[0]), // repeats first inner
        _f(outer, filled: filled, inner: seq[2]), // previous inner
        _f(outer, filled: !filled, inner: ansInner), // right inner, wrong fill
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
    final figs = [_f(1, inner: 1), _f(1, inner: 2), _f(1, inner: 3)];
    final r = _pack(_f(1, inner: 4), [
      _f(1, inner: 1),
      _f(1, inner: 2),
      _f(1, filled: true, inner: 4),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_inner',
      puzzle: {'type': 'series', 'sequence': figs},
      options: r.opts,
      correctIndex: r.idx,
    );
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

      final seq = List.generate(
        3,
        (i) => _f(
          shape,
          rot: (startR + i) % 4,
          dots: (startD + i).clamp(0, 4),
          filled: filled,
        ),
      );
      if (!_hasVisibleVariation(seq)) continue;
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
      _f(2, rot: 3, dots: 2),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'series_dots_rot',
      puzzle: {'type': 'series', 'sequence': seq},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ── 4g. SERIES — alternating dual transformation (JNVST hard style)
  // Step pattern alternates: +rotation, then +dots+fill, and repeats.
  static ReasoningQuestion _seriesAltDual() {
    const shapes = [2, 3, 7, 8];
    for (int attempt = 0; attempt < 40; attempt++) {
      final shape = shapes[_r.nextInt(shapes.length)];
      final startRot = _r.nextInt(4);
      final startDots = _r.nextInt(2); // 0/1 so answer remains <=4
      final startFill = _r.nextBool();
      final sigKey = 'serAltDual:s$shape,r$startRot,d$startDots,f$startFill';
      if (_seen(sigKey)) continue;

      Map<String, dynamic> step(Map<String, dynamic> prev, int s) {
        final rot = prev['rotation'] as int;
        final dots = prev['dots'] as int;
        final fill = prev['filled'] as bool;
        if (s.isOdd) {
          return _f(shape, rot: (rot + 1) % 4, dots: dots, filled: fill);
        }
        return _f(shape, rot: rot, dots: (dots + 1).clamp(0, 4), filled: !fill);
      }

      final s0 = _f(shape, rot: startRot, dots: startDots, filled: startFill);
      final s1 = step(s0, 1);
      final s2 = step(s1, 2);
      final s3 = step(s2, 3);
      final ans = step(s3, 4);

      final seq = [s0, s1, s2, s3];
      if (!_hasVisibleVariation(seq)) continue;
      final ansRot = ans['rotation'] as int;
      final ansDots = ans['dots'] as int;
      final ansFill = ans['filled'] as bool;

      final r = _pack(ans, [
        _f(shape, rot: ansRot, dots: ansDots, filled: !ansFill),
        _f(shape, rot: (ansRot + 1) % 4, dots: ansDots, filled: ansFill),
        _f(
          shape,
          rot: ansRot,
          dots: (ansDots - 1).clamp(0, 4),
          filled: ansFill,
        ),
      ]);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_alt_dual',
        puzzle: {'type': 'series', 'sequence': seq},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    return _seriesRotFill();
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
      final rule = _jnvstHardMode
          ? _pickWeighted([8, 9, 4, 6, 2, 8, 0, 1])
          : _r.nextInt(8); // 0-7

      // Pick two distinct asymmetric shapes for A/B pair and C/D pair
      final sh1 = _allAsym[_r.nextInt(_allAsym.length)];
      int sh2;
      do {
        sh2 = _allAsym[_r.nextInt(_allAsym.length)];
      } while (sh2 == sh1);

      final fillA = _r.nextBool();
      final rotA = _r.nextInt(4);
      final dotsA = (rule == 2 || rule == 6 || rule == 8) ? _r.nextInt(3) : 0;
      final innA = (rule == 4 || rule == 9) ? (_r.nextInt(3) + 1) : 0;

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
        case 8:
          rotB = (rotA + 1) % 4;
          fillB = !fillA;
          dotsB = (dotsA + 1).clamp(0, 4);
          innB = 0;
          break;
        case 9:
          rotB = (rotA + 2) % 4;
          fillB = fillA;
          dotsB = dotsA;
          innB = (innA % 3) + 1;
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
      final dotsC = (rule == 2 || rule == 6 || rule == 8) ? _r.nextInt(3) : 0;
      final innC = (rule == 4 || rule == 9) ? (_r.nextInt(3) + 1) : 0;

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
        case 7:
          rotD = (rotC + 2) % 4;
          fillD = fillC;
          dotsD = dotsC;
          innD = innC;
          break;
        case 8:
          rotD = (rotC + 1) % 4;
          fillD = !fillC;
          dotsD = (dotsC + 1).clamp(0, 4);
          innD = 0;
          break;
        case 9:
          rotD = (rotC + 2) % 4;
          fillD = fillC;
          dotsD = dotsC;
          innD = (innC % 3) + 1;
          break;
        default: // rule 4 fallback
          rotD = (rotC + 1) % 4;
          fillD = !fillC;
          dotsD = 0;
          innD = innB;
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
        _f(
          sh2D,
          rot: rotD,
          filled: fillD,
          dots: (dotsD - 1).clamp(0, 3),
          inner: innD,
        ),
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
          'C': _f(sh2, rot: rotC, filled: fillC, dots: dotsC, inner: innC),
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
      _f(3, rot: 3, filled: true),
    ]);
    return ReasoningQuestion(
      category: 'analogy',
      type: 'analogy_r0',
      puzzle: {
        'type': 'analogy',
        'A': _f(2, rot: 0),
        'B': _f(2, rot: 1, filled: true),
        'C': _f(3, rot: 0),
      },
      options: res.opts,
      correctIndex: res.idx,
    );
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
  static int _geoMaxCut(int shape) => shape == 0 ? 8 : 4;

  static Map<String, dynamic> _geoPiece(int shape, int cut, int piece) => {
    'type': 'geo_piece',
    'shape': shape,
    'cut': cut,
    'piece': piece,
  };

  static List<int> _geoNeighborCuts(int cut, int maxCut) {
    final out = <int>[];
    for (final d in [1, -1, 2, -2, 3, -3]) {
      final c = ((cut + d) % maxCut + maxCut) % maxCut;
      if (c != cut && !out.contains(c)) out.add(c);
    }
    for (int c = 0; c < maxCut; c++) {
      if (c != cut && !out.contains(c)) out.add(c);
    }
    return out;
  }

  static ReasoningQuestion _geoCompletion() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final shape = _jnvstHardMode
          ? [0, 0, 0, 0, 1, 2][_r.nextInt(6)]
          : _r.nextInt(3);
      final maxCut = _geoMaxCut(shape);
      final cut = (shape == 0 && _jnvstHardMode)
          ? [4, 5, 6, 7, 4, 5, 6, 7, 2, 3, 0, 1][_r.nextInt(12)]
          : _r.nextInt(maxCut);
      final shownPiece = _r.nextInt(2);
      final targetPiece = 1 - shownPiece;
      final template = _jnvstHardMode
          ? [0, 1, 0, 2, 1, 3, 0][_r.nextInt(7)]
          : _r.nextInt(4);
      final sigKey = 'geo6:sh$shape,c$cut,sp$shownPiece,t$template';
      if (_seen(sigKey)) continue;

      final qPiece = _geoPiece(shape, cut, shownPiece);
      final correct = _geoPiece(shape, cut, targetPiece);
      final correctKey = _key(correct);
      final wrongs = <Map<String, dynamic>>[];
      final seenWrongs = <String>{};
      final nearCuts = _geoNeighborCuts(cut, maxCut);

      void addWrong(int s, int c, int p) {
        // Avoid showing the exact same piece as the puzzle prompt as an option.
        if (s == shape && c == cut && p == shownPiece) return;
        final w = _geoPiece(s, c, p);
        final wk = _key(w);
        if (wk == correctKey) return;
        if (seenWrongs.add(wk)) wrongs.add(w);
      }

      switch (template) {
        case 0:
          // Hardest: same shape + same side as correct, only cut differs.
          for (final nc in nearCuts) {
            addWrong(shape, nc, targetPiece);
            if (wrongs.length == 3) break;
          }
          break;
        case 1:
          // Two near cuts + one same-cut wrong-side trap.
          for (int i = 0; i < nearCuts.length && wrongs.length < 2; i++) {
            addWrong(shape, nearCuts[i], targetPiece);
          }
          addWrong(shape, cut, shownPiece);
          break;
        case 2:
          // Near cuts with mixed side polarity.
          for (int i = 0; i < nearCuts.length && wrongs.length < 3; i++) {
            addWrong(shape, nearCuts[i], i.isEven ? targetPiece : shownPiece);
          }
          break;
        default:
          // Broader mix: same-cut trap + near-cuts + one shape-transfer trap.
          addWrong(shape, cut, shownPiece);
          for (int i = 0; i < nearCuts.length && wrongs.length < 2; i++) {
            addWrong(shape, nearCuts[i], targetPiece);
          }
          for (int s = 0; s < 3 && wrongs.length < 3; s++) {
            if (s == shape) continue;
            addWrong(s, _r.nextInt(_geoMaxCut(s)), _r.nextInt(2));
          }
      }

      // Fill remaining slots without becoming trivial.
      for (final nc in nearCuts) {
        if (wrongs.length >= 3) break;
        addWrong(shape, nc, shownPiece);
      }
      for (int c = 0; c < maxCut && wrongs.length < 3; c++) {
        if (c == cut) continue;
        addWrong(shape, c, targetPiece);
      }
      for (int s = 0; s < 3 && wrongs.length < 3; s++) {
        if (s == shape) continue;
        addWrong(s, _r.nextInt(_geoMaxCut(s)), _r.nextInt(2));
      }

      final res = _pack(correct, wrongs.take(3).toList());
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'geo_completion',
        type: 'geo_jigsaw',
        puzzle: {'type': 'geo_completion', 'piece': qPiece},
        options: res.opts,
        correctIndex: res.idx,
      );
    }
    final q = {'type': 'geo_piece', 'shape': 0, 'cut': 6, 'piece': 1};
    final a = {'type': 'geo_piece', 'shape': 0, 'cut': 6, 'piece': 0};
    final res = _pack(a, [
      {'type': 'geo_piece', 'shape': 0, 'cut': 5, 'piece': 0},
      {'type': 'geo_piece', 'shape': 0, 'cut': 6, 'piece': 1},
      {'type': 'geo_piece', 'shape': 0, 'cut': 7, 'piece': 0},
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
    8,
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
      final dots = _r.nextInt(3);
      final sigKey = 'mirror6:s$shape,r$rot,f$filled,d$dots';
      if (_seen(sigKey)) continue;

      final target = _f(
        shape,
        rot: rot,
        filled: filled,
        dots: dots,
        mirror: false,
      ); // shown in puzzle
      final ans = _f(
        shape,
        rot: rot,
        filled: filled,
        dots: dots,
        mirror: true,
      ); // CORRECT: mirror of target
      final wrongPool = <Map<String, dynamic>>[
        _f(shape, rot: rot, filled: filled, dots: dots, mirror: false),
        _f(shape, rot: (rot + 1) % 4, filled: filled, dots: dots, mirror: true),
        _f(
          shape,
          rot: (rot + 2) % 4,
          filled: filled,
          dots: dots,
          mirror: false,
        ),
        _f(shape, rot: rot, filled: !filled, dots: dots, mirror: false),
        _f(
          shape,
          rot: (rot + 3) % 4,
          filled: !filled,
          dots: dots,
          mirror: true,
        ),
        _f(
          shape,
          rot: rot,
          filled: filled,
          dots: (dots + 1) % 3,
          mirror: false,
        ),
        _f(
          shape,
          rot: (rot + 1) % 4,
          filled: !filled,
          dots: (dots + 2) % 3,
          mirror: true,
        ),
      ]..shuffle(_r);

      final r = _pack(ans, wrongPool.take(3).toList());
      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_shape',
        type: 'mirror_shape',
        puzzle: {'type': 'mirror_shape', 'target': target},
        options: r.opts,
        correctIndex: r.idx,
      );
    }
    final r = _pack(_f(2, rot: 0, mirror: true), [
      _f(2, rot: 0, mirror: false),
      _f(2, rot: 1, mirror: true),
      _f(2, rot: 2, mirror: false),
    ]);
    return ReasoningQuestion(
      category: 'mirror_shape',
      type: 'mirror_shape',
      puzzle: {'type': 'mirror_shape', 'target': _f(2)},
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. MIRROR TEXT
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _mirrorText() {
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
      'Z',
    ];
    // Words and short strings from actual Navodaya exam papers
    const words = [
      'FAN',
      'RUN',
      'UNR',
      'NKU',
      'CLASS',
      'KOON',
      'VERBAL',
      'STROKE',
      'BUZZER',
      'FORTIFY',
      'VINAY',
      'MALA',
      'LITY',
      'NIAL',
      'GARH',
      'VIR',
      'STU',
      'DIAN',
      'HEN',
      'FIX',
      'KR',
      'AB',
      'NAME',
      'RICE',
      'BIRD',
      'LEAF',
      'FACE',
      'GOLD',
    ];
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
      '3867',
    ];
    const digits = ['2', '3', '4', '5', '6', '7'];

    for (int attempt = 0; attempt < 20; attempt++) {
      final sub = _r.nextInt(
        4,
      ); // 0=single letter, 1=word, 2=number string, 3=clock
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

      late List<Map<String, dynamic>> combos;
      late int correctIdx;

      if (base['is_clock'] == true) {
        // Clock: same time in all options; only mirror orientation changes.
        final h = base['clock_hour'] as int;
        final m2 = base['clock_minute'] as int;
        final mk = (int dh, int dm, bool mir) => {
          ...base,
          'type': 'mirror_text',
          'clock_hour': ((h + dh - 1) % 12) + 1,
          'clock_minute': (m2 + dm) % 60,
          'mirror_h': mir,
          'mirror_v': false,
        };
        final correct = mk(0, 0, true); // correct mirror
        final wrongs = [
          mk(0, 0, false),
          {...mk(0, 0, false), 'mirror_v': true},
          {...mk(0, 0, true), 'mirror_v': true},
        ];
        wrongs.shuffle(_r);
        final packed = _pack(correct, wrongs.take(3).toList());
        combos = packed.opts;
        correctIdx = packed.idx;
      } else {
        // Text/number: same content in all options; vary only mirror flags.

        final correct = {
          ...base,
          'type': 'mirror_text',
          'mirror_h': true,
          'mirror_v': false,
        };
        final wrongs = <Map<String, dynamic>>[
          {
            ...base,
            'type': 'mirror_text',
            'mirror_h': false,
            'mirror_v': false,
          },
          {...base, 'type': 'mirror_text', 'mirror_h': false, 'mirror_v': true},
          {...base, 'type': 'mirror_text', 'mirror_h': true, 'mirror_v': true},
        ];
        wrongs.shuffle(_r);
        final packed = _pack(correct, wrongs.take(3).toList());
        combos = packed.opts;
        correctIdx = packed.idx;
      }

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_text',
        type: 'mirror_text_$sub',
        puzzle: {
          ...base,
          'type': 'mirror_text',
          'mirror_h': false,
          'mirror_v': false,
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
        'mirror_v': false,
      },
      {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': false,
      },
      {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': true,
      },
      {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': true,
        'mirror_v': true,
      },
    ]..shuffle(_r);
    return ReasoningQuestion(
      category: 'mirror_text',
      type: 'mirror_text_0',
      puzzle: {
        'content': 'B',
        'is_clock': false,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': false,
      },
      options: fb,
      correctIndex: fb.indexWhere(
        (c) => c['content'] == 'B' && c['mirror_h'] == true,
      ),
    );
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
            {'x': 0.22, 'y': 0.22},
            {'x': 0.22, 'y': 0.38},
            {'x': 0.35, 'y': 0.22},
            {'x': 0.35, 'y': 0.35},
            {'x': 0.28, 'y': 0.28},
            {'x': 0.42, 'y': 0.30},
            {'x': 0.30, 'y': 0.42},
            {'x': 0.40, 'y': 0.40},
          ]
        : foldType == 0
        ? [
            {'x': 0.18, 'y': 0.25},
            {'x': 0.18, 'y': 0.50},
            {'x': 0.18, 'y': 0.75},
            {'x': 0.28, 'y': 0.20},
            {'x': 0.28, 'y': 0.50},
            {'x': 0.28, 'y': 0.80},
            {'x': 0.35, 'y': 0.35},
            {'x': 0.35, 'y': 0.65},
            {'x': 0.22, 'y': 0.38},
            {'x': 0.22, 'y': 0.62},
            {'x': 0.30, 'y': 0.28},
            {'x': 0.30, 'y': 0.72},
          ]
        : [
            {'x': 0.25, 'y': 0.18},
            {'x': 0.50, 'y': 0.18},
            {'x': 0.75, 'y': 0.18},
            {'x': 0.20, 'y': 0.28},
            {'x': 0.50, 'y': 0.28},
            {'x': 0.80, 'y': 0.28},
            {'x': 0.35, 'y': 0.35},
            {'x': 0.65, 'y': 0.35},
            {'x': 0.38, 'y': 0.22},
            {'x': 0.62, 'y': 0.22},
            {'x': 0.28, 'y': 0.30},
            {'x': 0.72, 'y': 0.30},
          ];
    positions.shuffle(_r);

    final hp = positions[0];
    final hx = (hp['x'] as num).toDouble();
    final hy = (hp['y'] as num).toDouble();
    final sigKey =
        'punch:ft$foldType,x${hx.toStringAsFixed(2)},y${hy.toStringAsFixed(2)}';

    // ── Build all 4 option types ────────────────────────────────────────────

    // CORRECT: unfold along actual fold axis/axes
    final correctHoles = foldType == 2
        ? [
            // double fold → 4 holes (mirror both axes)
            {'x': hx, 'y': hy},
            {'x': 1.0 - hx, 'y': hy},
            {'x': hx, 'y': 1.0 - hy},
            {'x': 1.0 - hx, 'y': 1.0 - hy},
          ]
        : foldType == 0
        ? [
            {'x': hx, 'y': hy},
            {'x': 1.0 - hx, 'y': hy},
          ]
        : [
            {'x': hx, 'y': hy},
            {'x': hx, 'y': 1.0 - hy},
          ];

    // ── Distractors with VARIED positions so they don't look the same ────────
    // Pick a nearby alternative hole position (different from the actual hole)
    // for use in structural distractors — avoids all 4 options looking like
    // "same paper, just different dot positions"
    final altPositions =
        List<Map<String, num>>.from(positions)
            .where(
              (p) => (p['x']! - hx).abs() > 0.05 || (p['y']! - hy).abs() > 0.05,
            )
            .toList()
          ..shuffle(_r);
    final altHx = altPositions.isNotEmpty
        ? (altPositions[0]['x'] as num).toDouble()
        : (hx + 0.1).clamp(0.15, 0.45);
    final altHy = altPositions.isNotEmpty
        ? (altPositions[0]['y'] as num).toDouble()
        : (hy + 0.1).clamp(0.15, 0.85);

    // WRONG A: opposite axis / only vertical mirror for double fold
    final wrongA_holes = foldType == 2
        ? [
            {'x': hx, 'y': hy},
            {'x': 1.0 - hx, 'y': hy},
          ] // only mirrored x (forgot y)
        : foldType == 0
        ? [
            {'x': hx, 'y': hy},
            {'x': hx, 'y': 1.0 - hy},
          ]
        : [
            {'x': hx, 'y': hy},
            {'x': 1.0 - hx, 'y': hy},
          ];

    // WRONG B: correct axis but different position
    final wrongB_holes = foldType == 2
        ? [
            {'x': altHx, 'y': altHy},
            {'x': 1.0 - altHx, 'y': altHy},
            {'x': altHx, 'y': 1.0 - altHy},
            {'x': 1.0 - altHx, 'y': 1.0 - altHy},
          ]
        : foldType == 0
        ? [
            {'x': altHx, 'y': altHy},
            {'x': 1.0 - altHx, 'y': altHy},
          ]
        : [
            {'x': altHx, 'y': altHy},
            {'x': altHx, 'y': 1.0 - altHy},
          ];

    // WRONG C: single hole only (forgot unfolding multiplies holes)
    final wrongC_holes = [
      {'x': hx, 'y': hy},
    ];

    Map<String, dynamic> _opt(List<Map<String, dynamic>> holes) => {
      'type': 'punch_hole',
      'unfolded': true,
      'fold_axis': foldAxis,
      'holes': holes,
    };

    final correct = _opt(correctHoles);
    final wrongs = [_opt(wrongA_holes), _opt(wrongB_holes), _opt(wrongC_holes)];

    final r = _pack(correct, wrongs);
    _markSeen(sigKey);
    return ReasoningQuestion(
      category: 'punch_hole',
      type: 'punch_hole',
      puzzle: {
        'type': 'punch_hole',
        'folded': true,
        'fold_axis': foldAxis,
        'holes': [
          {'x': hx, 'y': hy},
        ],
      },
      options: r.opts,
      correctIndex: r.idx,
    );
  }

  static List<Map<String, dynamic>> _unfold(Map<String, double> h, int axis) {
    final x = h['x']!;
    final y = h['y']!;
    if (axis == 0)
      return [
        {'x': x, 'y': y},
        {'x': 1.0 - x, 'y': y},
      ];
    return [
      {'x': x, 'y': y},
      {'x': x, 'y': 1.0 - y},
    ];
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
      final sigKey =
          'embed3:s$targetShape,f$targetFilled,r$targetRot,tp$targetPos';
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
            } while (used.contains(s));
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
        final key = triple.map((t) => t['shape']).toList()..sort();
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
    final target = _f(2, filled: false, rot: 0);
    final pos = _r.nextInt(4);
    final opts = <Map<String, dynamic>>[
      {
        'type': 'embedded_option',
        'shapes': [_f(3), _f(1, filled: true), _f(8)],
        'offset': 1,
        'contains_target': false,
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(1), _f(7, filled: true), _f(3)],
        'offset': 2,
        'contains_target': false,
      },
      {
        'type': 'embedded_option',
        'shapes': [_f(7), _f(3, filled: true), _f(1)],
        'offset': 3,
        'contains_target': false,
      },
    ];
    opts.insert(pos, {
      'type': 'embedded_option',
      'shapes': [target, _f(3, filled: true), _f(8)],
      'offset': 2,
      'contains_target': true,
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
