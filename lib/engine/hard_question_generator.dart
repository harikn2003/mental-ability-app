import 'dart:convert';
import 'dart:math';

import 'reasoning_question.dart';

/// HardQuestionGenerator - Complete Dart Implementation of Sandia Matrix
/// & RAVEN A-SIG Hierarchical Grammar Engine for Advanced Mental Ability Items.
class HardQuestionGenerator {
  static Random _r = Random();
  static final Set<String> _sessionHistory = {};

  /// Tracks the last few odd-man RULE TYPES handed out (not exact
  /// questions - _sessionHistory already guards against literal duplicate
  /// renders). Without this, nothing stops the same rule family (e.g.
  /// Constant Attribute) from firing several times in a row - different
  /// shapes and colors each time, so _sessionHistory sees them as "new",
  /// but a student experiences it as "the same kind of question again,"
  /// and starts recognizing the layout instead of reasoning about it.
  static final List<String> _recentOddManTypes = [];
  static const int _oddManCooldown = 3; // a type can't repeat within this many draws

  static void seed(int s) {
    _r = Random(s);
  }

  static void resetSession() {
    _sessionHistory.clear();
    _recentOddManTypes.clear();
    _recentOddManFamilies.clear();
    _recentPatternRecipes.clear();
  }

  /// Main Dispatch Method
  /// complexity: 1 = light, 2 = medium, 3 = full density (matches the real
  /// tool's actual ceiling - up to 3 stacked supplemental features per
  /// layer, 2 layers, logic layers in the mix). Only 'pattern' currently
  /// reads this; other categories are unaffected. Exposed as a parameter
  /// rather than a fixed internal constant because this exact knob - "let
  /// the caller pick Easy/Hard" - is already on your WIP slide, so it
  /// makes more sense for that toggle to set this than for me to keep
  /// re-guessing a single fixed density every round.
  static ReasoningQuestion generate(String category, {int complexity = 3}) {
    for (int attempts = 0; attempts < 350; attempts++) {
      ReasoningQuestion q = _buildQuestionForCategory(category, complexity);

      // Verify all 4 options are 100% visually unique under symmetry normalization
      final optionKeys = q.options.map((o) => _visibleKey(o)).toSet();
      if (optionKeys.length < q.options.length) {
        continue; // Discard and retry if options contain visual duplicates
      }
      // ...and if any pair differs only in ways too small to see.
      if (_hasNearDuplicateOptions(q.options)) continue;

      final sig = _buildCanonicalSignature(q);
      if (_sessionHistory.add(sig)) {
        return q;
      }
    }
    return _buildQuestionForCategory(category, complexity);
  }

  /// Testing-only. Exposes the exact same symmetry-aware visibility key
  /// used internally by generate()'s own dedup check (line ~47 above), so
  /// external test/diagnostic code can verify option distinctness without
  /// re-implementing (and risking drifting from) that logic. See
  /// test/hard_generator_diagnostics_test.dart.
  static List<String> debugOptionVisibleKeys(ReasoningQuestion q) => q.options.map(_visibleKey).toList();

  /// Testing-only. Companion to debugOptionVisibleKeys - that check answers
  /// "are any two options exactly identical" (should always be false by
  /// construction). This answers a different, harder question: for every
  /// pair of options that AREN'T identical, exactly which numeric
  /// attribute differs, and by how much? Built because a screenshot can
  /// make two options look like duplicates when the underlying data is
  /// technically different but the difference is small enough (e.g. a
  /// handful of rotation degrees, or two close-together fills) to be
  /// imperceptible in practice - that's a distinct failure mode from a
  /// literal duplicate, needs a distinct check, and can't be judged from a
  /// photo of a phone screen. Only understands the 'sandia_cell' schema
  /// (pattern/odd_man/figure_match); returns one line per option pair
  /// (6 pairs for 4 options) describing every attribute that differs.
  static List<String> debugOptionPairDiffs(ReasoningQuestion q) {
    // Shares _optionPairDiff with generate()'s live near-duplicate guard, so
    // this test hook and the guard can never disagree about what counts as
    // "too subtle to see".
    final lines = <String>[];
    final rasterCache = Map<Map<String, dynamic>, List<double>>.identity();
    for (int i = 0; i < q.options.length; i++) {
      for (int j = i + 1; j < q.options.length; j++) {
        final d = _optionPairDiff(q.options[i], q.options[j], rasterCache);
        if (d.diffs.isEmpty) {
          lines.add('option[$i] vs option[$j]: NO DIFFERENCE FOUND (renders identically once symmetry is normalized)');
        } else if (d.allSmall) {
          lines.add('option[$i] vs option[$j] [POSSIBLY TOO SUBTLE]: ${d.diffs.join(', ')}');
        }
      }
    }
    return lines;
  }

  // ---- symmetry-aware option comparison ---------------------------------------
  //
  // BUGFIX (the real version of history fix #14 - the guard that doc describes
  // was never actually present in this file): options used to be compared
  // attribute-by-attribute on their RAW data, which misses every way two
  // different data maps can paint the same pixels:
  //   - rectangle/ellipse/diamond look identical 180 degrees apart (diamond
  //     became a symmetric rhombus in sandia_painter.dart, but nothing here
  //     was updated to match - the cause of odd_man_rotational_repetition
  //     rendering two identical options)
  //   - on those same shapes, "rotate 90" and "swap w/h" are the SAME visual
  //     edit - so a pattern answer set built from those two perturbation
  //     bits collapses into two identical pairs (00==11, 01==10)
  //   - legacy surface 9 (thick cross) is 90-degree symmetric, not 180 -
  //     the cause of figure_series' exact-duplicate options
  //   - scale multiplies w/h; mirror on a left-right-symmetric shape just
  //     reverses the rotation direction
  // Everything below reduces a cell to what the painter actually draws
  // before comparing.

  static double _round3(num v) => (v * 1000).round() / 1000;

  static bool _isCentrallySymmetricShape(String shape) =>
      shape == 'ellipse' || shape == 'rectangle' || shape == 'diamond' || shape == 'line';

  static Map<String, dynamic> _canonicalAuthenticFeature(Map f) {
    final shape = f['shape'] as String? ?? 'ellipse';
    final scale = ((f['scale'] as num?) ?? 1.0).toDouble();
    double w = ((f['w'] as num?) ?? 0.5).toDouble() * scale;
    double h = ((f['h'] as num?) ?? 0.5).toDouble() * scale;
    if (shape == 'line') h = 0; // painter only reads w for a line
    int rot = ((f['rot'] as num?) ?? 0).round();
    // Every authentic shape is symmetric about its vertical axis, so
    // mirror-then-rotate(θ) paints the same as rotate(-θ).
    if (f['mirror'] == true) rot = -rot;
    rot %= 360; // Dart's % is Euclidean: always non-negative here
    if (_isCentrallySymmetricShape(shape)) {
      rot %= 180;
      if (rot >= 90 && shape != 'line') {
        // A quarter turn of a two-axis-symmetric shape == swapping w/h.
        rot -= 90;
        final t = w;
        w = h;
        h = t;
      }
      if (shape == 'ellipse' && (w - h).abs() < 1e-9) rot = 0; // circle
    }
    return {
      'cx': _round3(((f['cx'] as num?) ?? 0.5)),
      'cy': _round3(((f['cy'] as num?) ?? 0.5)),
      'shape': shape,
      'w': _round3(w),
      'h': _round3(h),
      'rot': rot,
      'fill': f['fill'] as String? ?? 'white',
    };
  }

  static Map<String, dynamic> _canonicalLegacyLayer(Map l) {
    final surface = l['surface'] as int? ?? 0;
    final lines = l['lines'] as int? ?? 0;
    final dotPos = l['dot_pos'] as int? ?? -1;
    // Rotation period of each drawn part, in quarter turns. The whole layer
    // only looks the same after k quarter turns if EVERY part does, and all
    // periods divide 4, so the layer's period is the largest part period.
    final surfacePeriod = (surface == 9 || surface >= 10) ? 1 : (surface == 1 || surface == 2) ? 2 : 4;
    final linesPeriod = switch (lines) { <= 0 => 1, 1 => 2, 2 || 3 => 1, _ => 4 };
    final dotPeriod = dotPos >= 0 ? 4 : 1;
    final period = max(surfacePeriod, max(linesPeriod, dotPeriod));
    return {
      'surface': surface,
      'fill': l['fill'] as int? ?? 0,
      'scale': _round3(((l['scale'] as num?) ?? 2)),
      'rotation': (l['rotation'] as int? ?? 0) % period,
      'mirror_h': l['mirror_h'] as bool? ?? false,
      'outline': l['outline'] as bool? ?? true,
      'grid_box': l['grid_box'] as bool? ?? false,
      'lines': lines,
      'dot_pos': dotPos,
    };
  }

  /// Every drawn element of a cell, symmetry-normalized and sorted so that
  /// two cells that paint the same pixels produce the same list.
  static List<Map<String, dynamic>> _canonicalFeatures(Map<String, dynamic> cell) {
    final out = <Map<String, dynamic>>[];
    if (cell['grid_box'] == true) out.add({'frame': true});
    for (final layer in (cell['layers'] as List? ?? [])) {
      final lm = layer as Map;
      if (lm.containsKey('features')) {
        if (lm['grid_box'] == true) out.add({'frame': true});
        for (final f in (lm['features'] as List? ?? [])) {
          out.add(_canonicalAuthenticFeature(f as Map));
        }
      } else {
        out.add(_canonicalLegacyLayer(lm));
      }
    }
    out.sort((a, b) => a.toString().compareTo(b.toString()));
    return out;
  }

  /// Every attribute that differs between two options once symmetry is
  /// normalized, and whether the pair is too close to tell apart (`allSmall`).
  /// `diffs` empty means the two options render identically. [rasterCache]
  /// lets a caller comparing many pairs rasterize each option only once.
  static ({List<String> diffs, bool allSmall}) _optionPairDiff(Map<String, dynamic> a, Map<String, dynamic> b,
      [Map<Map<String, dynamic>, List<double>>? rasterCache]) {
    if (a['type'] != 'sandia_cell' || b['type'] != 'sandia_cell') {
      final same = a.toString() == b.toString();
      return (diffs: same ? <String>[] : ['non-sandia option data differs'], allSmall: false);
    }
    final fa = _canonicalFeatures(a);
    final fb = _canonicalFeatures(b);
    if (fa.length != fb.length) {
      return (diffs: ['different feature counts (${fa.length} vs ${fb.length})'], allSmall: false);
    }
    final diffs = <String>[];
    var allSmall = true;
    var hasFillDiff = false;
    for (int k = 0; k < fa.length; k++) {
      for (final key in {...fa[k].keys, ...fb[k].keys}) {
        final va = fa[k][key];
        final vb = fb[k][key];
        if (va == vb) continue;
        diffs.add('feature[$k].$key: $va vs $vb');
        if (key == 'rot' && va is num && vb is num) {
          // Authentic rotation, degrees. Judge by angular distance within
          // the shape's own symmetry period.
          final period = _isCentrallySymmetricShape(fa[k]['shape'] as String? ?? '') ? 180 : 360;
          final raw = (va - vb).abs() % period;
          final angular = raw > period / 2 ? period - raw : raw;
          // Turning a very small feature (e.g. figure_match's ~10dp corner
          // triangle) isn't a dependable visible difference on its own - the
          // visual test measured two options separated only by such a flip
          // as indistinguishable. Under 0.2 of the cell is ~13dp at 64dp.
          final featureSize = max((fa[k]['w'] as num?) ?? 0, (fa[k]['h'] as num?) ?? 0);
          if (angular >= 20 && featureSize >= 0.2) allSmall = false;
        } else if ((key == 'scale' || key == 'w' || key == 'h') && va is num && vb is num) {
          final denom = (va.abs() + vb.abs()) / 2;
          final relDiff = denom == 0 ? 0 : (va - vb).abs() / denom;
          if (relDiff >= 0.15) allSmall = false;
        } else if ((key == 'cx' || key == 'cy') && va is num && vb is num) {
          if ((va - vb).abs() >= 0.08) allSmall = false;
        } else if (key == 'fill' && va is String && vb is String) {
          // Authentic fills are semi-transparent, so how visible a fill
          // change is depends on what's drawn under and over it - judged
          // below by actually compositing, not per attribute.
          hasFillDiff = true;
        } else {
          // Categorical (shape, surface, legacy fill, lines, quarter-turn
          // rotation, ...) - judged visible here; for authentic cells the
          // rasterizer below gets the final say.
          allSmall = false;
        }
      }
    }
    // Attribute rules can say a difference is too SMALL (a 5% scale change),
    // but not that an attribute change is too faint once drawn - that
    // depends on size, overlap and outlines. For authentic cells, anything
    // not already ruled too small is confirmed by compositing.
    if ((hasFillDiff || !allSmall) && _isRasterizable(a) && _isRasterizable(b)) {
      allSmall = !_rasterChangeIsVisible(a, b, rasterCache);
    }
    return (diffs: diffs, allSmall: allSmall);
  }

  // ---- visibility rasterizer -----------------------------------------------------
  //
  // BUGFIX: attribute diffs call every fill/shape change "visible", but the
  // visual test showed several that aren't once actually drawn:
  //   - a fill change on a shape under another semi-transparent shape is
  //     attenuated by every layer on top - black vs grey10 under a grey10
  //     diamond composites to 41 vs 63 (out of 255)
  //   - white vs grey75 is only ~26 apart even uncovered
  //   - on a thin shape the dark outline hides much of the fill
  //   - swapping between similar outlines (trapezoid/triangle) on a small
  //     white shape changes only a sliver of pixels
  // This composites each option's fills and outlines on a 64x64 grid (the
  // app's 64dp option size), in the same order SandiaPainter draws them, and
  // checks how much of the cell actually changes - the same measure the
  // visual test applies to real renders.

