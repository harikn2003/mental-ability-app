import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

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

  /// Call at the start of each new quiz session for fresh variety.
  static void resetSession() {
    _history.clear();
    _questionHistory.clear();
  }

  /// Seed the internal random source with a deterministic value.
  /// Used specifically in visual unit tests to ensure repeatable coverage.
  static void seed(int s) {
    _r = Random(s);
  }

  static bool _seen(String sig) => _history.contains(sig);
  static void _markSeen(String sig) {
    _history.add(sig);
    if (_history.length > 200) {
      _history.clear();
    }
  }

  static void importHistory(Iterable<String> signatures) {
    _questionHistory.addAll(signatures);
    if (_questionHistory.length > 500) {
      _questionHistory.clear();
    }
  }

  static List<String> exportHistory({int maxItems = 400}) {
    return _questionHistory.take(maxItems).toList();
  }

  static String _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final parts = keys.map((k) => '$k:${_canonical(value[k])}');
      return '{${parts.join(',')}}';
    }
    if (value is List) {
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
    if (_questionHistory.contains(sig)) {
      return false;
    }
    _questionHistory.add(sig);
    if (_questionHistory.length > 400) {
      _questionHistory.clear();
    }
    return true;
  }

  static int _pickWeighted(List<int> weightedValues) {
    return weightedValues[_r.nextInt(weightedValues.length)];
  }

  static ReasoningQuestion generate(String category, {bool isHardMode = false}) {
    for (int attempt = 0; attempt < 80; attempt++) {
      final q = _generateRaw(category, isHardMode: isHardMode);
      // Diagnostic logging: detect visual-duplicate options and emit a
      // structured JSON blob so device logs (adb/flutter logs) can be
      // searched for duplicate events.
      if (debugDuplicateLogging) {
        try {
          final keys = q.options
              .map((o) => _visibleKey(Map<String, dynamic>.from(o)))
              .toList();
          if (keys.toSet().length < 4) {
            final dupCounts = <String, int>{};
            for (final k in keys) {
              dupCounts[k] = (dupCounts[k] ?? 0) + 1;
            }
            final dupKeys = dupCounts.entries
                .where((e) => e.value > 1)
                .map((e) => e.key)
                .toList();
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
            debugPrint(
              'DUPLICATE_DETECTED: ${JsonEncoder.withIndent('').convert(out)}',
            );
          }
        } catch (e, st) {
          // Don't let logging break generation in production; print minimal info.
          debugPrint('DUPLICATE_LOG_ERROR: $e $st');
        }
      }
      if (_markQuestionIfNew(q)) return q;
    }
    // Safety valve: if a category is fully exhausted in a long session, return
    // the latest generated instance instead of stalling generation.
    final fallback = _generateRaw(category, isHardMode: isHardMode);
    _markQuestionIfNew(fallback);
    return fallback;
  }

  static ReasoningQuestion _generateRaw(String category,
      {bool isHardMode = false}) {
    switch (category) {
      case 'odd_man':
        return _oddMan(isHardMode: isHardMode);
      case 'figure_match':
        return _figureMatch();
      case 'pattern':
        {
          final pv = isHardMode
              ? _pickWeighted([3, 2, 3, 1, 3, 2, 0])
              : _r.nextInt(3);
          if (pv == 0) return _matrixShapeCycle();
          if (pv == 1) return _matrixDotRotation();
          if (pv == 2) return _matrixInnerShape();
          return _matrixDualRule();
        }
      case 'figure_series':
        return (isHardMode
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
              ])[isHardMode ? _r.nextInt(8) : _r.nextInt(7)]();
      case 'analogy':
        return _analogy(isHardMode: isHardMode);
      case 'geo_completion':
        return _geoCompletion(isHardMode: isHardMode);
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
    bool dense = false,
    bool selectiveMirrorTrap = false,
  }) => {
    'shape': shape,
    'filled': filled,
    'rotation': rot,
    'mirror': mirror,
    'dots': dots,
    'inner': inner,
    'lines': lines,
    'missingCorner': missingCorner,
    if (dense) 'dense': true,
    if (selectiveMirrorTrap) 'selective_mirror_trap': true,
  };

  /// Compact string key for a shape map — used to detect duplicate options.
  static String _key(Map<String, dynamic> m) {
    return _visibleKey(m);
  }

  /// Visible signature used to reject series questions that only differ in
  /// ways the painter renders poorly (for example, rotating a square).
  static String _visibleKey(Map<String, dynamic> m) {
    // ── Punch hole options ─────────────────────────────────────────────────
    if (m.containsKey('holes') && m.containsKey('unfolded')) {
      final holes = (m['holes'] as List)
          .map((h) =>
              '(${(h["x"] as num).toStringAsFixed(2)},${(h["y"] as num).toStringAsFixed(2)})')
          .toList()
        ..sort();
      return 'punch|ax:${m["fold_axis"]}|holes:${holes.join("-")}';
    }
    // ── Mirror text / clock options ────────────────────────────────────────
    if (m.containsKey('mirror_h') || m.containsKey('is_clock')) {
      final ch = m['content'] ?? 'clk:${m["clock_hour"]}:${m["clock_minute"]}';
      return 'txt|$ch|h:${m["mirror_h"]}|v:${m["mirror_v"]}';
    }
    // ── Geo cell options ───────────────────────────────────────────────────
    if (m['type'] == 'geo_cell') {
      return 'geocell|f:${m["filled"]}|mk:${m["mark"] ?? "none"}';
    }
    // ── Geo piece options ──────────────────────────────────────────────────
    if (m['type'] == 'geo_piece') {
      return 'geopiece|s:${m["shape"]}|c:${m["cut"]}|p:${m["piece"]}';
    }
    // ── Embedded options ───────────────────────────────────────────────────
    if (m['type'] == 'embedded_option') {
      final shapes = (m['shapes'] as List)
          .map((s) => '${s["shape"]}-${s["filled"]}-${s["rotation"] ?? 0}')
          .join('+');
      return 'emb|$shapes|off:${m["offset"]}';
    }

    // ── Generic Shape options ──────────────────────────────────────────────
    final int s = m['shape'] ?? 0;
    int rot = m['rotation'] ?? 0;
    bool mir = m['mirror'] ?? false;
    final bool trap = (m['selective_mirror_trap'] ?? false) && ((m['lines'] ?? 0) > 0 || (m['inner'] ?? 0) > 0);

    // Apply visual symmetry reductions to canonicalize visually identical states
    if (s == 0 || s == 1 || s == 4 || s == 6) {
      rot = 0;
      mir = false;
    } else if (s == 3 || s == 5) {
      rot = rot % 2;
      mir = false;
    } else if (s == 2 && mir) {
      // Shape 2: Right-angle triangle. (mirror=true, rot) is visually identical to (mirror=false, 3-rot)
      mir = false;
      rot = 3 - rot;
    } else if (s == 7 && mir) {
      // Shape 7: Arrow. (mirror=true, rot) points LEFT/RIGHT/UP/DOWN identically to unmirrored counterparts:
      // (true, 0) -> (false, 2) [points LEFT]
      // (true, 1) -> (false, 1) [points DOWN]
      // (true, 2) -> (false, 0) [points RIGHT]
      // (true, 3) -> (false, 3) [points UP]
      mir = false;
      if (rot == 0) {
        rot = 2;
      } else if (rot == 2) {
        rot = 0;
      }
    }

    return '$s,${m["filled"]},$rot,$mir,${m["dots"]},${m["inner"]},${m["lines"]},${m["missingCorner"]},$trap';
  }

  static bool _hasVisibleVariation(List<Map<String, dynamic>> seq) {
    return seq.map(_visibleKey).toSet().length > 1;
  }

  /// Mutates a candidate distractor to resolve fingerprint collisions.
  static Map<String, dynamic> _mutate(Map<String, dynamic> orig, Map<String, dynamic> sample) {
    final m = Map<String, dynamic>.from(orig);

    // Geo cell mutation
    if (m['type'] == 'geo_cell') {
      if (_r.nextBool()) {
        m['filled'] = !(m['filled'] as bool? ?? false);
      } else {
        const marks = ['none', 'dot', 'cross'];
        final currentMark = m['mark'] ?? 'none';
        m['mark'] = marks.firstWhere((x) => x != currentMark, orElse: () => 'none');
      }
      return m;
    }

    // Geo piece mutation
    if (m['type'] == 'geo_piece') {
      final sh = m['shape'] as int? ?? 0;
      final maxCut = sh == 0 ? 8 : 4;
      m['cut'] = ((m['cut'] as int? ?? 0) + 1) % maxCut;
      if (_r.nextBool()) {
        m['piece'] = ((m['piece'] as int? ?? 0) + 1) % 2;
      }
      return m;
    }

    // Embedded option mutation
    if (m['type'] == 'embedded_option') {
      final shapes = List<Map<String, dynamic>>.from(
        (m['shapes'] as List).map((s) => Map<String, dynamic>.from(s as Map))
      );
      if (shapes.isNotEmpty) {
        final idx = _r.nextInt(shapes.length);
        final s = shapes[idx];
        s['rotation'] = ((s['rotation'] as int? ?? 0) + 1) % 4;
        if (_r.nextBool()) {
          s['shape'] = _allNonCircle[_r.nextInt(_allNonCircle.length)];
        }
      }
      m['shapes'] = shapes;
      return m;
    }

    // Punch hole mutation
    if (m.containsKey('holes') && m.containsKey('unfolded')) {
      final holes = List<Map<String, dynamic>>.from(
        (m['holes'] as List).map((h) => Map<String, dynamic>.from(h as Map))
      );
      if (holes.isNotEmpty) {
        final idx = _r.nextInt(holes.length);
        final h = holes[idx];
        if (_r.nextBool()) {
          h['x'] = ((h['x'] as double) + (_r.nextBool() ? 0.1 : -0.1)).clamp(0.05, 0.95);
        } else {
          h['y'] = ((h['y'] as double) + (_r.nextBool() ? 0.1 : -0.1)).clamp(0.05, 0.95);
        }
      } else {
        holes.add({
          'x': (0.18 + _r.nextDouble() * 0.6).clamp(0.05, 0.95),
          'y': (0.18 + _r.nextDouble() * 0.6).clamp(0.05, 0.95),
        });
      }
      m['holes'] = holes;
      return m;
    }

    // Mirror text / clock mutation
    if (m.containsKey('mirror_h') || m.containsKey('is_clock')) {
      if (m['is_clock'] == true) {
        m['clock_hour'] = ((m['clock_hour'] as int? ?? 3) % 12) + 1;
        final minuteChoices = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
        m['clock_minute'] = minuteChoices[_r.nextInt(minuteChoices.length)];
      } else {
        final content = m['content'] as String? ?? 'A';
        if (content.length > 1) {
          final prefix = content.substring(0, content.length - 1).split('');
          prefix.shuffle(_r);
          m['content'] = prefix.join('') + content[content.length - 1];
        } else {
          m['content'] = String.fromCharCode(65 + _r.nextInt(26));
        }
      }
      return m;
    }

    // Generic shape mutation
    final bool isMirrorShape = sample.containsKey('mirror') && !sample.containsKey('holes');
    if (isMirrorShape) {
      final choice = _r.nextInt(3);
      if (choice == 0) {
        m['rotation'] = ((m['rotation'] as int? ?? 0) + 1) % 4;
      } else if (choice == 1) {
        m['filled'] = !(m['filled'] as bool? ?? false);
      } else {
        m['dots'] = ((m['dots'] as int? ?? 0) + 1) % 3; // Keep dots strictly between 0 and 2
      }
    } else {
      if (_r.nextBool()) {
        m['rotation'] = ((m['rotation'] as int? ?? 0) + 1) % 4;
      } else if (_r.nextBool()) {
        m['filled'] = !(m['filled'] as bool? ?? false);
      } else if (_r.nextBool()) {
        m['dots'] = ((m['dots'] as int? ?? 0) + 1) % 5;
      } else if (_r.nextBool()) {
        m['lines'] = ((m['lines'] as int? ?? 0) + 1) % 4;
      } else {
        m['inner'] = ((m['inner'] as int? ?? 0) + 1) % 9;
      }
    }
    return m;
  }

  /// Insert [correct] at a random position among [wrongs].
  /// Removes any wrong that is visually identical to [correct] first.
  /// Returns options list (always 4) + correct index.
  static ({List<Map<String, dynamic>> opts, int idx}) _pack(
    Map<String, dynamic> correct,
    List<Map<String, dynamic>> wrongs,
  ) {
    final correctIndex = _r.nextInt(4);
    final List<Map<String, dynamic>?> options = List.filled(4, null);

    // Generate and place correct first
    options[correctIndex] = Map<String, dynamic>.from(correct);
    final seenKeys = <String>{ _visibleKey(correct) };

    int wrongIdx = 0;

    // Helper to produce a type-appropriate fallback option
    Map<String, dynamic> makeFallback(Map<String, dynamic> sample) {
      final bool isPunchHole =
          sample.containsKey('holes') || sample['type'] == 'punch_hole';
      final bool isMirrorText =
          sample.containsKey('mirror_h') ||
              sample.containsKey('is_clock') ||
              sample['type'] == 'mirror_text';
      final bool isGeoPiece = sample['type'] == 'geo_piece';
      final bool isGeoCell = sample['type'] == 'geo_cell';
      final bool isEmbedded = sample['type'] == 'embedded_option';

      if (isPunchHole) {
        final hx = 0.18 + _r.nextDouble() * 0.6;
        final hy = 0.18 + _r.nextDouble() * 0.6;
        final ax = sample['fold_axis'] as int? ?? 0;
        final n = _r.nextInt(3) + 1;
        return {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': ax,
          'holes': List.generate(
            n,
            (i) => {
              'x': (hx + i * 0.12).clamp(0.05, 0.95),
              'y': (hy + i * 0.08).clamp(0.05, 0.95),
            },
          ),
        };
      }
      if (isMirrorText) {
        final bool isClock = sample['is_clock'] ?? false;
        if (isClock) {
          final h = _r.nextInt(12) + 1;
          final minuteChoices = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
          final m = minuteChoices[_r.nextInt(minuteChoices.length)];
          return {
            'type': 'mirror_text',
            'is_clock': true,
            'clock_hour': h,
            'clock_minute': m,
            'mirror_h': true,
            'mirror_v': false,
            if (sample.containsKey('dense')) 'dense': sample['dense'],
          };
        } else {
          final content = (sample['content'] ?? 'A').toString();
          if (content.length > 1) {
            final prefix = content.substring(0, content.length - 1).split('');
            prefix.shuffle(_r);
            return {
              'type': 'mirror_text',
              'is_clock': false,
              'content': prefix.join('') + content[content.length - 1],
              'mirror_h': true,
              'mirror_v': false,
              if (sample.containsKey('dense')) 'dense': sample['dense'],
            };
          } else {
            return {
              'type': 'mirror_text',
              'is_clock': false,
              'content': String.fromCharCode(65 + _r.nextInt(26)),
              'mirror_h': true,
              'mirror_v': false,
              if (sample.containsKey('dense')) 'dense': sample['dense'],
            };
          }
        }
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
      if (isGeoCell) {
        return {
          'type': 'geo_cell',
          'filled': _r.nextBool(),
          'mark': ['none', 'dot', 'cross'][_r.nextInt(3)],
        };
      }
      if (isEmbedded) {
        final embShapes = [1, 2, 3, 7, 8];
        final triple = <Map<String, dynamic>>[];
        for (int i = 0; i < 3; i++) {
          triple.add(_f(embShapes[_r.nextInt(embShapes.length)], filled: _r.nextBool(), rot: _r.nextInt(4)));
        }
        return {
          'type': 'embedded_option',
          'shapes': triple,
          'offset': _r.nextInt(4) + 1,
          'contains_target': false,
        };
      }

      // Generic shape fallback
      return _f(
        _allNonCircle[_r.nextInt(_allNonCircle.length)],
        rot: _r.nextInt(4),
        filled: _r.nextBool(),
      );
    }

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) continue;

      Map<String, dynamic> candidate;
      if (wrongIdx < wrongs.length) {
        candidate = Map<String, dynamic>.from(wrongs[wrongIdx]);
        wrongIdx++;
      } else {
        candidate = makeFallback(correct);
      }

      int safety = 0;
      String vk = _visibleKey(candidate);
      while (seenKeys.contains(vk) && safety < 100) {
        safety++;
        candidate = _mutate(candidate, correct);
        vk = _visibleKey(candidate);
      }

      // Fallback fallback if mutations failed
      if (seenKeys.contains(vk)) {
        safety = 0;
        while (seenKeys.contains(vk) && safety < 50) {
          safety++;
          candidate = makeFallback(correct);
          vk = _visibleKey(candidate);
        }
      }

      options[i] = candidate;
      seenKeys.add(vk);
    }

    final finalList = options.cast<Map<String, dynamic>>();
    return (opts: finalList, idx: correctIndex);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. ODD MAN OUT
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _oddMan({bool isHardMode = false}) {
    for (int attempt = 0; attempt < 30; attempt++) {
      final v = isHardMode ? _r.nextInt(12) : _r.nextInt(8);
      final cp = _r.nextInt(4);
      List<Map<String, dynamic>> opts;
      String sigKey;

      switch (v) {
        case 0:
          {
            final s = _r.nextInt(6) + 1;
            final rot = _r.nextInt(4);
            final maj = _r.nextBool();
            sigKey = 'oddA:s$s,r$rot,maj$maj,cp$cp';
            opts = List.generate(
              4,
              (i) => _f(s, rot: rot, filled: i == cp ? !maj : maj),
            );
            break;
          }
        case 1:
          {
            const pairs = [
              [2, 5],
              [3, 6],
              [7, 1],
              [8, 4],
              [2, 3],
              [7, 8],
            ];
            final pair = pairs[_r.nextInt(pairs.length)];
            final base = pair[0];
            final odd = pair[1];
            final rot = _r.nextInt(4);
            final filled = _r.nextBool();
            sigKey = 'oddB:b$base,o$odd,r$rot,f$filled,cp$cp';
            opts = List.generate(
              4,
              (i) => _f(i == cp ? odd : base, rot: rot, filled: filled),
            );
            break;
          }
        case 2:
          {
            final s = _r.nextInt(5) + 1;
            final rot = _r.nextInt(4);
            final majD = 1;
            final oddD = 3;
            sigKey = 'oddC:s$s,r$rot,cp$cp';
            opts = List.generate(
              4,
              (i) => _f(s, rot: rot, dots: i == cp ? oddD : majD),
            );
            break;
          }
        case 3:
          {
            final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
            final filled = _r.nextBool();
            final majRot = _r.nextInt(4);
            final oddRot = (majRot + 1) % 4;
            sigKey = 'oddD:s$s,f$filled,mr$majRot,cp$cp';
            opts = List.generate(
              4,
              (i) => _f(s, rot: i == cp ? oddRot : majRot, filled: filled),
            );
            break;
          }
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
        case 5:
          {
            final outer = _r.nextInt(4) + 1;
            final rot = _r.nextInt(4);
            final majInner = _r.nextInt(4) + 1;
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
        case 6:
          {
            final s = _r.nextInt(6) + 1;
            final rot = _r.nextInt(4);
            final filled = _r.nextBool();
            final majD = _r.nextInt(3);
            final oddD = majD == 0 ? 3 : 0;
            sigKey = 'oddG:s$s,r$rot,f$filled,md$majD,cp$cp';
            opts = List.generate(
              4,
              (i) =>
                  _f(s, rot: rot, filled: filled, dots: i == cp ? oddD : majD),
            );
            break;
          }
        case 7:
          {
            final outer = _r.nextInt(4) + 1;
            final inner = _r.nextInt(3) + 1;
            final rot = _r.nextInt(4);
            sigKey = 'oddH:o$outer,i$inner,r$rot,cp$cp';
            opts = List.generate(
              4,
              (i) => _f(outer, rot: rot, filled: i == cp, inner: inner),
            );
            break;
          }
        case 8: // Variant 8: Rotation vs Mirror Trap (Hard)
          {
            final s = [2, 7, 8][_r.nextInt(3)];
            final baseRot = _r.nextInt(4);
            final filled = _r.nextBool();
            sigKey = 'oddI:s$s,br$baseRot,f$filled,cp$cp';
            opts = List.generate(4, (i) {
              if (i == cp) {
                return _f(s, rot: baseRot, filled: filled, mirror: true);
              } else {
                return _f(s,
                    rot: (baseRot + i) % 4, filled: filled, mirror: false);
              }
            });
            break;
          }
        case 9: // Variant 9: Side count vs Dot count (Hard)
          {
            final shapes = [1, 2, 5, 6];
            final sideCounts = {1: 4, 2: 3, 5: 5, 6: 6};
            final baseShapes = List<int>.from(shapes)..shuffle(_r);
            sigKey = 'oddJ:bs${baseShapes.join()},cp$cp';
            opts = List.generate(4, (i) {
              final s = baseShapes[i];
              int d = sideCounts[s]!;
              if (i == cp) d = (d == 3) ? 4 : d - 1;
              return _f(s, dots: d);
            });
            break;
          }
        case 10: // Variant 10: Missing Corner (Hard)
          {
            final s = 1; // square
            final majC = _r.nextInt(4) + 1;
            int oddC;
            do {
              oddC = _r.nextInt(4) + 1;
            } while (oddC == majC);
            sigKey = 'oddK:m$majC,o$oddC,cp$cp';
            opts = List.generate(
                4, (i) => _f(s, missingCorner: i == cp ? oddC : majC));
            break;
          }
        default: // Variant 11: Inner shape vs Outer shape sides (Hard)
          {
            final shapes = [1, 2, 3, 5, 6];
            final baseS = shapes[_r.nextInt(shapes.length)];
            int diffS;
            do {
              diffS = shapes[_r.nextInt(shapes.length)];
            } while (diffS == baseS);

            sigKey = 'oddL:bs$baseS,ds$diffS,cp$cp';
            opts = List.generate(4, (i) {
              if (i == cp) {
                return _f(baseS, inner: diffS + 1);
              } else {
                return _f(baseS, inner: baseS + 1);
              }
            });
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
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _figureMatch() {
    const asymShapes = [2, 3, 7, 8];
    const lookalike = {2: 3, 3: 2, 7: 8, 8: 7};

    for (int attempt = 0; attempt < 30; attempt++) {
      final s = asymShapes[_r.nextInt(asymShapes.length)];
      final rot = _r.nextInt(4);
      final filled = _r.nextBool();
      final dots = _r.nextInt(3);

      final rotStep = _r.nextBool() ? 1 : 3;
      final sigKey = 'figMatch:s$s,r$rot,f$filled,d$dots,rs$rotStep';
      if (_seen(sigKey)) continue;

      final target = _f(s, rot: rot, filled: filled, dots: dots);
      final dRot = _f(s, rot: (rot + rotStep) % 4, filled: filled, dots: dots);
      final dFill = _f(s, rot: rot, filled: !filled, dots: dots);
      final dShape = _f(
        lookalike[s] ?? ((s % 4) + 1),
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
  // ═══════════════════════════════════════════════════════════════════════════
  static const _matShapeSets = [
    [1, 2, 3],
    [2, 7, 8],
    [3, 7, 2],
    [1, 8, 3],
    [5, 2, 7],
    [8, 1, 7],
  ];

  static ReasoningQuestion _matrixShapeCycle() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final setIdx = _r.nextInt(_matShapeSets.length);
      final shapes = _matShapeSets[setIdx];
      final baseRot = _r.nextInt(4);
      final step = _r.nextBool() ? 1 : -1;
      final missing = _r.nextInt(8) + 1;
      final misRow = missing ~/ 3;
      final misCol = missing % 3;

      final sigKey =
          'matSC:set$setIdx,br$baseRot,st${step > 0 ? 1 : 0},m$missing';
      if (_seen(sigKey)) continue;

      Map<String, dynamic> cell(int row, int col) => _f(
        shapes[row],
        rot: ((baseRot + col * step) % 4 + 4) % 4,
        filled: row == 1,
      );

      final cells = <Map<String, dynamic>>[];
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) {
          cells.add(cell(r, c));
        }

      final ans = cell(misRow, misCol);
      final ansShape = shapes[misRow];
      final ansRot = ans['rotation'] as int;
      final ansFill = ans['filled'] as bool;

      final res = _pack(ans, [
        _f(ansShape, rot: (ansRot + 1) % 4, filled: ansFill),
        _f(ansShape, rot: ansRot, filled: !ansFill),
        _f(shapes[(misRow + 1) % 3], rot: ansRot, filled: ansFill),
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
  // 3b. PATTERN — dot & rotation
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _matrixDotRotation() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = _rotateable[_r.nextInt(_rotateable.length)];
      final filled = _r.nextBool();
      final subV = _r.nextInt(2);
      final startD = _r.nextInt(2);
      final startR = _r.nextInt(4);
      final missing = _r.nextInt(6) + 3;
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
        for (int c = 0; c < 3; c++) {
          cells.add(cell(r, c));
        }

      final ans = cell(misRow, misCol);
      final ansRot = ans['rotation'] as int;
      final ansD = ans['dots'] as int;

      final res = _pack(ans, [
        _f(shape, rot: (ansRot + 1) % 4, filled: filled, dots: ansD),
        _f(shape, rot: ansRot, filled: !filled, dots: ansD),
        _f(shape, rot: ansRot, filled: filled, dots: (ansD - 1).clamp(0, 3)),
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
      for (int c = 0; c < 3; c++) {
        cells.add(_f(shape, rot: c % 4, dots: c));
      }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 3c. PATTERN — inner shape progression
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _matrixInnerShape() {
    const outerShapes = [1, 3, 5];
    const innerSeqs = [
      [2, 7, 8],
      [1, 2, 3],
      [4, 2, 7],
      [3, 8, 2],
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
        for (int c = 0; c < 3; c++) {
          cells.add(cell(r, c));
        }

      final ans = cell(mRow, mCol);
      final ansOuter = outerShapes[mRow % outerShapes.length];
      final ansInner = inners[mCol];

      final res = _pack(ans, [
        _f(ansOuter, filled: false, inner: inners[(mCol + 1) % 3]),
        _f(ansOuter, filled: true, inner: ansInner),
        _f(
          outerShapes[(mRow + 1) % outerShapes.length],
          filled: false,
          inner: ansInner,
        ),
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
  // 3d. PATTERN — dual-rule matrix
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _matrixDualRule() {
    for (int attempt = 0; attempt < 40; attempt++) {
      final setIdx = _r.nextInt(_matShapeSets.length);
      final shapes = _matShapeSets[setIdx];
      final baseRot = _r.nextInt(4);
      final startDots = _r.nextInt(2);
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
  static ReasoningQuestion _seriesRotation() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 7, 8][_r.nextInt(4)];
      final filled = _r.nextBool();
      final start = _r.nextInt(4);
      final dots = _r.nextInt(3);
      final sigKey = 'serRot2:s$shape,f$filled,st$start,d$dots';
      if (_seen(sigKey)) continue;

      final subV2 = _r.nextInt(2);
      final innerCy = subV2 == 1 ? (_r.nextInt(3) + 1) : 0;

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
        ),
        _f(
          shape,
          rot: (start + 2) % 4,
          filled: filled,
          dots: dots,
          inner: ansInner,
        ),
        _f(
          shape,
          rot: (start + 3) % 4,
          filled: filled,
          dots: (dots + 1).clamp(0, 2),
          inner: ansInner,
        ),
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
  // 4b. SERIES — dot addition
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesDots() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = [2, 3, 5, 7, 8][_r.nextInt(5)];
      final filled = _r.nextBool();
      final sub = _r.nextBool() ? 0 : 1;
      final start = sub == 0
          ? _r.nextInt(2)
          : _r.nextInt(2) + 3;
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

      final r = _pack(ans, [
        _f(shape, dots: d1, filled: filled),
        _f(shape, dots: d2, filled: filled),
        _f(shape, dots: ansD, filled: !filled),
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
  // 4c. SERIES — fill toggles each step
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
        _f(shape, rot: (startRot + 2) % 4, filled: fill(2), dots: dots),
        _f(
          shape,
          rot: (startRot + 3) % 4,
          filled: fill(3),
          dots: (dots + 1).clamp(0, 2),
        ),
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
  // 4d. SERIES — shape morphs
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _seriesMorph() {
    const morphSeqs = [
      [2, 1, 5, 6],
      [1, 5, 6, 2],
      [5, 6, 2, 1],
      [6, 2, 1, 5],
    ];

    for (int attempt = 0; attempt < 30; attempt++) {
      final seqIdx = _r.nextInt(morphSeqs.length);
      final shapes = morphSeqs[seqIdx];
      final startRot = _r.nextInt(4);
      final startFill = _r.nextBool();
      final sigKey = 'serMorph:sq$seqIdx,sr$startRot,sf$startFill';
      if (_seen(sigKey)) continue;

      bool fill(int i) => i.isEven ? startFill : !startFill;
      final seq = List.generate(
        3,
        (i) => _f(shapes[i], rot: (startRot + i) % 4, filled: fill(i)),
      );
      final ans = _f(shapes[3], rot: (startRot + 3) % 4, filled: fill(3));

      final r = _pack(ans, [
        _f(shapes[3], rot: (startRot + 3) % 4, filled: !fill(3)),
        _f(shapes[2], rot: (startRot + 3) % 4, filled: fill(3)),
        _f(shapes[3], rot: (startRot + 2) % 4, filled: fill(3)),
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
      final ansF = 3.isEven ? startF : !startF;
      final ans = _f(shape, rot: ansR, filled: ansF, dots: dots);

      final r = _pack(ans, [
        _f(shape, rot: ansR, filled: !ansF, dots: dots),
        _f(shape, rot: (ansR + 1) % 4, filled: ansF, dots: dots),
        _f(shape, rot: (ansR + 1) % 4, filled: !ansF, dots: dots),
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
  static ReasoningQuestion _seriesInner() {
    const outers = [3, 5, 7, 8];
    const innerSeqs = [
      [2, 7, 8, 3],
      [7, 2, 5, 8],
      [8, 3, 2, 7],
      [5, 8, 7, 2],
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

      final r = _pack(ans, [
        _f(outer, filled: filled, inner: seq[0]),
        _f(outer, filled: filled, inner: seq[2]),
        _f(outer, filled: !filled, inner: ansInner),
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
  static ReasoningQuestion _seriesDotsRot() {
    const shapes = [2, 3, 7, 8];
    for (int attempt = 0; attempt < 30; attempt++) {
      final shape = shapes[_r.nextInt(shapes.length)];
      final filled = _r.nextBool();
      final startD = _r.nextInt(2);
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
        _f(shape, rot: (ansR + 1) % 4, dots: ansD, filled: filled),
        _f(shape, rot: ansR, dots: (ansD - 1).clamp(0, 4), filled: filled),
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

  // ── 4g. SERIES — alternating dual transformation
  static ReasoningQuestion _seriesAltDual() {
    const shapes = [2, 3, 7, 8];
    for (int attempt = 0; attempt < 40; attempt++) {
      final shape = shapes[_r.nextInt(shapes.length)];
      final startRot = _r.nextInt(4);
      final startDots = _r.nextInt(2);
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
  // 5. ANALOGY
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _analogy({bool isHardMode = false}) {
    const allAsym = [2, 3, 7, 8];

    for (int attempt = 0; attempt < 40; attempt++) {
      final rule = isHardMode
          ? _pickWeighted([8, 9, 4, 6, 2, 8, 0, 1])
          : _r.nextInt(8);

      final sh1 = allAsym[_r.nextInt(allAsym.length)];
      int sh2;
      do {
        sh2 = allAsym[_r.nextInt(allAsym.length)];
      } while (sh2 == sh1);

      final fillA = _r.nextBool();
      final rotA = _r.nextInt(4);
      final dotsA = (rule == 2 || rule == 6 || rule == 8) ? _r.nextInt(3) : 0;
      final innA = (rule == 4 || rule == 9) ? (_r.nextInt(3) + 1) : 0;

      int rotB = 0;
      bool fillB = false;
      int dotsB = 0;
      int innB = 0;
      int sh1B = sh1;
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
        default:
          rotB = (rotA + 1) % 4;
          fillB = !fillA;
          dotsB = 0;
          innB = _r.nextInt(3) + 1;
          break;
      }

      final rotC = _r.nextInt(4);
      final fillC = _r.nextBool();
      final dotsC = (rule == 2 || rule == 6 || rule == 8) ? _r.nextInt(3) : 0;
      final innC = (rule == 4 || rule == 9) ? (_r.nextInt(3) + 1) : 0;

      int rotD = 0;
      bool fillD = false;
      int dotsD = 0;
      int innD = 0;
      int sh2D = sh2;
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
        default:
          rotD = (rotC + 1) % 4;
          fillD = !fillC;
          dotsD = 0;
          innD = innB;
          break;
      }

      final sigKey = 'analogy2:s1$sh1,s2$sh2,rA$rotA,rC$rotC,rule$rule';
      if (_seen(sigKey)) continue;

      final ans = _f(sh2D, rot: rotD, filled: fillD, dots: dotsD, inner: innD);

      final res = _pack(ans, [
        _f(sh2D, rot: (rotD + 1) % 4, filled: fillD, dots: dotsD, inner: innD),
        _f(sh2D, rot: rotD, filled: !fillD, dots: dotsD, inner: innD),
        _f(
          sh2D,
          rot: rotD,
          filled: fillD,
          dots: (dotsD - 1).clamp(0, 3),
          inner: innD,
        ),
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
  // 6. GEO COMPLETION
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

  static ReasoningQuestion _geoCompletion({bool isHardMode = false}) {
    for (int attempt = 0; attempt < 40; attempt++) {
      final shape = isHardMode
          ? [0, 0, 0, 0, 1, 2][_r.nextInt(6)]
          : _r.nextInt(3);
      final maxCut = _geoMaxCut(shape);
      final cut = (shape == 0 && isHardMode)
          ? [4, 5, 6, 7, 4, 5, 6, 7, 2, 3, 0, 1][_r.nextInt(12)]
          : _r.nextInt(maxCut);
      final shownPiece = _r.nextInt(2);
      final targetPiece = 1 - shownPiece;
      final template = isHardMode
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
        if (s == shape && c == cut && p == shownPiece) return;
        final w = _geoPiece(s, c, p);
        final wk = _key(w);
        if (wk == correctKey) return;
        if (seenWrongs.add(wk)) wrongs.add(w);
      }

      switch (template) {
        case 0:
          for (final nc in nearCuts) {
            addWrong(shape, nc, targetPiece);
            if (wrongs.length == 3) break;
          }
          break;
        case 1:
          for (int i = 0; i < nearCuts.length && wrongs.length < 2; i++) {
            addWrong(shape, nearCuts[i], targetPiece);
          }
          addWrong(shape, cut, shownPiece);
          break;
        case 2:
          for (int i = 0; i < nearCuts.length && wrongs.length < 3; i++) {
            addWrong(shape, nearCuts[i], i.isEven ? targetPiece : shownPiece);
          }
          break;
        default:
          addWrong(shape, cut, shownPiece);
          for (int i = 0; i < nearCuts.length && wrongs.length < 2; i++) {
            addWrong(shape, nearCuts[i], targetPiece);
          }
          for (int s = 0; s < 3 && wrongs.length < 3; s++) {
            if (s == shape) continue;
            addWrong(s, _r.nextInt(_geoMaxCut(s)), _r.nextInt(2));
          }
      }

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
  static const _mirrorShapes = [2, 7, 8];

  static ReasoningQuestion _mirrorShape() {
    for (int attempt = 0; attempt < 60; attempt++) {
      final shape = _mirrorShapes[_r.nextInt(_mirrorShapes.length)];
      final rot = _r.nextInt(4);
      final filled = _r.nextBool();
      final int dots = _r.nextInt(3); // 0, 1, or 2 dots

      final sigKey = 'mirror6:s$shape,r$rot,f$filled,d$dots';
      if (_seen(sigKey)) continue;

      final target = _f(
        shape,
        rot: rot,
        filled: filled,
        dots: dots,
        mirror: false,
      );

      final ans = _f(
        shape,
        rot: rot,
        filled: filled,
        dots: dots,
        mirror: true,
      );

      // Create wrong pool containing pure spatial transformations of the target shape:
      // - w1: Same rot/fill/dots, but mirror = false (original unmirrored target)
      // - w2: Same rot/fill/dots, but mirror = true and rotation offset by 90 degrees
      // - w3: Same rot/fill/dots, but mirror = true and rotation offset by 180 degrees
      // - w4: Same rot/fill/dots, but mirror = true and rotation offset by 270 degrees
      // - w5: Same rot/fill/dots, but mirror = false and rotation offset by 180 degrees
      final wrongPool = <Map<String, dynamic>>[
        _f(shape, rot: rot, filled: filled, dots: dots, mirror: false),
        _f(shape, rot: (rot + 1) % 4, filled: filled, dots: dots, mirror: true),
        _f(shape, rot: (rot + 2) % 4, filled: filled, dots: dots, mirror: true),
        _f(shape, rot: (rot + 3) % 4, filled: filled, dots: dots, mirror: true),
        _f(shape, rot: (rot + 2) % 4, filled: filled, dots: dots, mirror: false),
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

  static ReasoningQuestion _mirrorText() {
    String pickBaseContent(bool isDigit) {
      if (isDigit) {
        // Generate a random 4-digit number with unique digits
        final List<int> digits = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_r);
        if (digits[0] == 0) {
          final temp = digits[0];
          digits[0] = digits[1];
          digits[1] = temp;
        }
        return digits.take(4).join('');
      } else {
        // Generate a random 4-letter word with unique uppercase letters
        const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        final List<String> chars = letters.split('')..shuffle(_r);
        return chars.take(4).join('');
      }
    }

    String permuteStringNotEndingWithLast(String src) {
      if (src.length <= 1) return src;
      final last = src.substring(src.length - 1);
      final List<String> chars = src.split('');
      for (int i = 0; i < 40; i++) {
        chars.shuffle(_r);
        if (chars.last != last) {
          final res = chars.join('');
          if (res != src) return res;
        }
      }
      return src;
    }

    String permutePrefix(String src) {
      if (src.length <= 2) return src;
      final last = src.substring(src.length - 1);
      final prefix = src.substring(0, src.length - 1);
      final List<String> chars = prefix.split('');
      for (int i = 0; i < 20; i++) {
        chars.shuffle(_r);
        final res = chars.join('');
        if (res != prefix) return res + last;
      }
      return src;
    }

    Map<String, dynamic> buildOption(
      String strategy,
      String sourceContent, {
      required bool isDigit,
      int? trapIndex,
      int? swapPos,
    }) {
      bool mirrorH = true;
      bool mirrorV = false;
      bool selectiveMirrorTrap = false;
      int trapCharIndex = -1;
      String contentToRender = sourceContent;

      switch (strategy) {
        case 'correct':
          mirrorH = true;
          selectiveMirrorTrap = false;
          contentToRender = sourceContent;
          break;

        case 'A':
          mirrorH = true;
          selectiveMirrorTrap = true;
          trapCharIndex = -99;
          contentToRender = sourceContent;
          break;

        case 'B':
          mirrorH = true;
          selectiveMirrorTrap = false;
          contentToRender = sourceContent.split('').reversed.join();
          break;

        case 'C':
          mirrorH = true;
          selectiveMirrorTrap = true;
          trapCharIndex = trapIndex ?? 0;
          contentToRender = sourceContent;
          break;

        case 'D':
          mirrorH = true;
          selectiveMirrorTrap = false;
          final pos = swapPos ?? 0;
          final chars = sourceContent.split('');
          if (pos >= 0 && pos < chars.length - 1) {
            final tmp = chars[pos];
            chars[pos] = chars[pos + 1];
            chars[pos + 1] = tmp;
          }
          contentToRender = chars.join();
          break;
      }

      return {
        'type': 'mirror_text',
        'is_clock': false,
        'content': contentToRender,
        'mirror_h': mirrorH,
        'mirror_v': mirrorV,
        'selective_mirror_trap': selectiveMirrorTrap,
        'trap_char_index': trapCharIndex,
        'mirror_strategy': strategy,
        'mirror_source': sourceContent,
        'mirror_is_digit': isDigit,
        // ignore: use_null_aware_elements
        if (trapIndex != null) 'mirror_trap_index': trapIndex,
        // ignore: use_null_aware_elements
        if (swapPos != null) 'mirror_swap_pos': swapPos,
      };
    }

    Map<String, dynamic> mutateCandidate(
      Map<String, dynamic> candidate, {
      required bool isDigit,
      required int mutationAttempt,
    }) {
      final strategy = candidate['mirror_strategy'] as String? ?? 'A';
      var source = (candidate['mirror_source'] as String?) ?? '';

      if (strategy == 'C') {
        final currentTrap = candidate['mirror_trap_index'] as int? ?? 0;
        final maxTrap = source.isEmpty ? 0 : source.length - 1;
        if (mutationAttempt % (maxTrap + 1) == 0 && mutationAttempt > 0) {
          source = permutePrefix(source);
        }
        final nextTrap = (currentTrap + 1) % (source.isEmpty ? 1 : source.length);
        return buildOption(
          'C',
          source,
          isDigit: isDigit,
          trapIndex: nextTrap,
        );
      } else if (strategy == 'D') {
        final currentSwap = candidate['mirror_swap_pos'] as int? ?? 0;
        final maxSwap = source.length - 3; // Keep swap within prefix to preserve last letter
        if (maxSwap <= 0 || (mutationAttempt % (maxSwap + 1) == 0 && mutationAttempt > 0)) {
          source = permutePrefix(source);
        }
        final nextSwap = maxSwap <= 0 ? 0 : (currentSwap + 1) % (maxSwap + 1);
        return buildOption(
          'D',
          source,
          isDigit: isDigit,
          swapPos: nextSwap,
        );
      } else if (strategy == 'A') {
        source = permutePrefix(source);
        return buildOption(strategy, source, isDigit: isDigit);
      } else {
        // Strategy B: always keep last letter not matching original last
        source = permuteStringNotEndingWithLast(source);
        return buildOption(strategy, source, isDigit: isDigit);
      }
    }

    Map<String, dynamic> resolveUniqueCandidate(
      Map<String, dynamic> initial,
      Set<String> seenKeys, {
      required bool isDigit,
    }) {
      var current = Map<String, dynamic>.from(initial);
      for (int i = 0; i < 120; i++) {
        final key = _visibleKey(current);
        if (!seenKeys.contains(key)) return current;
        current = mutateCandidate(current, isDigit: isDigit, mutationAttempt: i);
      }
      return current;
    }

    mirrorTextAttempt:
    for (int attempt = 0; attempt < 80; attempt++) {
      final isDigit = _r.nextBool();
      final content = pickBaseContent(isDigit);
      final sigKey = 'mirTextAdv:$content|${isDigit ? 'digit' : 'word'}';
      if (_seen(sigKey)) continue;

      final correctIndex = _r.nextInt(4);
      final options = List<Map<String, dynamic>?>.filled(4, null);
      final seenKeys = <String>{};

      final correct = buildOption('correct', content, isDigit: isDigit);
      options[correctIndex] = correct;
      seenKeys.add(_visibleKey(correct));

      // Always include Strategy B (ends with first letter)
      // Pick 2 other strategies from A, C, D (ends with last letter)
      final otherStrategies = ['A', 'C', 'D']..shuffle(_r);
      final strategies = ['B', otherStrategies[0], otherStrategies[1]]..shuffle(_r);
      int strategyIdx = 0;

      for (int slot = 0; slot < 4; slot++) {
        if (slot == correctIndex) continue;

        final strategy = strategies[strategyIdx++];
        final candidate = switch (strategy) {
          'A' => buildOption(
              'A',
              permutePrefix(content),
              isDigit: isDigit,
            ),
          'C' => buildOption(
              'C',
              permutePrefix(content),
              isDigit: isDigit,
              trapIndex: 0,
            ),
          'D' => buildOption(
              'D',
              content,
              isDigit: isDigit,
              swapPos: _r.nextInt(content.length - 2),
            ),
          _ => buildOption(strategy, content, isDigit: isDigit),
        };

        final uniqueCandidate = resolveUniqueCandidate(
          candidate,
          seenKeys,
          isDigit: isDigit,
        );
        final uniqueKey = _visibleKey(uniqueCandidate);
        if (seenKeys.contains(uniqueKey)) {
          continue mirrorTextAttempt;
        }
        options[slot] = uniqueCandidate;
        seenKeys.add(uniqueKey);
      }

      if (options.any((o) => o == null)) continue;

      final finalOptions = options.map((o) => o!).toList();
      final correctKey = _visibleKey(correct);
      if (finalOptions.where((o) => _visibleKey(o) == correctKey).length != 1) {
        continue;
      }

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'mirror_text',
        type: isDigit ? 'mirror_text_num' : 'mirror_text_word',
        puzzle: {
          'type': 'mirror_text',
          'is_clock': false,
          'content': content,
          'mirror_h': false,
          'mirror_v': false,
        },
        options: finalOptions,
        correctIndex: correctIndex,
      );
    }

    final fallbackContent = '1086';
    final fallbackCorrect = buildOption('correct', fallbackContent, isDigit: true);
    final fallbackOptions = <Map<String, dynamic>>[
      buildOption('A', fallbackContent, isDigit: true),
      buildOption('B', fallbackContent, isDigit: true),
      buildOption('C', fallbackContent, isDigit: true, trapIndex: 0),
    ];
    final fallbackPacked = _pack(fallbackCorrect, fallbackOptions);

    return ReasoningQuestion(
      category: 'mirror_text',
      type: 'mirror_text_num',
      puzzle: {
        'type': 'mirror_text',
        'is_clock': false,
        'content': fallbackContent,
        'mirror_h': false,
        'mirror_v': false,
      },
      options: fallbackPacked.opts,
      correctIndex: fallbackPacked.idx,
    );
  }
  // 9. PUNCH HOLE
  // ═══════════════════════════════════════════════════════════════════════════
  static String _holesKey(List<Map<String, dynamic>> holes) {
    final parts = holes
        .map((h) =>
            '${(h['x'] as num).toStringAsFixed(4)},${(h['y'] as num).toStringAsFixed(4)}')
        .toSet()
        .toList()
      ..sort();
    return parts.join('-');
  }

  static ReasoningQuestion _punchHole() {
    for (int attempt = 0; attempt < 50; attempt++) {
      final int axis = _r.nextInt(2);
      final double hx = 0.18 + _r.nextDouble() * 0.32;
      final double hy = 0.18 + _r.nextDouble() * 0.32;
      final int variant = _r.nextInt(4);

      final List<Map<String, dynamic>> foldedHoles = [
        {'x': hx, 'y': hy}
      ];

      if (variant == 2 || variant == 3) {
        foldedHoles.add({'x': hx + 0.15, 'y': hy + 0.15});
      }

      final sigKey = 'punch6:ax$axis,hx${hx.toStringAsFixed(2)},v$variant';
      if (_seen(sigKey)) continue;

      List<Map<String, dynamic>> unfold(List<Map<String, dynamic>> fHoles, int ax) {
        final out = <Map<String, dynamic>>[];
        for (final h in fHoles) {
          final x = h['x'] as double;
          final y = h['y'] as double;
          out.add({'x': x, 'y': y});
          if (ax == 0) {
            out.add({'x': 1.0 - x, 'y': y});
          } else {
            out.add({'x': x, 'y': 1.0 - y});
          }
        }
        return out;
      }

      final correctHoles = unfold(foldedHoles, axis);

      final double ox = hx + 0.22;
      final double oy = hy + 0.22;
      final wPosHoles = [
        {'x': ox.clamp(0.08, 0.92), 'y': oy.clamp(0.08, 0.92)}
      ];
      if (variant == 2 || variant == 3) {
        wPosHoles.add({'x': (ox - 0.1).clamp(0.08, 0.92), 'y': (oy - 0.1).clamp(0.08, 0.92)});
      }
      final wrongPos = unfold(wPosHoles, axis);

      final wrongOppAxis = unfold(foldedHoles, 1 - axis);

      final double fx = hx + 0.12;
      final double fy = hy + 0.12;
      final w3Holes = [
        {'x': fx.clamp(0.08, 0.92), 'y': fy.clamp(0.08, 0.92)}
      ];
      if (variant == 2 || variant == 3) {
        w3Holes.add({'x': (fx + 0.05).clamp(0.08, 0.92), 'y': (fy + 0.05).clamp(0.08, 0.92)});
      }
      final wrongMixed = unfold(w3Holes, 1 - axis);

      final correctOpt = {
        'type': 'punch_hole',
        'unfolded': true,
        'fold_axis': axis,
        'holes': correctHoles,
      };

      final wrongOpts = [
        {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': axis,
          'holes': wrongPos,
        },
        {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': 1 - axis,
          'holes': wrongOppAxis,
        },
        {
          'type': 'punch_hole',
          'unfolded': true,
          'fold_axis': 1 - axis,
          'holes': wrongMixed,
        },
      ];

      final packed = _pack(correctOpt, wrongOpts);

      final correctKey = _holesKey(correctHoles);
      final exact = packed.opts
          .where((o) => _holesKey(List<Map<String, dynamic>>.from(o['holes'])) == correctKey)
          .length;
      if (exact != 1) continue;

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'punch_hole',
        type: 'punch_hole',
        puzzle: {
          'type': 'punch_hole',
          'unfolded': false,
          'fold_axis': axis,
          'holes': foldedHoles,
        },
        options: packed.opts,
        correctIndex: packed.idx,
      );
    }

    final fh = [
      {'x': 0.3, 'y': 0.3}
    ];
    final correctFb = [
      {'x': 0.3, 'y': 0.3},
      {'x': 0.7, 'y': 0.3}
    ];
    final w1 = [
      {'x': 0.3, 'y': 0.3},
      {'x': 0.3, 'y': 0.7}
    ];
    final w2 = [
      {'x': 0.25, 'y': 0.25},
      {'x': 0.75, 'y': 0.25}
    ];
    final w3 = [
      {'x': 0.4, 'y': 0.4},
      {'x': 0.6, 'y': 0.4}
    ];

    final correctOpt = {
      'type': 'punch_hole',
      'unfolded': true,
      'fold_axis': 0,
      'holes': correctFb,
    };
    final wrongOpts = [
      {
        'type': 'punch_hole',
        'unfolded': true,
        'fold_axis': 1,
        'holes': w1,
      },
      {
        'type': 'punch_hole',
        'unfolded': true,
        'fold_axis': 0,
        'holes': w2,
      },
      {
        'type': 'punch_hole',
        'unfolded': true,
        'fold_axis': 0,
        'holes': w3,
      },
    ];
    final packed = _pack(correctOpt, wrongOpts);

    return ReasoningQuestion(
      category: 'punch_hole',
      type: 'punch_hole',
      puzzle: {
        'type': 'punch_hole',
        'unfolded': false,
        'fold_axis': 0,
        'holes': fh,
      },
      options: packed.opts,
      correctIndex: packed.idx,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. EMBEDDED FIGURE
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _embedded() {
    const embShapes = [1, 2, 3, 7, 8];

    for (int attempt = 0; attempt < 40; attempt++) {
      final targetShape = embShapes[_r.nextInt(embShapes.length)];
      final targetFilled = _r.nextBool();
      final targetRot = _r.nextInt(4);
      final targetPos = _r.nextInt(3);
      final sigKey =
          'embed3:s$targetShape,f$targetFilled,r$targetRot,tp$targetPos';
      if (_seen(sigKey)) continue;

      final target = _f(targetShape, filled: targetFilled, rot: targetRot);

      List<Map<String, dynamic>> correctShapes(int tp) {
        final shapes = <Map<String, dynamic>>[];
        final used = <int>{targetShape};
        for (int i = 0; i < 3; i++) {
          if (i == tp) {
            shapes.add(target);
          } else {
            int s;
            do {
              s = embShapes[_r.nextInt(embShapes.length)];
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
            s = embShapes[_r.nextInt(embShapes.length)];
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

      // Pack embedded options sequentially via visual canonical fingerprint
      final packed = _pack(correct, wrongs);

      _markSeen(sigKey);
      return ReasoningQuestion(
        category: 'embedded',
        type: 'embedded',
        puzzle: {'type': 'embedded', 'target': target},
        options: packed.opts,
        correctIndex: packed.idx,
      );
    }

    final target = _f(2, filled: false, rot: 0);
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
    final correctFb = {
      'type': 'embedded_option',
      'shapes': [target, _f(3, filled: true), _f(8)],
      'offset': 2,
      'contains_target': true,
    };
    final packed = _pack(correctFb, opts);

    return ReasoningQuestion(
      category: 'embedded',
      type: 'embedded',
      puzzle: {'type': 'embedded', 'target': target},
      options: packed.opts,
      correctIndex: packed.idx,
    );
  }
}