  /// Mirrors SandiaFill.palette in sandia_painter.dart as (channel, alpha) -
  /// if you change one, change both (same convention as SandiaFillCompat).
  static const Map<String, List<double>> _fillLumAlpha = {
    'white': [255, 0.0],
    'grey75': [191, 0.4],
    'grey40': [102, 0.5],
    'grey10': [26, 0.6],
    'black': [0, 0.75],
  };

  // One sample per dp at the app's 64dp option size.
  static const int _rasterN = 64;
  // SandiaPainter strokes every authentic shape with a 2.0dp dark outline,
  // centred on the edge - on a thin shape that eats a big share of the
  // visible fill, so it has to be modelled: half the stroke width plus a
  // little anti-aliasing, as a fraction of the cell.
  static const double _strokeHalfBand = 1.5 / 64;
  static const double _strokeLum = 23; // SandiaPainter's 0xFF0F172A outline
  // Kept at or stricter than test/hard_generator_visual_test.dart's own
  // "indistinguishable" cut-offs (>25 difference, <2% of pixels), so any pair
  // that test would flag is already rejected here. At the app's 64dp option
  // size, 2% of the cell is roughly a 9x9dp patch.
  static const double _minVisibleLumDiff = 30; // the visual test's minAdjacentFillDistance
  static const double _minVisibleAreaFraction = 0.02; // the visual test's significantPixelFractionThreshold

  static bool _insideShape(String shape, double x, double y, double hw, double hh) {
    if (hw <= 0 || hh <= 0) return false;
    switch (shape) {
      case 'rectangle':
        return x.abs() <= hw && y.abs() <= hh;
      case 'triangle':
        if (y < -hh || y > hh) return false;
        return x.abs() <= hw * (y + hh) / (2 * hh);
      case 'diamond':
        return x.abs() / hw + y.abs() / hh <= 1;
      case 'trapezoid':
        if (y < -hh || y > hh) return false;
        final qw = hw / 2;
        return x.abs() <= qw + (hw - qw) * (y + hh) / (2 * hh);
      case 'tee':
        if (y < -hh || y > hh) return false;
        return y <= -hh / 2 ? x.abs() <= hw : x.abs() <= hw / 2;
      case 'line':
        return false; // stroke only, no fill
      default: // ellipse
        return (x / hw) * (x / hw) + (y / hh) * (y / hh) <= 1;
    }
  }

  /// Authentic-schema cells only: the rasterizer doesn't draw legacy layers
  /// (figure_series/analogy), nor 'line' features, which no generator uses.
  static bool _isRasterizable(Map<String, dynamic> cell) {
    final layers = cell['layers'] as List? ?? [];
    if (layers.isEmpty) return false;
    for (final layer in layers) {
      final lm = layer as Map;
      if (!lm.containsKey('features')) return false;
      for (final f in (lm['features'] as List? ?? [])) {
        if ((f as Map)['shape'] == 'line') return false;
      }
    }
    return true;
  }

  /// SandiaPainter._drawFrame: a square outline at 0.9 of the cell.
  static void _rasterFrame(List<double> lum) {
    for (int j = 0; j < _rasterN; j++) {
      for (int i = 0; i < _rasterN; i++) {
        final x = ((i + 0.5) / _rasterN - 0.5).abs();
        final y = ((j + 0.5) / _rasterN - 0.5).abs();
        final edgeDist = min((x - 0.45).abs(), (y - 0.45).abs());
        if (x <= 0.45 + _strokeHalfBand && y <= 0.45 + _strokeHalfBand && edgeDist <= _strokeHalfBand) {
          lum[j * _rasterN + i] = _strokeLum;
        }
      }
    }
  }

  /// Per-sample composited luminance of a cell's fills and outlines, in the
  /// order SandiaPainter draws them.
  static List<double> _rasterize(Map<String, dynamic> cell) {
    final lum = List<double>.filled(_rasterN * _rasterN, 255);
    if (cell['grid_box'] == true) _rasterFrame(lum);
    for (final layer in (cell['layers'] as List? ?? [])) {
      if ((layer as Map)['grid_box'] == true) _rasterFrame(lum);
      for (final raw in (layer['features'] as List? ?? [])) {
        final f = raw as Map;
        final la = _fillLumAlpha[f['fill']] ?? _fillLumAlpha['white']!;
        final shape = f['shape'] as String? ?? 'ellipse';
        final scale = ((f['scale'] as num?) ?? 1.0).toDouble();
        final hw = ((f['w'] as num?) ?? 0.5).toDouble() * scale / 2;
        final hh = ((f['h'] as num?) ?? 0.5).toDouble() * scale / 2;
        final cx = ((f['cx'] as num?) ?? 0.5).toDouble();
        final cy = ((f['cy'] as num?) ?? 0.5).toDouble();
        final theta = ((f['rot'] as num?) ?? 0).toDouble() * pi / 180;
        final c = cos(theta), s = sin(theta);
        final mirror = f['mirror'] == true;
        for (int j = 0; j < _rasterN; j++) {
          for (int i = 0; i < _rasterN; i++) {
            // Invert the painter's translate -> mirror -> rotate transform.
            var dx = (i + 0.5) / _rasterN - cx;
            final dy = (j + 0.5) / _rasterN - cy;
            if (mirror) dx = -dx;
            final x = dx * c + dy * s;
            final y = -dx * s + dy * c;
            final idx = j * _rasterN + i;
            final inside = _insideShape(shape, x, y, hw, hh);
            // On the outline band if any nearby point is on the other side
            // of the edge. Rotation-invariant offsets, so testing in local
            // coordinates is fine.
            const d = _strokeHalfBand;
            final onEdge = _insideShape(shape, x + d, y, hw, hh) != inside ||
                _insideShape(shape, x - d, y, hw, hh) != inside ||
                _insideShape(shape, x, y + d, hw, hh) != inside ||
                _insideShape(shape, x, y - d, hw, hh) != inside;
            if (onEdge) {
              lum[idx] = _strokeLum;
            } else if (inside) {
              lum[idx] = la[1] * la[0] + (1 - la[1]) * lum[idx];
            }
          }
        }
      }
    }
    return lum;
  }

  static bool _rasterChangeIsVisible(Map<String, dynamic> a, Map<String, dynamic> b,
      [Map<Map<String, dynamic>, List<double>>? cache]) {
    final ra = cache == null ? _rasterize(a) : cache.putIfAbsent(a, () => _rasterize(a));
    final rb = cache == null ? _rasterize(b) : cache.putIfAbsent(b, () => _rasterize(b));
    int changed = 0;
    for (int i = 0; i < ra.length; i++) {
      if ((ra[i] - rb[i]).abs() >= _minVisibleLumDiff) changed++;
    }
    return changed >= ra.length * _minVisibleAreaFraction;
  }

  /// True if any two options render identically or differ only in ways
  /// too small to see. Used by generate() as a live guard.
  static bool _hasNearDuplicateOptions(List<Map<String, dynamic>> options) {
    final rasterCache = Map<Map<String, dynamic>, List<double>>.identity();
    for (int i = 0; i < options.length; i++) {
      for (int j = i + 1; j < options.length; j++) {
        final d = _optionPairDiff(options[i], options[j], rasterCache);
        if (d.diffs.isEmpty || d.allSmall) return true;
      }
    }
    return false;
  }

  /// Testing-only. Walks a question's puzzle + options looking for any
  /// rendered feature whose effective on-screen size (w*scale or h*scale)
  /// falls under [minFraction] of the cell - the exact failure mode behind
  /// every "too small to see" bug found by hand this session (dot markers,
  /// compounded scale-down chains, etc). Returns a human-readable line per
  /// offender so a test can print them for review; empty list means none
  /// found. Only understands the 'sandia_cell' authentic schema (pattern,
  /// odd_man, figure_match) - figure_series/analogy use a different legacy
  /// int-based schema this does not walk, so an empty result for those
  /// categories means "not checked", not "confirmed fine".
  static List<String> debugTinyFeatureWarnings(ReasoningQuestion q, {double minFraction = 0.12}) {
    final warnings = <String>[];
    void walkCell(Map<String, dynamic> cell, String label) {
      if (cell['type'] != 'sandia_cell') return;
      final layers = cell['layers'] as List? ?? [];
      for (int li = 0; li < layers.length; li++) {
        final feats = (layers[li] as Map)['features'] as List? ?? [];
        for (int fi = 0; fi < feats.length; fi++) {
          final f = feats[fi] as Map;
          final w = ((f['w'] as num?) ?? 0.5).toDouble();
          final h = ((f['h'] as num?) ?? 0.5).toDouble();
          final scale = ((f['scale'] as num?) ?? 1.0).toDouble();
          final effW = w * scale, effH = h * scale;
          if (effW < minFraction || effH < minFraction) {
            warnings.add('$label layer[$li] feature[$fi] shape=${f['shape']} '
                'effW=${effW.toStringAsFixed(3)} effH=${effH.toStringAsFixed(3)} (min=$minFraction)');
          }
        }
      }
    }

    final cells = q.puzzle['cells'] as List?;
    if (cells != null) {
      for (int i = 0; i < cells.length; i++) {
        final c = cells[i] as Map<String, dynamic>;
        if (c['empty'] == true) continue;
        walkCell(c, 'context-cell[$i]');
      }
    }
    for (int i = 0; i < q.options.length; i++) {
      walkCell(q.options[i], 'option[$i]');
    }
    return warnings;
  }

  /// Testing-only. For 'pattern' questions specifically: independently
  /// re-checks the same "row/column giveaway" condition _sgmHasRowColGiveaway
  /// guards against at generation time (two OTHER cells sharing the missing
  /// cell's row or column being visually identical to each other, letting
  /// the answer be guessed without any real reasoning) - reimplemented here
  /// against the returned puzzle data only, as a regression trip-wire that
  /// doesn't depend on that internal guard staying correct.
  static bool debugHasRowColGiveaway(ReasoningQuestion q) {
    if (q.puzzle['type'] != 'matrix') return false;
    final cells = q.puzzle['cells'] as List;
    String keyOf(int i) => jsonEncode(cells[i]);
    // cells is row-major 3x3, index 8 (row2,col2) is the missing cell.
    // row match: cells[6] (r2c0) vs cells[7] (r2c1); col match: cells[2]
    // (r0c2) vs cells[5] (r1c2).
    return keyOf(6) == keyOf(7) || keyOf(2) == keyOf(5);
  }

  static ReasoningQuestion _buildQuestionForCategory(String category, int complexity) {
    switch (category) {
      case 'odd_man':
        return _generateHardOddMan();
      case 'pattern':
        return _generateFullSandiaMatrix(complexity: complexity);
      case 'figure_match':
        return _generateHardFigureMatch();
      case 'figure_series':
        return _generateDenseMultiLayerSeries();
      case 'analogy':
        return _generateDenseMultiLayerAnalogy();
      default:
        // Was a silent fallback to Odd Man Out, which is how Hard Mode for
        // the non-Sandia topics ended up serving the wrong category. Those
        // are routed in QuestionGenerator.generate now; fail loudly if a
        // caller ever gets it wrong again.
        throw ArgumentError.value(category, 'category', 'not a HardQuestionGenerator category');
    }
  }

  /// Symmetry-aware visual key: two options with the same key paint the
  /// same pixels. See _canonicalFeatures.
  static String _visibleKey(Map<String, dynamic> m) {
    if (m['type'] == 'sandia_cell') return _canonicalFeatures(m).toString();
    return m.toString();
  }

  static String _buildCanonicalSignature(ReasoningQuestion q) {
    final Map<String, dynamic> data = {
      'category': q.category,
      'type': q.type,
      'puzzle': q.puzzle,
      'correctIndex': q.correctIndex,
      'options': q.options,
    };
    return _canonicalJson(data);
  }

  static String _canonicalJson(dynamic val) {
    if (val is Map) {
      final keys = val.keys.map((k) => k.toString()).toList()..sort();
      final Map<String, dynamic> sorted = {};
      for (final k in keys) {
        sorted[k] = val[k];
      }
      return jsonEncode(sorted, toEncodable: (nonEncodable) => _canonicalJson(nonEncodable));
    } else if (val is List) {
      return jsonEncode(val.map((e) => _canonicalJson(e)).toList());
    }
    return val.toString();
  }

  // ===========================================================================
  // AUTHENTIC SANDIA SURFACE-FEATURE HELPERS
  //
  // Ported building blocks from:
  //   gov.sandia.cognition.generator.matrix.surface.*SGMSurfaceFeature
  //   gov.sandia.cognition.generator.matrix.fillpattern.*SGMFillPattern
  //   gov.sandia.cognition.generator.matrix.structure.supplemental.*
  //   gov.sandia.cognition.generator.matrix.structure.base.*
  // ===========================================================================

  /// The 6 stochastically-generated shape types from
  /// SGMSurfaceFeatureGenerator.generateSurfaceFeature() (excludes Line,
  /// which that generator's switch never reaches - case 6 is commented out
  /// in the original source).
  static const List<String> _shapePool = [
    'ellipse',
    'rectangle',
    'triangle',
    'tee',
    'diamond',
    'trapezoid',
  ];

  /// SGMFillPatternGenerator.generateFillPattern(random) default 3-pattern
  /// pool (White / Grey75 / Black) used when generating plain surface
  /// features (as opposed to the full 5-pattern pool used specifically by
  /// the fill-pattern structure features).
  static const List<String> _basicFillPool = ['white', 'grey75', 'black'];

  /// Fill palette used by rules that require SPOTTING a fill difference
  /// (ChangeFillPattern, FillPatternRepetition, ConsistentUnion).
  ///
  /// BUGFIX: the original 5-step cycle included 'grey75', which renders at
  /// ~90% brightness - only about a 10% step down from white, and visually
  /// indistinguishable from it at small sizes, especially for a thin
  /// outlined shape on a white card. Any rule asking a solver to spot
  /// "which fill differs" or "which two fills match" silently became
  /// unsolvable whenever the pool happened to include both white and
  /// grey75. This 4-value palette keeps every adjacent step at least ~30%
  /// apart (255 / 179 / 117 / 64), so any fill difference the rule depends
  /// on is actually visible.
  static const List<String> _fillCycle = ['white', 'grey40', 'grey10', 'black'];

  static Map<String, dynamic> _feature(
      String shape, {
        double w = 0.5,
        double h = 0.5,
        int rot = 0,
        double cx = 0.5,
        double cy = 0.5,
        double scale = 1.0,
        String fill = 'white',
      }) =>
      {
        'shape': shape,
        'w': w,
        'h': h,
        'rot': rot,
        'cx': cx,
        'cy': cy,
        'scale': scale,
        'fill': fill,
      };

  static Map<String, dynamic> _cell(List<Map<String, dynamic>> features, {bool gridBox = false}) => {
    'type': 'sandia_cell',
    'grid_box': gridBox,
    'layers': [
      {'features': features},
    ],
  };

  static String _randomShape([List<String>? exclude]) {
    final pool = exclude == null ? _shapePool : _shapePool.where((s) => !exclude.contains(s)).toList();
    return pool[_r.nextInt(pool.length)];
  }

  // ===========================================================================
  // 1. HARD ODD MAN OUT GENERATORS
  //    Each sub-generator implements one authentic Sandia STRUCTURE FEATURE
  //    (a transform rule that 3 options obey and 1 option violates).
  // ===========================================================================

  /// Same idea as _recentOddManTypes, one level up: several of the 7 rule
  /// types are technically different but LOOK the same at a glance, so
  /// blocking only the exact type let two visually-identical archetypes
  /// (rotation-nesting, scaling-nesting) alternate freely and still read
  /// as "the same question again." Each type belongs to a family; the
  /// family also gets excluded for a (shorter) cooldown window.
  static final List<String> _recentOddManFamilies = [];
  static const int _oddManFamilyCooldown = 2;

  static const Map<String, String> _oddManFamily = {
    // outer shape + smaller copy nested inside, compare one attribute
    'rotational_repetition': 'nested_shape',
    'scaling_repetition': 'nested_shape',
    // two side-by-side/layered shapes, compare their fills
    'change_fill_pattern': 'fill_compare',
    'fill_pattern_repetition': 'fill_compare',
    // count things and check a relationship
    'translational_numerosity': 'count',
    'arithmetic': 'count',
    // single shape, spot the different one
    'constant_attribute': 'color_spot',
  };

  static ReasoningQuestion _generateHardOddMan() {
    final subTypes = <String, ReasoningQuestion Function()>{
      'rotational_repetition': _oddManRotationalRepetition,
      'scaling_repetition': _oddManScalingRepetition,
      // _oddManChangeFillPattern and _oddManFillPatternRepetition retired
      // from Hard Mode (2026-09-23): both hinge on judging one-shade steps
      // between semi-transparent greys, which testers couldn't do by eye -
      // the source of the tracker's "why is this the answer" / "circle in a
      // square" / "clarity on odd man out" reports. Replaced in Hard Mode by
      // the exam-style mirror-image odd man out (ExamStyleGenerator.oddManOut).
      'translational_numerosity': _oddManTranslationalNumerosity,
      'arithmetic': _oddManArithmetic,
      // _oddManConstantAttribute intentionally excluded: reported three
      // times as "easy question in hard mode" (one shape, spot the different
      // fill) - an easy-tier rule. Its 3 majority options are also
      // pixel-identical, so generate()'s duplicate guard rejected it anyway.
      // _oddManLogicalCombination intentionally excluded - see note where
      // it's defined below.
    };

    // Exclude whichever exact types were used in the last _oddManCooldown
    // draws, AND whichever families were used in the last
    // _oddManFamilyCooldown draws. Relax family first, then type, then
    // fall back to the full pool - never leave the pool empty.
    var available = subTypes.keys
        .where((k) => !_recentOddManTypes.contains(k) && !_recentOddManFamilies.contains(_oddManFamily[k]))
        .toList();
    if (available.isEmpty) {
      available = subTypes.keys.where((k) => !_recentOddManTypes.contains(k)).toList();
    }
    if (available.isEmpty) available = subTypes.keys.toList();

    final chosenKey = available[_r.nextInt(available.length)];

    _recentOddManTypes.add(chosenKey);
    while (_recentOddManTypes.length > _oddManCooldown) {
      _recentOddManTypes.removeAt(0);
    }
    _recentOddManFamilies.add(_oddManFamily[chosenKey]!);
    while (_recentOddManFamilies.length > _oddManFamilyCooldown) {
      _recentOddManFamilies.removeAt(0);
    }

    return subTypes[chosenKey]!();
  }

  /// 1. ROTATIONAL REPETITION (ApplyRotationSGMStructureFeature)
  /// Java: feature.rotation = rotateAmount(45) + previousLocationFeature.rotation
  /// i.e. an inner accent feature's rotation must always be exactly 45 degrees
  /// ahead of the outer "base" feature's rotation, regardless of what the
  /// outer rotation itself is.
  /// - 3 majority: inner rotation = outer rotation + 45
  /// - 1 odd: inner rotation offset by something other than 45 (e.g. 0 or 90)
  ///
  /// BUGFIX (round 1): 'ellipse' is excluded from this generator's shape
  /// pool. A circle looks identical at every rotation, so if it were ever
  /// picked as the inner accent, the entire rule would be invisible on
  /// screen. wrongOffset is also restricted to values that are NOT
  /// congruent to 45 (mod 90).
  ///
  /// BUGFIX (round 2 - tighter ruleset): the inner and outer used to be two
  /// DIFFERENT shape types (e.g. a tee bracket with a diamond twisted
  /// inside it). Judging "is shape B rotated exactly 45 degrees more than
  /// unrelated shape A" requires mentally aligning two different outlines'
  /// coordinate frames - technically visible, but too hard to do reliably
  /// by eye. The inner is now always a smaller copy of the SAME shape as
  /// the outer, so the comparison becomes "is the small copy twisted
  /// relative to the big copy of the same shape" - a single, direct
  /// same-shape comparison, the standard way this kind of item is posed.
  // BUGFIX: 'tee' removed from this pool despite the name - a T-shape
  // rotated 90 degrees doesn't read as "the same shape turned", it reads
  // as a completely different glyph (a bracket, ⊢), and 270 degrees reads
  // as its mirror (⊣). A human comparing 4 options at 4 different
  // rotations would see what looks like two unrelated shape families
  // (T-like and bracket-like) instead of one shape in different
  // orientations - exactly the "looks like 2 pairs, not 3-vs-1" ambiguity
  // this rule depends on avoiding. rectangle/triangle/diamond/trapezoid
  // all remain visually continuous (recognizably "the same shape,
  // rotated") across all four cardinal rotations, which is the actual
  // bar for belonging in a pool literally named "rotation-safe".
  static const List<String> _rotationSafeShapes = ['rectangle', 'triangle', 'diamond', 'trapezoid'];

  static ReasoningQuestion _oddManRotationalRepetition() {
    final shape = _rotationSafeShapes[_r.nextInt(_rotationSafeShapes.length)];
    final outerFill = _basicFillPool[_r.nextInt(_basicFillPool.length)];
    final innerFill = (_basicFillPool.where((f) => f != outerFill).toList()..shuffle(_r)).first;

    // Non-square proportions (ported from SGMSurfaceFeatureGenerator, see
    // _sgmRandomDims) instead of a fixed square, scaled up slightly to
    // fill the cell the way the old 0.78 constant did. Inner keeps the
    // SAME aspect ratio as outer, just smaller - it's a nested copy of the
    // same shape, not a differently-proportioned one.
    final outerDims = _sgmRandomDims();
    final outerW = outerDims[0] * 1.05;
    final outerH = outerDims[1] * 1.05;
    final innerW = outerW * 0.54;
    final innerH = outerH * 0.54;

    // BUGFIX: rectangle and diamond (a symmetric rhombus since the painter
    // fix) look identical 180 degrees apart, so outer 90/inner 135 and outer
    // 270/inner 315 were two pixel-identical majority options (~11% of
    // odd_man questions, caught by the visual test). For those shapes, spread
    // the four outer rotations across 180 degrees instead of 360 so every
    // option is a genuinely different orientation.
    final centrallySymmetric = _isCentrallySymmetricShape(shape);
    final baseRotations = (centrallySymmetric ? [0, 45, 90, 135] : [0, 90, 180, 270])..shuffle(_r); // one per option
    final oddIndex = _r.nextInt(4);
    // Wrong offsets: anything that is not congruent to 45 (mod 90), so the
    // "wrong" option can never accidentally render the same as the correct
    // diagonal orientation.
    final wrongOffset = [0, 90, 180, 270][_r.nextInt(4)];

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final outerRot = baseRotations[i];
      final innerRot = (i == oddIndex) ? (outerRot + wrongOffset) % 360 : (outerRot + 45) % 360;

      options.add(_cell([
        _feature(shape, w: outerW, h: outerH, rot: outerRot, fill: outerFill),
        _feature(shape, w: innerW, h: innerH, rot: innerRot, fill: innerFill),
      ], gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_rotational_repetition',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 2. SCALING REPETITION (ApplyScalingSGMStructureFeature)
  /// Java: feature.scale = scaleAmount(0.66) * previousLocationFeature.scale
  /// i.e. a nested inner copy of the SAME shape must always be scaled by
  /// exactly 0.66x relative to the outer copy.
  /// - 3 majority: inner width/height = outer * 0.66
  /// - 1 odd: inner scaled by a different factor
  static ReasoningQuestion _oddManScalingRepetition() {
    const correctFactor = 0.66;
    final wrongFactors = [0.4, 0.5, 0.85]..shuffle(_r);
    final wrongFactor = wrongFactors.first;

    // BUGFIX: 'tee' excluded, as in _rotationSafeShapes - a turned T reads as
    // a different glyph, so the options looked like two shape families and
    // drew attention away from the inner-size rule (tracker: "Bluberry
    // build: Ambiguity 1 in odd man", 2nd screenshot).
    final shape = _randomShape(['tee']);
    final oddIndex = _r.nextInt(4);
    // BUGFIX: was an independent rotation per option ([0,90,180,270]
    // shuffled across the 4 options). Rotation plays no role in this
    // rule's actual correctness signal (that's purely the scale ratio),
    // so varying it per-option only added risk for no benefit - any
    // shape whose silhouette isn't perfectly continuous across all 4
    // cardinal turns (e.g. 'tee', which reads as a bracket at 90/270) can
    // make 4 different rotations look like two unrelated shape families
    // instead of one shape turned four ways, the same ambiguity fixed in
    // _rotationSafeShapes above. A single shared rotation still varies
    // question-to-question, just not misleadingly within one question.
    final rotation = [0, 90, 180, 270][_r.nextInt(4)];
    // BUGFIX: fill used to be an independent random shade per option
    // (one each of white/grey75/grey40/black). That's a far more visually
    // salient difference than the actual rule (a 0.66 vs 0.4/0.5/0.85
    // size ratio), so it draws all the attention while being completely
    // irrelevant to correctness - reported directly as "unclear why this
    // is the answer... why not a different option". Holding fill constant
    // removes the competing, irrelevant signal so size is the only thing
    // left to compare.
    const innerFill = 'grey40';
    // BUGFIX: with shape, rotation and fill all shared, the 3 majority
    // options were pixel-identical - a "spot the different picture" item
    // that generate()'s duplicate guard rejected every time, so this rule
    // never actually appeared. Each option now gets a different OUTER size
    // (steps ~20% apart, comfortably past the near-duplicate threshold)
    // while the inner:outer ratio stays the rule, so the solver has to
    // compare ratios rather than absolute sizes - which is the point of
    // ApplyScalingSGMStructureFeature in the first place.
    // Only the (0.5, 0.75) dims are used: with the 1:2 / 1:3 dims the
    // smallest option's inner at the 0.4 wrong factor fell under the 0.12
    // legibility threshold. Smallest possible inner: 0.5 x 0.65 x 0.4 = 0.13.
    final outerDims = _r.nextBool() ? [0.5, 0.75] : [0.75, 0.5];
    final sizeSteps = [0.65, 0.78, 0.94, 1.12]..shuffle(_r); // largest: 0.75 x 1.12 = 0.84, inside the 0.9 frame

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final factor = (i == oddIndex) ? wrongFactor : correctFactor;
      final outerW = outerDims[0] * sizeSteps[i];
      final outerH = outerDims[1] * sizeSteps[i];

      options.add(_cell([
        _feature(shape, w: outerW, h: outerH, rot: rotation, fill: 'white'),
        _feature(shape, w: outerW * factor, h: outerH * factor, rot: rotation, fill: innerFill),
      ], gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_scaling_repetition',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 3. CHANGE FILL PATTERN (ChangeFillPatternSGMStructureFeature)
  /// Java: fillIndex = (baseFillPatterns.indexOf(previous.fillPattern) + 1)
  ///                     % baseFillPatterns.size()
  /// i.e. the foreground feature's fill must always be exactly ONE STEP
  /// darker (next in the White->Grey40->Grey10->Black cycle) than
  /// the background feature's fill.
  /// - 3 majority: fg fill = cycle.next(bg fill)
  /// - 1 odd: fg fill breaks that one-step adjacency
  ///
  /// BUGFIX: 'black' used to be a valid bg starting shade. Since it's the
  /// last entry in the cycle, "next" wrapped it around to 'white' - so on
  /// whichever option got a black background, the foreground would jump to
  /// the LIGHTEST possible fill instead of getting darker. A solver trying
  /// to infer "the front shape is always a bit darker than the back one"
  /// would hit that option and see the opposite, which reads as a
  /// contradiction rather than a pattern. 'black' is now excluded from the
  /// bg starting pool, so fg is always genuinely darker than bg, no
  /// exceptions.
  static const List<String> _changeFillBgPool = ['white', 'grey40', 'grey10'];

  // RETIRED from Hard Mode - see the note in _generateHardOddMan's subTypes.
  // ignore: unused_element
  static ReasoningQuestion _oddManChangeFillPattern() {
    final bgShape = _randomShape();
    final fgShape = _randomShape([bgShape]);
    final oddIndex = _r.nextInt(4);
    // Rotation is fixed per question (same for every option) rather than
    // randomized per option - see the Constant Attribute bugfix note above
    // for why per-option rotation is dangerous for asymmetric shapes.
    final bgRot = [0, 90, 180, 270][_r.nextInt(4)];
    final fgRot = [0, 90, 180, 270][_r.nextInt(4)];
    final bgDims = _sgmRandomDims();
    final bgW = bgDims[0] * 1.05;
    final bgH = bgDims[1] * 1.05;
    final fgDims = _sgmRandomDims();
    // BUGFIX: fg carries the entire correctness signal (a one-step fill
    // difference from bg) and nothing else - at the old 0.56 multiplier,
    // _sgmRandomDims' smallest tier (0.25) could shrink it to 0.14 of the
    // cell. Even a well-spaced, technically-correct one-step shade
    // difference is hard to judge confidently on an area that small.
    // Floored so the fill always has enough visible surface to read.
    final fgW = max(fgDims[0] * 0.7, 0.22);
    final fgH = max(fgDims[1] * 0.7, 0.22);

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final bgFill = _changeFillBgPool[_r.nextInt(_changeFillBgPool.length)];
      final correctFg = SandiaFillCompat.next(bgFill);
      String fgFill = correctFg;
      if (i == oddIndex) {
        // Break the adjacency: repeat bg's fill, or skip two steps ahead
        final alt = [bgFill, SandiaFillCompat.next(correctFg)]..shuffle(_r);
        fgFill = alt.first;
      }

      options.add(_cell([
        _feature(bgShape, w: bgW, h: bgH, rot: bgRot, fill: bgFill),
        _feature(fgShape, w: fgW, h: fgH, rot: fgRot, fill: fgFill),
      ], gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_change_fill_pattern',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 4. FILL PATTERN REPETITION (FillPatternRepetitionSGMStructureFeature)
  /// Java: feature.fillPattern = previousLocationFeature.fillPattern
  /// i.e. two DIFFERENT shapes in the same cell must always share the exact
  /// same fill pattern (fill pattern is "repeated", not advanced).
  /// - 3 majority: shapeA.fill == shapeB.fill
  /// - 1 odd: shapeA.fill != shapeB.fill
  ///
  /// BUGFIX: shapeA and shapeB were 0.55 wide each, centered only 0.36
  /// apart (cx 0.32 / 0.68) - their bounding areas overlapped by roughly a
  /// third. For wide shapes like triangle or trapezoid this made the two
  /// supposedly-separate shapes visually merge into one composite blob
  /// (e.g. a circle appearing to sit "inside" a triangle instead of beside
  /// it), which defeats a rule that depends on reading them as two
  /// distinct fills. They're now smaller and spaced further apart, with a
  /// safety margin so even the widest shape pairing stays visually
  /// separate.
  // RETIRED from Hard Mode - see the note in _generateHardOddMan's subTypes.
  // ignore: unused_element
  static ReasoningQuestion _oddManFillPatternRepetition() {
    final shapeA = _randomShape();
    final shapeB = _randomShape([shapeA]);
    final oddIndex = _r.nextInt(4);
    // Rotation fixed per question, not per option - see Constant Attribute
    // bugfix note above.
    final rotA = [0, 90, 180, 270][_r.nextInt(4)];
    final rotB = [0, 90, 180, 270][_r.nextInt(4)];
    // Scaled down from _sgmRandomDims' raw 0.25-0.75 range to 0.13-0.4, so
    // even the largest possible pairing still clears the no-overlap
    // spacing (cx 0.26/0.74) fixed earlier - two 0.4-wide shapes leave a
    // guaranteed gap, where two raw 0.75-wide ones would collide again.
    const dimsScale = 0.533;
    final dimsA = _sgmRandomDims().map((d) => d * dimsScale).toList();
    final dimsB = _sgmRandomDims().map((d) => d * dimsScale).toList();

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final sharedFill = _fillCycle[_r.nextInt(_fillCycle.length)];
      String fillA = sharedFill;
      String fillB = sharedFill;
      if (i == oddIndex) {
        fillB = _maxContrastFill(sharedFill);
      }

      options.add(_cell([
        _feature(shapeA, w: dimsA[0], h: dimsA[1], rot: rotA, cx: 0.26, cy: 0.5, fill: fillA),
        _feature(shapeB, w: dimsB[0], h: dimsB[1], rot: rotB, cx: 0.74, cy: 0.5, fill: fillB),
      ], gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_fill_pattern_repetition',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 5. TRANSLATIONAL NUMEROSITY (TranslationalNumerositySGMStructureFeature)
  /// Java: numPositions = ceil(sqrt(maxDimension + initialNumerosity - 1));
  ///       positionStepSize = cellPixelSize / (numPositions + 1);
  ///       scaling = 0.75 / numPositions;
  ///       grid-fills copies left-to-right, top-to-bottom without overlap.
  /// - 3 majority: a fixed copy-count N, laid out via the exact formula above
  /// - 1 odd: a different copy-count N' (still laid out correctly - the
  ///   violation is purely the count, not sloppy placement)
  static ReasoningQuestion _oddManTranslationalNumerosity() {
    final fill = _basicFillPool[_r.nextInt(_basicFillPool.length)];
    final majorityCount = [2, 3, 4][_r.nextInt(3)];
    int oddCount;
    do {
      oddCount = [2, 3, 4, 5][_r.nextInt(4)];
    } while (oddCount == majorityCount);

    final oddIndex = _r.nextInt(4);
    // BUGFIX: one shared shape made the 3 majority options pixel-identical,
    // so generate()'s duplicate guard rejected this rule every time and it
    // never appeared. Each option now uses a different shape: count is the
    // only thing the 3 majority options share, so the solver has to count
    // rather than spot the odd picture - and since all 4 shapes differ, no
    // single option stands out by shape.
    final shapes = List<String>.from(_shapePool)..shuffle(_r);

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final count = (i == oddIndex) ? oddCount : majorityCount;
      options.add(_cell(_numerosityFeatures(shapes[i], fill, count), gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_translational_numerosity',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// Faithful port of TranslationalNumerositySGMStructureFeature's grid
  /// layout math (provideBaseSurfaceFeatures branch): a square grid of
  /// `count` non-overlapping shrunk copies, filled row-major.
  static List<Map<String, dynamic>> _numerosityFeatures(String shape, String fill, int count,
      {double extraScale = 1.0, int rot = 0}) {
    final numPositions = sqrt(count).ceil();
    final positionStep = 1.0 / (numPositions + 1); // fraction of cell (pixel formula normalized to [0,1])
    final scaling = (0.75 / numPositions) * extraScale;

    final features = <Map<String, dynamic>>[];
    int col = 0, row = 0;
    for (int i = 0; i < count; i++) {
      final cx = (col + 1) * positionStep;
      final cy = (row + 1) * positionStep;
      features.add(_feature(shape, w: 0.85, h: 0.85, scale: scaling, rot: rot, cx: cx, cy: cy, fill: fill));
      col++;
      if (col >= numPositions) {
        col = 0;
        row++;
      }
    }
    return features;
  }

  /// 6. LOGICAL COMBINATION - AND / OR / XOR
  /// Ported from the relation family common to PGM (Barrett et al.) and
  /// Sandia's LogicalAND/OR/XORSGMStructureFeature: a boolean attribute is
  /// evaluated on a "key" marker and a "candidate" shape, and a small
  /// accent dot renders the result of AND / OR / XOR on those two booleans:
  ///   AND: dot present iff key AND candidate are both "dark"
  ///   OR:  dot present iff key OR candidate is "dark"
  ///   XOR: dot present iff exactly one of key/candidate is "dark"
  /// All 4 options walk through the 4 possible (key, candidate) truth
  /// combinations so the rule is inferable from the majority; 1 option's
  /// dot violates the chosen operator's truth table.
  ///
  /// BUGFIX: the original version encoded each boolean as membership in an
  /// arbitrary, invented shape-type category ({ellipse, diamond} = "true").
  /// That category has no perceptual basis - nothing in the image tells a
  /// solver which shapes are grouped together, so the rule was only
  /// correct in code, never inferable by looking at the picture. Both
  /// booleans are now encoded as fill darkness (dark vs light), which is
  /// immediately visible and needs no hidden lookup table. Shape *type* is
  /// now fixed per role (key is always one shape, candidate always
  /// another) purely for visual variety and carries no rule meaning.
  static const List<String> _darkFills = ['black', 'grey40'];
  static const List<String> _lightFills = ['white', 'grey75'];

  static bool _applyLogic(String op, bool a, bool b) {
    switch (op) {
      case 'and':
        return a && b;
      case 'or':
        return a || b;
      default: // xor
        return a != b;
    }
  }

  // RETIRED - not called from _generateHardOddMan's subTypes list. See the
  // note where it used to be registered, above.
  // ignore: unused_element
  static ReasoningQuestion _oddManLogicalCombination() {
    final op = ['and', 'or', 'xor'][_r.nextInt(3)];
    final oddIndex = _r.nextInt(4);
    final rotations = [0, 90, 180, 270]..shuffle(_r);
    final keyShape = _randomShape();
    final candidateShape = _randomShape([keyShape]);

    // Walk through all 4 (keyVal, candVal) truth combinations, one per
    // option, so the operator's behavior is fully demonstrated.
    final combos = [
      [true, true],
      [true, false],
      [false, true],
      [false, false],
    ]..shuffle(_r);

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final keyVal = combos[i][0];
      final candVal = combos[i][1];
      final keyFill = keyVal ? _darkFills[_r.nextInt(_darkFills.length)] : _lightFills[_r.nextInt(_lightFills.length)];
      final candidateFill = candVal ? _darkFills[_r.nextInt(_darkFills.length)] : _lightFills[_r.nextInt(_lightFills.length)];

      final correctDotPresent = _applyLogic(op, keyVal, candVal);
      final dotPresent = (i == oddIndex) ? !correctDotPresent : correctDotPresent;

      final features = <Map<String, dynamic>>[
        _feature(keyShape, w: 0.3, h: 0.3, cx: 0.22, cy: 0.22, fill: keyFill),
        _feature(candidateShape, w: 0.56, h: 0.56, rot: rotations[i], cx: 0.5, cy: 0.6, fill: candidateFill),
      ];
      if (dotPresent) {
        // BUGFIX: this used to sit at (0.85, 0.85), right at the edge of
        // (and for some shape/rotation combos, overlapping) the candidate
        // shape's own bounding area - when both were dark-filled, the dot
        // visually merged into the candidate and "present vs absent"
        // became a coin flip. The top-right corner stays clear of both the
        // key marker (top-left) and the candidate (center/bottom), so the
        // dot is unambiguous regardless of what shape or rotation the
        // candidate has.
        features.add(_feature('ellipse', w: 0.12, h: 0.12, cx: 0.87, cy: 0.15, fill: 'black'));
      }

      options.add(_cell(features, gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_logical_$op',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 7. ARITHMETIC (PGM "Arithmetic" relation; SRAN Fig.1's Arithmetic
  /// progression rule; RAVEN's number attribute)
  /// Three stacked rows of dots per option: row A has `a` dots, row B has
  /// `b` dots, row C has `c` dots. The rule is c = a + b.
  /// - 3 majority: c == a + b (a, b vary freely per option)
  /// - 1 odd: c is off by +-1 from the correct sum
  /// BUGFIX: dot spacing is cx = (i+1)/(count+1), so with counts up to 6-7
  /// (a,b were each 1-3, c = a+b could reach 6, or 7 for the odd option)
  /// the gap between adjacent dot centers shrank to ~0.14 while each dot
  /// was 0.13 wide - they nearly touched and the row read as one solid
  /// dark blob instead of countable individual dots, making the whole
  /// point of the rule (comparing counts) impossible to do by eye. a and b
  /// are now capped at 1-2 (max row count 4, or 5 for the odd option),
  /// and dots are drawn smaller, so every row stays clearly countable.
  static List<Map<String, dynamic>> _dotRow(int count, double cy, String fill) {
    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      final cx = (i + 1) / (count + 1);
      features.add(_feature('ellipse', w: 0.1, h: 0.1, cx: cx, cy: cy, fill: fill));
    }
    return features;
  }

  /// BUGFIX (round 2): even with countable dots, rows B and C sit right
  /// next to each other (cy 0.5 / 0.78) and both use fairly dark fills
  /// (grey40 / black) - close enough in shade that the two rows visually
  /// read as one merged block, so a solver can't tell where "row B" ends
  /// and "row C" begins, which makes verifying c = a + b impossible even
  /// though every individual dot is countable. Two thin divider bars now
  /// explicitly split the cell into 3 bands, so the row grouping is a
  /// structural fact of the layout, not something that depends on the
  /// fills being different enough to tell apart.
  static Map<String, dynamic> _rowDivider(double cy) =>
      _feature('rectangle', w: 0.86, h: 0.02, cx: 0.5, cy: cy, fill: 'grey10');

  static ReasoningQuestion _oddManArithmetic() {
    final oddIndex = _r.nextInt(4);
    final fillA = 'grey75';
    final fillB = 'grey40';
    final fillC = 'black';

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final a = 1 + _r.nextInt(2); // 1-2
      final b = 1 + _r.nextInt(2); // 1-2
      int c = a + b;
      if (i == oddIndex) {
        final delta = _r.nextBool() ? 1 : -1;
        c = max(1, c + delta);
        if (c == a + b) c += 1; // guarantee an actual violation
      }

      final features = <Map<String, dynamic>>[
        ..._dotRow(a, 0.2, fillA),
        _rowDivider(0.36),
        ..._dotRow(b, 0.52, fillB),
        _rowDivider(0.68),
        ..._dotRow(c, 0.84, fillC),
      ];
      options.add(_cell(features, gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_arithmetic',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  /// 8. CONSTANT ATTRIBUTE (RAVEN's "Constant" rule - the fill of an
  /// attribute stays fixed while everything else is free to vary)
  /// A single shape (same type across all 4 options) draws its fill from
  /// the tight palette. 3 majority options all get the SAME fill; 1 odd
  /// option gets a different one.
  ///
  /// BUGFIX (replaces "Consistent Union"): the previous version made the
  /// odd option DUPLICATE one of the majority fills, on the theory that 3
  /// distinct + 1 repeat mirrors RAVEN's Distribute-Three rule. In a
  /// single-answer, 4-option format this backfires: it produces two
  /// options with the exact same fill, and there is no way for a solver to
  /// tell which of that identical-looking PAIR is "the" odd one - both look
  /// equally anomalous. Flipping it to 3-identical/1-different removes the
  /// ambiguity entirely: there is exactly one option that looks different,
  /// full stop.
  ///
  /// BUGFIX (rotation): rotation is now fixed to a single value shared by
  /// all 4 options, chosen once per question, instead of being randomized
  /// per option. Shapes like trapezoid/tee/diamond are highly asymmetric,
  /// so randomizing their rotation "just for visual variety" was producing
  /// four wildly different-looking silhouettes and made it look like the
  /// shape TYPE was changing between options - pure noise that had nothing
  /// to do with the actual rule (fill) and swamped it.
  ///
  /// ANTI-SHORTCUT: fill used to be the ONLY thing that varied between
  /// options, which makes this rule solvable by pure visual salience -
  /// "glance for whichever one looks different" - without ever consciously
  /// registering that fill specifically is the relevant attribute. Size now
  /// varies independently and randomly for every option (no 3-vs-1
  /// structure to it, unlike fill), so there are two things different
  /// about each option and only one of them is actually the rule. A solver
  /// has to notice WHICH attribute is the constant one instead of just
  /// picking whatever looks most different overall.
  /// Farthest-luminance fill from [from] in _fillCycle, rather than merely
  /// "a different one" - picking any random different shade let the odd
  /// option land on an adjacent pair (grey10 vs black, or white vs grey40),
  /// which on a small shape like a diamond can render as visually
  /// indistinguishable from the majority even though the values are
  /// technically different. Maximizing contrast instead guarantees the
  /// one attribute this rule actually depends on is always perceivable.
  static String _maxContrastFill(String from) {
    const luminance = {'white': 255, 'grey40': 179, 'grey10': 117, 'black': 64};
    final fromLum = luminance[from]!;
    return _fillCycle.reduce((a, b) => (luminance[a]! - fromLum).abs() >= (luminance[b]! - fromLum).abs() ? a : b);
  }

  // RETIRED from Hard Mode - see the note in _generateHardOddMan's subTypes.
  // Kept for a future easy/medium tier.
  // ignore: unused_element
  static ReasoningQuestion _oddManConstantAttribute() {
    final shape = _randomShape();
    final oddIndex = _r.nextInt(4);
    final rotation = [0, 90, 180, 270][_r.nextInt(4)];

    final majorityFill = _fillCycle[_r.nextInt(_fillCycle.length)];
    final oddFill = _maxContrastFill(majorityFill);

    // Evenly-spaced, all-distinct SCALE FACTORS rather than independent
    // random draws: 4 random floats in a narrow range can coincidentally
    // cluster (3 similar + 1 outlier), which would create a second,
    // spurious "odd one out by size" pattern that might contradict or
    // accidentally line up with the real fill-based answer. A fixed,
    // evenly-spaced set guarantees size reads as "different for everyone"
    // - genuine noise, not a competing signal. Applied on top of a
    // randomized non-square base aspect (ported from
    // SGMSurfaceFeatureGenerator) so the shape's own proportions vary too.
    final baseDims = _sgmRandomDims();
    final scaleFactors = [0.62, 0.68, 0.74, 0.8]..shuffle(_r);

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final fill = (i == oddIndex) ? oddFill : majorityFill;
      options.add(_cell([
        _feature(shape, w: baseDims[0] * scaleFactors[i], h: baseDims[1] * scaleFactors[i], rot: rotation, fill: fill),
      ], gridBox: true));
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_constant_attribute',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  // ===========================================================================
  // 1b. HARD FIGURE MATCH
  //
  // Same puzzle contract as the existing easy-mode _figureMatch() in
  // question_generator.dart: {'type': 'figure_match', 'target': <cell>} plus
  // 4 options, one of which is the true match. Rendered via 'sandia_cell' /
  // SandiaWidget (same pipeline as odd_man and pattern) rather than the
  // older EnhancedFigurePainter vocabulary, for the same reasons hard mode
  // uses it elsewhere: continuous shape proportions, a wider fill palette,
  // and the shape/rendering infrastructure already built and tested.
  //
  // DESIGN NOTE - why there are corner markers at all: a genuine "spot the
  // exact match" question needs a mirror trap (an option that LOOKS like a
  // valid rotation of the target but is actually a reflection of it - not
  // reachable by rotation alone). None of the 6 shapes in this vocabulary
  // are individually chiral (triangle, tee, and trapezoid are all built
  // left-right symmetric), so mirroring the main shape alone changes
  // nothing visible - the trap would be undetectable, not just hard. Small
  // markers at two corners of the figure make the WHOLE composition
  // asymmetric, which is what actually makes a mirror distinguishable from
  // a rotation.
  //
  // BUGFIX: a single circular marker used to sit only 0.26 from center,
  // which overlapped the shapes' own silhouettes once two overlaid shapes
  // (up to ~1.0 wide) were introduced - it read as messy, sitting on top
  // of shape edges instead of clearly next to them. Markers are pushed out
  // to 0.37 now, and the main shapes are sized to leave room for that.
  // Also swapped the plain circle for two differently-shaped markers (a
  // small triangle and a small square) - both because a bare dot read as
  // visual noise rather than a deliberate reference point, and because two
  // independent markers (a solver has to check both corners, and a
  // distractor might only get ONE of them wrong) is real added difficulty
  // rather than the same one check with worse contrast.
  // ===========================================================================

  static const List<List<double>> _cornerOffsets = [
    [-0.37, -0.37], // TL
    [0.37, -0.37], // TR
    [0.37, 0.37], // BR
    [-0.37, 0.37], // BL
  ];

  static int _mirrorCorner(int c) => const [1, 0, 3, 2][c];
  static int _rotateCorner(int c, int rotDeg) => (c + (rotDeg ~/ 90)) % 4;

  /// BUGFIX: the marker's POSITION was correctly rotated (via _rotateCorner
  /// above), but the marker's own SHAPE was always drawn at rot:0 - so as
  /// the figure rotated, the triangle marker moved to the right corner but
  /// kept pointing the same fixed direction instead of turning with the
  /// rest of the figure. Invisible on the square marker (a square looks
  /// identical at every 90-degree turn) but obviously wrong on the
  /// triangle, which is exactly what was being reported. The marker now
  /// rotates by the same `rot` as the main shapes. No special handling
  /// needed for `mirror` here specifically - the triangle is itself
  /// left-right symmetric (same reason it can't carry a mirror trap on its
  /// own), so a mirrored-then-rotated triangle looks identical to a
  /// plain rotated one; only its corner position (already handled above)
  /// carries the mirror information.
  static Map<String, dynamic> _markerFeature(String shape, int cornerIndex, int rot, bool mirror) {
    final cc = mirror ? _mirrorCorner(cornerIndex) : cornerIndex;
    return _markerAt(shape, _rotateCorner(cc, rot), rot);
  }

  /// A marker at an explicit (already rotated) corner. BUGFIX: the
  /// distractor override path used to build its square marker inline at
  /// 0.13 instead of the 0.16 every other option uses - so the one
  /// distractor with a misplaced square ALSO had a visibly smaller square,
  /// a tell that let a solver eliminate it without any rotation reasoning.
  /// Every marker now goes through here, so all options share one size.
  static Map<String, dynamic> _markerAt(String shape, int finalCorner, int rot) {
    final off = _cornerOffsets[finalCorner];
    return _feature(shape, w: 0.16, h: 0.16, rot: rot, cx: 0.5 + off[0], cy: 0.5 + off[1], fill: 'black');
  }

  static Map<String, dynamic> _figureMatchCell({
    required String outerShape,
    required String innerShape,
    required double outerW,
    required double outerH,
    required double innerW,
    required double innerH,
    required String outerFill,
    required String innerFill,
    required int rot,
    required int markerACorner,
    required int markerBCorner,
    required bool mirror,
    int? overrideMarkerACorner,
    int? overrideMarkerBCorner,
  }) {
    return _cell([
      _feature(outerShape, w: outerW, h: outerH, rot: rot, fill: outerFill),
      _feature(innerShape, w: innerW, h: innerH, rot: rot, fill: innerFill),
      overrideMarkerACorner != null
          ? _markerAt('triangle', overrideMarkerACorner, rot)
          : _markerFeature('triangle', markerACorner, rot, mirror),
      overrideMarkerBCorner != null
          ? _markerAt('rectangle', overrideMarkerBCorner, rot)
          : _markerFeature('rectangle', markerBCorner, rot, mirror),
    ], gridBox: true);
  }

  /// ANTI-SHORTCUT / complexity: two independently-checkable overlaid
  /// shapes (concentric, like the ChangeFillPattern/ScalingRepetition
  /// nesting elsewhere) plus two independently-checkable corner markers -
  /// a solver has to verify outer shape, inner shape, outer fill, inner
  /// fill, rotation, AND both markers, all at once. Difficulty comes from
  /// there being more to check, not from any individual difference being
  /// harder to SEE.
  static ReasoningQuestion _generateHardFigureMatch() {
    final outerShape = _randomShape();
    final innerShape = _randomShape([outerShape]);
    final dims = _sgmRandomDims();
    final outerW = dims[0] * 0.92;
    final outerH = dims[1] * 0.92;
    final innerW = max(outerW * 0.5, 0.15);
    final innerH = max(outerH * 0.5, 0.15);
    final outerFill = _fillCycle[_r.nextInt(_fillCycle.length)];
    final innerFill = (_fillCycle.where((f) => f != outerFill).toList()..shuffle(_r)).first;
    final markerACorner = _r.nextInt(4);
    final markerBCorner = ([0, 1, 2, 3]..remove(markerACorner))[_r.nextInt(3)];
    final targetRot = [0, 90, 180, 270][_r.nextInt(4)];

    Map<String, dynamic> build({
      required int rot,
      required bool mirror,
      String? oShape,
      String? iShape,
      String? oFill,
      String? iFill,
      int? overrideMarkerACorner,
      int? overrideMarkerBCorner,
    }) =>
        _figureMatchCell(
          outerShape: oShape ?? outerShape,
          innerShape: iShape ?? innerShape,
          outerW: outerW, outerH: outerH, innerW: innerW, innerH: innerH,
          outerFill: oFill ?? outerFill, innerFill: iFill ?? innerFill,
          rot: rot, markerACorner: markerACorner, markerBCorner: markerBCorner, mirror: mirror,
          overrideMarkerACorner: overrideMarkerACorner, overrideMarkerBCorner: overrideMarkerBCorner,
        );

    final target = build(rot: targetRot, mirror: false);

    // Correct answer: the SAME figure (same two shapes, same two fills,
    // same two corner markers), shown at a rotation different from the
    // target's own. This is the whole point of the exercise - recognizing
    // that two different-looking orientations are the same rigid figure,
    // not matching pixels directly.
    final correctRot = ([0, 90, 180, 270]..remove(targetRot))[_r.nextInt(3)];
    final correct = build(rot: correctRot, mirror: false);

    // ANTI-SHORTCUT: fillOuter/fillInner/shapeOuter/shapeInner are all
    // rotation-invariant - you can spot a wrong fill or wrong shape type
    // with a direct glance, no rotation reasoning required at all. When
    // those kinds got drawn, a solver could eliminate 3 options via plain
    // attribute-matching and never engage with the actual point of the
    // question. Distractors are now always exactly these 3 - the ones
    // that genuinely require figuring out what the target looks like
    // after rotating it, not just scanning for a mismatched color.
    final kinds = ['mirror', 'markerA', 'markerB']..shuffle(_r);
    final distractors = <Map<String, dynamic>>[];
    for (final kind in kinds.take(3)) {
      final rot = [0, 90, 180, 270][_r.nextInt(4)];
      switch (kind) {
        case 'mirror':
        // The chirality trap: identical figure, but reflected. Looks
        // like it could be a rotation at a glance - isn't one.
          distractors.add(build(rot: rot, mirror: true));
          break;
        case 'markerA':
        // Right shapes, right fills, right rotation, marker B correct -
        // but marker A sits somewhere no rotation of the target could
        // put it. Only ONE of the two markers is wrong.
          // BUGFIX: the wrong corner used to be allowed to land on marker
          // B's corner, stacking both markers in one spot - messy, and with
          // a centrally symmetric main shape two such distractors could
          // render almost identically. Exclude the other marker's corner.
          final correctA = _rotateCorner(markerACorner, rot);
          final wrongA = ([0, 1, 2, 3]..remove(correctA)..remove(_rotateCorner(markerBCorner, rot)))[_r.nextInt(2)];
          distractors.add(build(rot: rot, mirror: false, overrideMarkerACorner: wrongA));
          break;
        case 'markerB':
        default:
          final correctB = _rotateCorner(markerBCorner, rot);
          final wrongB = ([0, 1, 2, 3]..remove(correctB)..remove(_rotateCorner(markerACorner, rot)))[_r.nextInt(2)];
          distractors.add(build(rot: rot, mirror: false, overrideMarkerBCorner: wrongB));
          break;
      }
    }

    final correctIndex = _r.nextInt(4);
    final options = <Map<String, dynamic>>[...distractors];
    options.insert(correctIndex, correct);

    return ReasoningQuestion(
      category: 'figure_match',
      type: 'figure_match_hard',
      puzzle: {'type': 'figure_match', 'target': target},
      options: options,
      correctIndex: correctIndex,
    );
  }

  // ===========================================================================
  // 2. FULL SANDIA MATRIX ENGINE (PATTERN COMPLETION)
  //
  // A genuine port of the composable grammar from SGMLayer.java / the
  // structure/base and structure/supplemental packages, not the earlier
  // single hard-coded 3-layer template. Per question:
  //   - 1 or 2 LAYERS (mirrors the tool's "One Layer / Two Layers" choice)
  //   - each layer picks a BASE STRUCTURE FEATURE (Shape Repetition, or
  //     Logical AND/OR/XOR) + a LOCATION TRANSFORM (Horizontal, Vertical,
  //     Diagonal x2, Top-Left-Corner-Out)
  //   - a Shape-Repetition layer can additionally chain up to 3
  //     SUPPLEMENTAL FEATURES (Apply Rotation, Apply Scaling, Fill Pattern
  //     Repetition, Change Fill Pattern, Translational Numerosity), each
  //     with its OWN independently-chosen location transform, exactly as
  //     the real tool allows.
  //
  // SIMPLIFICATIONS (documented, not hidden): the real tool's diagonal and
  // corner-out transforms use a wrap-around chain purely as an internal
  // bookkeeping trick; this port uses plain, human-legible diagonal bands
  // and concentric corner rings instead, which express the same
  // "constant/progressing along this axis" idea without requiring a solver
  // to track an invisible wrap. Logical AND/OR/XOR layers don't carry
  // supplemental features - true to the source (a Logic-based base feature
  // uses a special derivation, not the normal chain-walk supplementals
  // hook into), and combinatorially it stays legible in a 3x3 grid.
  // ===========================================================================

  // ---- location transforms -------------------------------------------------

  /// How far along this transform's axis cell (r,c) sits. Used by
  /// supplemental features to compute a cumulative amount (index * step).
  static int _sgmIndex(String transform, int r, int c) {
    switch (transform) {
      case 'vertical':
        return r;
      case 'diagTLBR':
        return r; // monotonic within its "\" band, see _sgmChain
      case 'diagBLTR':
        return r; // monotonic within its "/" band
      case 'cornerOut':
        return max(r, c);
      case 'horizontal':
      default:
        return c;
    }
  }

  /// Which independent chain cell (r,c) belongs to. Shape Repetition seeds
  /// ONE random shape per chain (e.g. Horizontal -> one shape per ROW,
  /// Vertical -> one shape per COLUMN, diagonal -> one shape per diagonal
  /// band, cornerOut -> a single chain covering the whole layer).
  static int _sgmChain(String transform, int r, int c) {
    switch (transform) {
      case 'vertical':
        return c;
      case 'diagTLBR':
        return r - c; // -2..2, five "\" diagonals
      case 'diagBLTR':
        return r + c; // 0..4, five "/" diagonals
      case 'cornerOut':
        return 0; // single chain
      case 'horizontal':
      default:
        return r;
    }
  }

  static const List<String> _sgmTransforms = ['horizontal', 'vertical', 'diagTLBR', 'diagBLTR', 'cornerOut'];

  /// Faithful port of SGMSurfaceFeatureGenerator's width/height
  /// randomization. Width and height are independently drawn from
  /// {1/4, 1/2, 3/4} of the cell, with a rule that guarantees they're never
  /// equal ("disallow width=height (squares, circles...)" - straight from
  /// the Java comment) and a coin-flip on which axis ends up bigger. This
  /// is a big part of why the real tool's shapes never look quite the same
  /// twice even when the shape TYPE repeats - proportions vary too, not
  /// just size/rotation/fill. Previously every shape in this port was
  /// rendered at a fixed square aspect, which is a real source of the
  /// "same shapes every time" feeling - a diamond always looked like the
  /// exact same diamond.
  static List<double> _sgmRandomDims() {
    const q = 0.25;
    double width = _r.nextInt(3) * q + q; // 0.25, 0.5, or 0.75
    double height;
    if (width == 2 * q) {
      height = 3 * q;
    } else if (width == 3 * q) {
      height = 2 * q;
    } else {
      height = _r.nextInt(2) * q + 2 * q; // 0.5 or 0.75
    }
    if (_r.nextBool()) {
      final t = width;
      width = height;
      height = t;
    }
    return [width, height];
  }

  // ---- per-cell attribute bundle --------------------------------------------

  static Map<String, dynamic> _sgmCellAttrs({
    String shape = 'ellipse',
    double w = 0.6,
    double h = 0.75,
    double rot = 0,
    double scale = 1.0,
    String fill = 'white',
    int count = 1,
    Set<String>? logicShapes,
  }) =>
      {'shape': shape, 'w': w, 'h': h, 'rot': rot, 'scale': scale, 'fill': fill, 'count': count, 'logicShapes': logicShapes};

  static Map<String, dynamic> _sgmCopy(Map<String, dynamic> a) => {
    ...a,
    'logicShapes': a['logicShapes'] == null ? null : Set<String>.from(a['logicShapes'] as Set<String>),
  };

  // ---- layer construction ----------------------------------------------------

  /// Builds one layer's full 3x3 grid of attribute bundles by applying its
  /// base structure feature, then chaining any supplemental features - the
  /// same "process the whole grid once per structure feature, in order"
  /// pipeline SGMLayer.java uses.
  static List<List<Map<String, dynamic>>> _sgmBuildLayer({
    required bool isLogic,
    required String baseTransform,
    required String logicOp, // 'and' | 'or' | 'xor', only used if isLogic
    required List<Map<String, String>> supplements, // [{'type':..,'transform':..}, ...]
  }) {
    final grid = List.generate(3, (_) => List.generate(3, (_) => _sgmCellAttrs()));

    if (isLogic) {
      _sgmApplyLogicBase(grid, logicOp);
      return grid; // logic layers carry no supplemental features
    }

    _sgmApplyShapeRepetitionBase(grid, baseTransform);
    for (final supp in supplements) {
      _sgmApplySupplemental(grid, supp['type']!, supp['transform']!);
    }
    return grid;
  }

  /// Shape Repetition: one independently-randomized {shape, dims, fill} per
  /// chain, held identical across every cell in that chain.
  static void _sgmApplyShapeRepetitionBase(List<List<Map<String, dynamic>>> grid, String transform) {
    final chainSeed = <int, Map<String, dynamic>>{};
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final chain = _sgmChain(transform, r, c);
        final seed = chainSeed.putIfAbsent(chain, () {
          final dims = _sgmRandomDims();
          // Must draw from _fillCycle, not _basicFillPool: this seed fill
          // can become the anchor for a chained 'changeFill' supplemental
          // (SandiaFillCompat.next steps through _fillCycle only), and
          // _basicFillPool's 'grey75' isn't a member of that cycle -
          // indexOf returns -1 and next() silently resets to 'white'
          // instead of stepping one shade darker. Since which supplements
          // get picked happens after this seed is chosen, there's no safe
          // way to know in advance whether this fill will stay purely
          // cosmetic - always seed from the cycle it might need to step
          // through.
          return _sgmCellAttrs(
              shape: _randomShape(), w: dims[0], h: dims[1], fill: _fillCycle[_r.nextInt(_fillCycle.length)]);
        });
        grid[r][c] = _sgmCopy(seed);
      }
    }
  }

  /// Logical AND/OR/XOR: exact port of SGMLayer's special-case derivation -
  /// the top-left 2x2 gets independent random subset membership from a
  /// shared pool, row 0 and row 1's third column is derived by combining
  /// that row's first two cells, then row 2 is derived by combining rows 0
  /// and 1 column-by-column.
  ///
  /// Corrected against the actual Java source (BaseSGMStructureFeatureGenerator
  /// + AbstractLogicOperationSGMStructureFeature + SGMSurfaceFeatureGenerator):
  /// the pool is 3-5 distinct shapes (not 2), every surface feature is always
  /// generated dead-center of the cell with no positional offset anywhere in
  /// the source, and logic-operation shapes are restricted to WHITE fill only
  /// (allowedFillPatterns = [WhiteSGMFillPattern] in the generator) - i.e.
  /// outline-only. So a cell showing multiple pool members renders them all
  /// centered on the same point, each its own fixed size, nesting as visible
  /// concentric outlines - never side-by-side, never filled. Each base
  /// location gets a random SUBSET of the pool (any size, including several
  /// at once), not a single yes/no per shape.
  /// Dims for logic-layer pool members specifically. _sgmRandomDims can
  /// return ratios as extreme as 1:3 (e.g. 0.25 x 0.75), which is fine
  /// where fill/rotation give extra disambiguating cues - but logic-layer
  /// shapes render outline-only (white fill, per the authentic Sandia
  /// design) and are never rotated, so silhouette is the ONLY thing
  /// telling two pool members apart. At an extreme ratio, 'trapezoid's
  /// top edge (quarterW = halfW/2) shrinks toward a point, and it starts
  /// reading as 'triangle' or a narrow 'diamond' rather than itself -
  /// exactly the "which shape is this supposed to be" confusion reported
  /// against real logic-layer questions. Kept close enough to square that
  /// every shape in the pool stays recognizably itself.
  static List<double> _sgmLogicShapeDims() {
    const options = [0.55, 0.65, 0.75];
    return [options[_r.nextInt(options.length)], options[_r.nextInt(options.length)]];
  }

  static void _sgmApplyLogicBase(List<List<Map<String, dynamic>>> grid, String op) {
    // OR only ever grows set membership (unlike AND/XOR, which shrink or
    // toggle), so a wide pool makes the overcrowding guard below much
    // harder to satisfy within its retry budget - capping OR to the low
    // end of the authentic 3-5 range keeps the guard actually effective
    // instead of frequently exhausting its attempts and returning the
    // same overcrowded result anyway.
    final poolSize = op == 'or' ? 3 : _r.nextInt(3) + 3; // 3-5, matches MIN/MAX_SURFACE_FEATURES_FOR_LOGIC_OPERATION
    final shapesUsed = <String>{};
    final pool = <String>[];
    while (pool.length < poolSize) {
      final shape = _randomShape();
      if (shapesUsed.contains(shape)) continue; // Java: unique shapes per pool
      shapesUsed.add(shape);
      final dims = _sgmLogicShapeDims();
      // Encode as a self-describing id ("shape:w:h") so the final cell sets
      // carry everything render needs without a separate id->shape map.
      pool.add('$shape:${dims[0]}:${dims[1]}');
    }

    Set<String> combine(Set<String> a, Set<String> b) {
      switch (op) {
        case 'and':
          return a.intersection(b);
        case 'or':
          return a.union(b);
        default: // xor
          final result = <String>{};
          for (final s in {...a, ...b}) {
            if (a.contains(s) != b.contains(s)) result.add(s);
          }
          return result;
      }
    }

    // Port of AbstractLogicOperationSGMStructureFeature's assignment loop:
    // randomly assign pool members to each of the 4 base locations (any
    // subset size, zero allowed mid-loop) until every pool member has been
    // used somewhere AND every location ended up non-empty. Capped for
    // Dart's sake (Java's loop has no cap either, but this converges in a
    // handful of tries for pool sizes 3-5 over 4 locations; the fallback
    // guarantees termination without ever violating either constraint).
    List<List<Set<String>>> base;
    int attempts = 0;
    do {
      base = List.generate(2, (_) => List.generate(2, (_) => <String>{}));
      for (final id in pool) {
        final loc = _r.nextInt(4);
        base[loc ~/ 2][loc % 2].add(id);
      }
      attempts++;
    } while (attempts < 50 &&
        (base[0][0].isEmpty ||
            base[0][1].isEmpty ||
            base[1][0].isEmpty ||
            base[1][1].isEmpty ||
            !pool.every((id) => base[0][0].contains(id) || base[0][1].contains(id) || base[1][0].contains(id) || base[1][1].contains(id))));
    if (attempts >= 50) {
      // Deterministic fallback: round-robin the pool across the 4
      // locations so every constraint holds even if random assignment
      // kept missing it.
      base = List.generate(2, (_) => List.generate(2, (_) => <String>{}));
      for (int i = 0; i < pool.length; i++) {
        base[i % 2][(i ~/ 2) % 2].add(pool[i]);
      }
      // Guarantee every location non-empty by also seeding it with a
      // random pool member if the round-robin left any empty.
      for (int loc = 0; loc < 4; loc++) {
        if (base[loc ~/ 2][loc % 2].isEmpty) base[loc ~/ 2][loc % 2].add(pool[_r.nextInt(pool.length)]);
      }
    }

    final sets = List.generate(3, (_) => List<Set<String>>.filled(3, {}));
    sets[0][0] = base[0][0];
    sets[0][1] = base[0][1];
    sets[1][0] = base[1][0];
    sets[1][1] = base[1][1];
    sets[0][2] = combine(sets[0][0], sets[0][1]);
    sets[1][2] = combine(sets[1][0], sets[1][1]);
    for (int c = 0; c < 3; c++) {
      sets[2][c] = combine(sets[0][c], sets[1][c]);
    }

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        grid[r][c] = _sgmCellAttrs(logicShapes: sets[r][c]);
      }
    }
  }

  /// Applies one supplemental feature across the whole grid using ITS OWN
  /// location transform (which may differ from the base's). Walks each
  /// chain in index order; the first cell in a chain is the anchor
  /// (attribute left as-is), each following cell = previous cell's value
  /// in this chain + one step. Every other attribute is preserved from
  /// whatever the grid already held at that cell.
  static void _sgmApplySupplemental(List<List<Map<String, dynamic>>> grid, String type, String transform) {
    final chains = <int, List<List<int>>>{};
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        chains.putIfAbsent(_sgmChain(transform, r, c), () => []).add([r, c]);
      }
    }

    for (final cells in chains.values) {
      cells.sort((a, b) => _sgmIndex(transform, a[0], a[1]).compareTo(_sgmIndex(transform, b[0], b[1])));
      Map<String, dynamic>? previous;
      for (final rc in cells) {
        final r = rc[0], c = rc[1];
        final current = grid[r][c];
        if (previous == null) {
          previous = current; // anchor: unchanged
        } else {
          final next = _sgmCopy(current);
          switch (type) {
            case 'rotation':
              next['rot'] = ((previous['rot'] as double) + 45) % 360;
              break;
            case 'scaling':
            // BUGFIX: uncapped, this compounds every step along the
            // chain. Most transforms only chain 2-3 cells deep, but a
            // transform like cornerOut can put all 8 non-anchor cells in
            // one chain - eight compounding x0.66 steps shrinks a shape
            // to under 5% of its size well before the missing cell, at
            // which point every answer option renders as the same
            // barely-visible speck no matter what actually differs
            // between them. Floor it so it always stays legible.
            // Floor recalculated against the actual minimum base size:
            // _sgmRandomDims' smallest tier is 0.25, so the floor must
            // clear 0.12/0.25 = 0.48 to guarantee legibility regardless
            // of which base size this chain started from - 0.42 (last
            // round's floor) was picked to stop catastrophic shrink but
            // was never checked against that minimum, so it could still
            // land under the legibility threshold on its own with no
            // further compounding needed (0.25 x 0.42 = 0.105).
              next['scale'] = max(0.55, (previous['scale'] as double) * 0.66);
              break;
            case 'fillRepetition':
              next['fill'] = previous['fill'];
              break;
            case 'changeFill':
              next['fill'] = SandiaFillCompat.next(previous['fill'] as String);
              break;
            case 'numerosity':
              next['count'] = min(4, (previous['count'] as int) + 1);
              break;
          }
          grid[r][c] = next;
          previous = next;
        }
      }
    }
  }

  // ---- rendering + question assembly -----------------------------------------

  static List<Map<String, dynamic>> _sgmAttrsToFeatures(Map<String, dynamic> attrs) {
    if (attrs['logicShapes'] != null) {
      // Port of SGMSurfaceFeatureGenerator: every surface feature is always
      // generated dead-center of the cell (SGMPoint(halfSize, halfSize)) -
      // there's no positional offset logic anywhere in the source. Logic
      // operations additionally restrict shapes to WHITE fill only
      // (allowedFillPatterns.add(new WhiteSGMFillPattern()) in
      // BaseSGMStructureFeatureGenerator), i.e. outline-only, so several
      // shapes in one cell nest as visible concentric outlines rather than
      // needing an offset or a solid fill to stay distinguishable - each
      // pool member's own fixed size (encoded in its id) is what keeps them
      // tellable apart, exactly like the real tool.
      final ids = (attrs['logicShapes'] as Set<String>).toList()..sort();
      return [
        for (final id in ids)
              () {
            final parts = id.split(':');
            return _feature(parts[0], w: double.parse(parts[1]), h: double.parse(parts[2]), fill: 'white');
          }(),
      ];
    }
    final count = attrs['count'] as int;
    if (count > 1) {
      return _numerosityFeatures(attrs['shape'] as String, attrs['fill'] as String, count,
          extraScale: attrs['scale'] as double, rot: (attrs['rot'] as double).round());
    }
    return [
      _feature(attrs['shape'] as String,
          w: attrs['w'] as double,
          h: attrs['h'] as double,
          rot: (attrs['rot'] as double).round(),
          scale: attrs['scale'] as double,
          fill: attrs['fill'] as String),
    ];
  }

  /// True if either of the two OTHER visible cells sharing the held-out
  /// cell's row (2,0 & 2,1) - or column (0,2 & 1,2) - are visually
  /// identical to each other. When that happens the missing cell is
  /// guessable directly from those two matching neighbours (e.g. "both
  /// other cells in this row are blank, so the third must be too") without
  /// ever engaging the actual rule - most commonly hit by a logic layer
  /// whose AND of two disjoint single-shape seeds produces an empty set at
  /// more than one spot, blanking out a whole row or column.
  static bool _sgmHasRowColGiveaway(List<List<Map<String, dynamic>>> grid) {
    final rowMatch = _sgmAttrsVisibleKey(grid[2][0]) == _sgmAttrsVisibleKey(grid[2][1]);
    final colMatch = _sgmAttrsVisibleKey(grid[0][2]) == _sgmAttrsVisibleKey(grid[1][2]);
    return rowMatch || colMatch;
  }

  /// True if any cell in a logic-layer grid ends up with more than 3
  /// shapes simultaneously centered on top of each other. Unlike AND
  /// (shrinks toward empty) or XOR (toggles membership), OR only ever
  /// grows a set - and a derived cell combines two already-unioned rows,
  /// so it can end up rendering most or all of the pool stacked on one
  /// point. That's mathematically correct and visually unreadable at the
  /// same time (reported directly: "too many shapes clamped together,
  /// can't even compare them") - caps it the same way giveaway rows are
  /// rejected, as a generation-time guard rather than a rendering patch.
  static bool _sgmHasOvercrowdedLogicCell(List<List<Map<String, dynamic>>> grid) {
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final shapes = grid[r][c]['logicShapes'];
        if (shapes is Set && shapes.length > 3) return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> _sgmCellAt(List<List<List<Map<String, dynamic>>>> layerGrids, int r, int c) {
    final layers = <Map<String, dynamic>>[];
    // Two overlapping layers used to need a size-ordering hack and a
    // same-fill-swap hack to stay legible, because fills were rendered
    // fully opaque. Both are gone now that SandiaFill renders the
    // original tool's real semi-transparent alpha (see its doc comment):
    // a later layer drawn on top no longer blots out an earlier one, and
    // two layers that happen to share a fill still show a visibly darker
    // overlap where they intersect, since alpha genuinely compounds. This
    // is the same fix the actual Sandia tool relies on, not a workaround.
    for (int li = 0; li < layerGrids.length; li++) {
      layers.add({'features': _sgmAttrsToFeatures(layerGrids[li][r][c])});
    }
    return {'type': 'sandia_cell', 'grid_box': true, 'layers': layers};
  }

  /// Per-cell visible signature used to detect a layer that renders
  /// pixel-identical across the whole grid (e.g. a 'cornerOut' base - one
  /// shared seed for every cell - paired with a 'fillRepetition'
  /// supplemental, which is a no-op on top of an already-constant fill).
  /// Same symmetry normalization as _visibleKey: a shape that looks the
  /// same at two different 'rot' values must hash the same, or this would
  /// under-detect and let a genuinely-invisible layer through.
  static String _sgmAttrsVisibleKey(Map<String, dynamic> attrs) {
    if (attrs['logicShapes'] != null) {
      return 'logic:${(attrs['logicShapes'] as Set<String>).toList()..sort()}';
    }
    final String shape = attrs['shape'] as String;
    int rot = (attrs['rot'] as double).round() % 360;
    // rectangle and ellipse (never square/circular here - _sgmRandomDims
    // guarantees w != h) both look identical after a 180-degree turn.
    if (shape == 'rectangle' || shape == 'ellipse') rot = rot % 180;
    return 'sh:$shape-w:${attrs['w']}-h:${attrs['h']}-r:$rot-sc:${attrs['scale']}-f:${attrs['fill']}-cnt:${attrs['count']}';
  }

  /// True if this layer shows at least one real difference across the 8
  /// visible context cells (everything except the held-out bottom-right).
  /// A layer that fails this contributes nothing a solver could reason
  /// from - the whole point of showing 8 example cells.
  static bool _sgmLayerHasVisibleVariation(List<List<Map<String, dynamic>>> grid) {
    String? first;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (r == 2 && c == 2) continue;
        final key = _sgmAttrsVisibleKey(grid[r][c]);
        first ??= key;
        if (key != first) return true;
      }
    }
    return false;
  }

  static Map<String, String> _sgmRandomSupplement() => {
    'type': ['rotation', 'scaling', 'fillRepetition', 'changeFill', 'numerosity'][_r.nextInt(5)],
    'transform': _sgmTransforms[_r.nextInt(_sgmTransforms.length)],
  };

  /// Tracks the "recipe" (which base feature + transform + supplement
  /// types each layer used) of the last few pattern questions. Without
  /// this, nothing stops the engine from handing out several
  /// rotation-only or size-only questions in a row - different specific
  /// shapes and colors each time, so it doesn't look like a literal
  /// repeat, but a student experiences it as "I've seen this kind of
  /// question three times now" and starts checking only the one attribute
  /// they've learned matters, instead of reasoning about the grid fresh.
  static final List<String> _recentPatternRecipes = [];
  static const int _patternCooldown = 4;

  static Map<String, dynamic> _sgmRandomLayerConfig(int complexity) {
    // Odds per complexity tier. Tier 3 matches the real tool's actual
    // ceiling: up to 3 stacked supplemental features (First/Second/Third
    // slots in the UI), logic layers roughly as common as in the source
    // tool's uniform random choice between the 4 base features.
    final logicChance = {1: 8, 2: 5, 3: 3}[complexity]!; // 1-in-N
    final maxSupplements = {1: 1, 2: 2, 3: 3}[complexity]!;
    final minSupplements = complexity == 1 ? 1 : 1;

    final isLogic = _r.nextInt(logicChance) == 0;
    final baseTransform = isLogic ? 'horizontal' : _sgmTransforms[_r.nextInt(_sgmTransforms.length)];
    final logicOp = ['and', 'or', 'xor'][_r.nextInt(3)];

    final supplements = <Map<String, String>>[];
    if (!isLogic) {
      final range = maxSupplements - minSupplements + 1;
      final numSupplements = minSupplements + _r.nextInt(range); // never 0
      final usedTypes = <String>{};
      for (int s = 0; s < numSupplements; s++) {
        Map<String, String> supp;
        int guard = 0;
        do {
          supp = _sgmRandomSupplement();
          guard++;
          // BUGFIX: 'scaling' and 'numerosity' both shrink the same
          // attrs['scale'] value - numerosity's own grid-packing formula
          // (0.75/numPositions) multiplies directly on top of whatever
          // 'scaling' already floored it to, so the two together can land
          // well under the legibility floor even after that floor was
          // raised (e.g. 0.55 x 0.375 x smallest base width 0.25 = 0.05).
          // Raising the scaling floor further to compensate would flatten
          // its own visible step-size rule when it runs alone, so excluded
          // the combination at the source instead.
        } while ((usedTypes.contains(supp['type']) ||
            (usedTypes.contains('scaling') && supp['type'] == 'numerosity') ||
            (usedTypes.contains('numerosity') && supp['type'] == 'scaling')) &&
            guard < 10);
        usedTypes.add(supp['type']!);
        supplements.add(supp);
      }
    }

    return {'isLogic': isLogic, 'baseTransform': baseTransform, 'logicOp': logicOp, 'supplements': supplements};
  }

  static String _sgmRecipeSignature(List<Map<String, dynamic>> layerConfigs) {
    final parts = layerConfigs.map((cfg) {
      if (cfg['isLogic'] as bool) return 'logic:${cfg['logicOp']}';
      final supps = (cfg['supplements'] as List<Map<String, String>>).map((s) => s['type']).toList()..sort();
      return 'shape:${cfg['baseTransform']}:${supps.join(',')}';
    }).toList()
      ..sort(); // order-independent - 2 layers in either order are "the same recipe"
    return parts.join('|');
  }

  static ReasoningQuestion _generateFullSandiaMatrix({int complexity = 3}) {
    // complexity 1 = light, 2 = medium, 3 = full density (matches the real
    // tool's ceiling - see generate()'s doc comment). Every non-logic
    // layer always gets at least 1 supplemental feature regardless of
    // tier - a layer with zero visible transformation (just a shape
    // copied along a row/column, nothing else happening) was the single
    // biggest source of "these all look the same" in earlier rounds.
    final layerChance = {1: 2, 2: 5, 3: 6}[complexity]!; // chance out of 10 of getting 2 layers
    List<Map<String, dynamic>> layerConfigs;
    String recipe;
    int attempts = 0;
    List<List<List<Map<String, dynamic>>>> layerGrids;
    do {
      final numLayers = _r.nextInt(10) < layerChance ? 2 : 1;
      layerConfigs = List.generate(numLayers, (_) => _sgmRandomLayerConfig(complexity));
      recipe = _sgmRecipeSignature(layerConfigs);
      attempts++;

      layerGrids = [
        for (final cfg in layerConfigs)
          _sgmBuildLayer(
            isLogic: cfg['isLogic'] as bool,
            baseTransform: cfg['baseTransform'] as String,
            logicOp: cfg['logicOp'] as String,
            supplements: cfg['supplements'] as List<Map<String, String>>,
          )
      ];
      // BUGFIX: a base transform that seeds every cell identically (e.g.
      // 'cornerOut') paired with a supplemental that's a no-op on top of
      // that (e.g. 'fillRepetition' holding an already-constant fill)
      // renders 8 pixel-identical context cells - no rule a solver could
      // ever see. Require at least one layer to show real variation; retry
      // the whole layer build (same budget as the recipe-cooldown retry)
      // otherwise, since it's cheap and this is the root cause, not a
      // cosmetic tweak.
    } while ((_recentPatternRecipes.contains(recipe) ||
        !layerGrids.any(_sgmLayerHasVisibleVariation) ||
        layerGrids.any(_sgmHasRowColGiveaway) ||
        layerGrids.any(_sgmHasOvercrowdedLogicCell)) &&
        attempts < 30);

    _recentPatternRecipes.add(recipe);
    while (_recentPatternRecipes.length > _patternCooldown) {
      _recentPatternRecipes.removeAt(0);
    }

    // Build the 8 context cells (everything except the held-out bottom-right).
    final cells = <Map<String, dynamic>>[];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (r == 2 && c == 2) {
          cells.add({'empty': true});
        } else {
          cells.add(_sgmCellAt(layerGrids, r, c));
        }
      }
    }

    // ---- RAVEN-FAIR-style answer set: an Attribute Bisection Tree -----------
    // Rather than mutating the correct answer differently for each
    // distractor (RAVEN's original approach, shown to let a solver find the
    // correct answer just by picking whichever choice shares the most
    // attributes with the others - see Zhang et al.'s RAVEN-FAIR and Hu et
    // al.'s I-RAVEN), 2 independent perturbations are sampled once and then
    // every one of the 4 combinations of "apply / don't apply" each of them
    // becomes one answer choice. Every choice sits at Hamming distance 0-2
    // from the correct one in a perfectly balanced square - no choice is
    // structurally more "central" than another, so the answer set itself
    // gives no shortcut.
    //
    // 4 choices, not 8: 8-way multiple choice is a second, independent
    // source of difficulty on top of an already denser matrix grammar
    // (more layers, more transform types, chained supplementals) - stacking
    // both compounds past what's reasonable for this age group. 4 keeps the
    // "no shortcut" answer-set property while matching the choice count
    // used everywhere else in the app.
    const numPerturbationBits = 2;
    final numOptions = 1 << numPerturbationBits; // 4
    final perturbations = _sgmBuildPerturbations(layerGrids, layerGrids.length, numPerturbationBits);

    final rawOptions = <Map<String, dynamic>>[];
    for (int subset = 0; subset < numOptions; subset++) {
      final perturbedGrids = [for (final g in layerGrids) [for (final row in g) [for (final cell in row) _sgmCopy(cell)]]];
      for (int bit = 0; bit < numPerturbationBits; bit++) {
        if ((subset >> bit) & 1 == 1) {
          perturbations[bit](perturbedGrids);
        }
      }
      rawOptions.add(_sgmCellAt(perturbedGrids, 2, 2));
    }

    final indices = List.generate(numOptions, (i) => i)..shuffle(_r);
    final options = [for (final i in indices) rawOptions[i]];
    final correctIndex = indices.indexOf(0); // subset 0 = unperturbed = correct

    return ReasoningQuestion(
      category: 'pattern',
      type: 'sandia_full_matrix',
      puzzle: {
        'type': 'matrix',
        'cells': cells,
        'missing': 8,
      },
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// 3 independent, always-visible mutation functions applied only to the
  /// held-out (2,2) cell of a cloned layer-grid set. Picked fresh per
  /// question so the answer set's structure can't be memorized.
  static List<void Function(List<List<List<Map<String, dynamic>>>>)> _sgmBuildPerturbations(
      List<List<List<Map<String, dynamic>>>> referenceGrids, int numLayers, int count) {
    final candidates = <void Function(List<List<List<Map<String, dynamic>>>>)>[];

    for (int li = 0; li < numLayers; li++) {
      final refCell = referenceGrids[li][2][2];

      if (refCell['logicShapes'] != null) {
        // Logic layer: the only meaningful, always-visible perturbation is
        // toggling membership of one of the two marker shapes actually in
        // play for this layer. Collect them once from the whole grid.
        final usedShapes = <String>{};
        for (final row in referenceGrids[li]) {
          for (final c in row) {
            usedShapes.addAll(c['logicShapes'] as Set<String>);
          }
        }
        final shapesList = usedShapes.toList();

        for (final s in shapesList) {
          candidates.add((grids) {
            final shapes = grids[li][2][2]['logicShapes'] as Set<String>;
            if (shapes.contains(s)) {
              shapes.remove(s);
            } else {
              shapes.add(s);
            }
          });
        }
        if (shapesList.length >= 2) {
          // A third, distinct option: toggle both at once.
          candidates.add((grids) {
            final shapes = grids[li][2][2]['logicShapes'] as Set<String>;
            for (final s in shapesList) {
              if (shapes.contains(s)) {
                shapes.remove(s);
              } else {
                shapes.add(s);
              }
            }
          });
        }
        continue;
      }

      // Shape-repetition layer: resolve every replacement value ONCE, here,
      // from the stable reference cell - never inside the closure.
      final targetRot = ((refCell['rot'] as double) + 90) % 360;
      final shapePool = _shapePool.where((s) => s != refCell['shape']).toList()..shuffle(_r);
      final targetShape = shapePool.first;
      final targetFill = SandiaFillCompat.next(refCell['fill'] as String);
      // BUGFIX: this is a separate shrink from the chain-supplemental
      // 'scaling' floor above - it multiplies on top of whatever
      // refCell['scale'] already is (which could itself already be at that
      // floor), so raising that floor alone couldn't close this. Only ever
      // used to build a WRONG-answer option (the correct option and every
      // context cell inherit refCell['scale'] unmodified), which is why it
      // wasn't caught by the earlier fixes: those only ever generated
      // findings against context cells and the chain itself. Floored the
      // same way: 0.5 x the smallest possible base width (0.25) = 0.125,
      // clearing the 0.12 legibility threshold.
      final targetScale = max(0.5, (refCell['scale'] as double) * 0.7);
      final refW = refCell['w'] as double;
      final refH = refCell['h'] as double;
      final isNumerosity = (refCell['count'] as int) > 1;
      // BUGFIX: _numerosityFeatures hardcodes every dot to w:0.85, h:0.85
      // and never reads the cell's own w/h at all - so the w/h-swap
      // candidate below is a complete no-op on every numerosity cell, 100%
      // of the time, regardless of shape: it swaps two values nothing ever
      // reads. It's also invisible whenever a rotation candidate is
      // applied to a numerosity cell whose shape becomes 90-degree
      // rotationally symmetric once forced square (diamond/ellipse/
      // rectangle all qualify; triangle/tee/trapezoid don't). Either one
      // landing as the chosen "wrong answer" perturbation renders
      // identically to the reference cell - a real duplicate-looking
      // option, not merely a subtle one. Excluded both for numerosity
      // cells rather than only the specific symmetric-shape case, since
      // the w/h-swap failure has no shape dependency at all.
      final rotIsSafe = !isNumerosity || !{'diamond', 'ellipse', 'rectangle'}.contains(refCell['shape']);

      if (rotIsSafe) candidates.add((grids) => grids[li][2][2]['rot'] = targetRot);
      candidates.add((grids) => grids[li][2][2]['shape'] = targetShape);
      candidates.add((grids) => grids[li][2][2]['fill'] = targetFill);
      candidates.add((grids) => grids[li][2][2]['scale'] = targetScale);
      // BUGFIX: on rectangle/ellipse/diamond, "+90 rotation" and "swap w/h"
      // are the same visual edit. With both picked as the two perturbation
      // bits, each cancels the other: options 00==11 and 01==10, the exact
      // "two identical pairs" signature (confirmed by the visual test).
      // Offer only one of them for those shapes.
      final whSwapDuplicatesRot = rotIsSafe && _isCentrallySymmetricShape(refCell['shape'] as String);
      if (!isNumerosity && !whSwapDuplicatesRot) {
        candidates.add((grids) {
          grids[li][2][2]['w'] = refH;
          grids[li][2][2]['h'] = refW;
        });
      }
    }

    candidates.shuffle(_r);
    final chosen = candidates.take(count).toList();
    // Defensive fallback only - the loop above always produces at least 3
    // candidates per layer even in the worst case (numerosity cell with a
    // 90-degree-symmetric shape excludes both rot and w/h-swap, leaving
    // shape/fill/scale), so this should never actually trigger. Uses a
    // fill change rather than rotation for the fallback itself, since fill
    // has no geometric-invisibility failure mode to worry about the way
    // rotation does on a forced-square numerosity dot.
    while (chosen.length < count) {
      chosen.add((grids) => grids[0][2][2]['fill'] = SandiaFillCompat.next(grids[0][2][2]['fill'] as String));
    }
    return chosen;
  }

  // ===========================================================================
  // 3. HARD DENSE FIGURE SERIES & ANALOGY - unchanged
  // ===========================================================================

  static ReasoningQuestion _generateDenseMultiLayerSeries() {
    // BUGFIX: only 3 bg options x 4 fg options = 12 total shape
    // combinations existed here, with 2 of the 10 available shape codes
    // (3=diamond, 9=thick-cross) never used anywhere in this generator -
    // the actual rule (90-degree rotation, fill cycling, lines count) is
    // otherwise identical on every single generation, so the shape pool
    // was the only source of variety at all, and it was this narrow.
    // Confirmed safe to widen: every distractor and the correct option
    // below are built entirely from fixed rotation/fill/scale/lines
    // literals - bgShape/fgShape are purely decorative substitutions that
    // never affect which option is correct. Shape 1 (ellipse) stays
    // reserved since it's the fixed middle/frame layer every question
    // already uses; fgShape explicitly excludes whatever bgShape drew so
    // the two never coincide, same as the original disjoint pools did
    // implicitly. 5 x 5 (with exclusion) = 20 combinations, up from 12.
    //
    // BUGFIX: 9 (thick cross) removed from bgPool. It's 90-degree
    // symmetric, and the background's quarter-turn IS the rule here - the
    // correct option and distractor d1 differ ONLY in background rotation
    // (3 vs 2), so with a cross they rendered pixel-identical (~20% of
    // figure_series questions, confirmed by the visual test). fgPool keeps
    // it: the foreground is identical across all 4 options, and its lines
    // overlay still shows each step's rotation.
    final bgPool = [0, 2, 3, 6];
    final fgPool = [3, 4, 5, 7, 8, 9];
    final bgShape = bgPool[_r.nextInt(bgPool.length)];
    final fgShape = (fgPool.where((s) => s != bgShape).toList()..shuffle(_r)).first;

    final seq = [
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': bgShape, 'fill': 1, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
          {'surface': 1, 'fill': 0, 'scale': 1.5, 'rotation': 0},
          {'surface': fgShape, 'fill': 3, 'scale': 1.0, 'rotation': 0, 'lines': 1},
        ],
      },
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': bgShape, 'fill': 2, 'scale': 2.2, 'rotation': 1, 'grid_box': true},
          {'surface': 1, 'fill': 1, 'scale': 1.5, 'rotation': 1},
          {'surface': fgShape, 'fill': 2, 'scale': 1.0, 'rotation': 1, 'lines': 2},
        ],
      },
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': bgShape, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
          {'surface': 1, 'fill': 2, 'scale': 1.5, 'rotation': 2},
          {'surface': fgShape, 'fill': 1, 'scale': 1.0, 'rotation': 2, 'lines': 3},
        ],
      },
    ];

    final correctOption = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape, 'fill': 1, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 3},
        {'surface': fgShape, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };

    final d1 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape, 'fill': 1, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 3},
        {'surface': fgShape, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };
    final d2 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape, 'fill': 1, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 1, 'scale': 1.5, 'rotation': 3},
        {'surface': fgShape, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };
    final d3 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape, 'fill': 3, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 0},
        {'surface': fgShape, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };

    final distractors = [d1, d2, d3]..shuffle(_r);
    final options = <Map<String, dynamic>>[];
    final correctIndex = _r.nextInt(4);
    int dPtr = 0;

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add(correctOption);
      } else {
        options.add(distractors[dPtr++]);
      }
    }

    return ReasoningQuestion(
      category: 'figure_series',
      type: 'hard_series_sandia_3layer',
      puzzle: {
        'type': 'series',
        'sequence': seq,
      },
      options: options,
      correctIndex: correctIndex,
    );
  }

  static ReasoningQuestion _generateDenseMultiLayerAnalogy() {
    // Same fix as _generateDenseMultiLayerSeries above, same reasoning:
    // shape choice here is decorative only (verified against the
    // correctOption/distractor construction below, which uses fixed
    // rotation/fill literals throughout), so widening the pools is safe
    // and directly addresses the "everything looks similar" complaint.
    //
    // BUGFIX: the background's 180-degree turn is half the A->B rule, and
    // distractor d2 differs from the correct answer ONLY by that turn. Any
    // background that looks the same (or nearly the same) upside down makes
    // the rule invisible in A->B and/or d2 indistinguishable from the
    // answer: 2 (rectangle) and 9 (cross) are exactly 180-degree symmetric,
    // 3 (diamond) nearly so. 6 is dropped too because it's literally 0
    // turned upside down, so pairing them made C look like B. One shared
    // pool of shapes that clearly change when flipped, A and C distinct.
    const bgPool = [0, 4, 5, 7, 8];
    final bgShape1 = bgPool[_r.nextInt(bgPool.length)];
    final bgShape2 = (bgPool.where((s) => s != bgShape1).toList()..shuffle(_r)).first;

    final figA = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape1, 'fill': 0, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 1, 'fill': 1, 'scale': 1.2, 'rotation': 0},
      ],
    };
    final figB = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape1, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 1, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final figC = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape2, 'fill': 0, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 2, 'fill': 1, 'scale': 1.2, 'rotation': 0},
      ],
    };

    final correctOption = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape2, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };

    final d1 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape2, 'fill': 0, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final d2 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape2, 'fill': 3, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final d3 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': bgShape2, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 2, 'fill': 1, 'scale': 1.2, 'rotation': 0},
      ],
    };

    final distractors = [d1, d2, d3]..shuffle(_r);
    final options = <Map<String, dynamic>>[];
    final correctIndex = _r.nextInt(4);
    int dPtr = 0;

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add(correctOption);
      } else {
        options.add(distractors[dPtr++]);
      }
    }

    return ReasoningQuestion(
      category: 'analogy',
      type: 'hard_analogy_sandia_3layer',
      puzzle: {
        'type': 'analogy',
        'A': figA,
        'B': figB,
        'C': figC,
      },
      options: options,
      correctIndex: correctIndex,
    );
  }
}

/// Small standalone copy of the fill-cycle stepper so this file has no hard
/// import dependency on sandia_painter.dart (keeps generator + painter
/// independently testable). Mirrors SandiaFill.cycle / SandiaFill.next in
/// sandia_painter.dart exactly - if you change one, change both.
class SandiaFillCompat {
  static const List<String> cycle = ['white', 'grey40', 'grey10', 'black'];

  static String next(String key) {
    final i = cycle.indexOf(key);
    return cycle[(i < 0 ? 0 : i + 1) % cycle.length];
  }
}