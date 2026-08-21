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

      final sig = _buildCanonicalSignature(q);
      if (_sessionHistory.add(sig)) {
        return q;
      }
    }
    return _buildQuestionForCategory(category, complexity);
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
        return _generateHardOddMan();
    }
  }

  /// Symmetry-Aware Visual Key Generator
  static String _visibleKey(Map<String, dynamic> m) {
    if (m['type'] == 'sandia_cell') {
      final layers = m['layers'] as List? ?? [];
      final layerKeys = layers.map((l) {
        final Map<String, dynamic> lm = Map<String, dynamic>.from(l as Map);

        if (lm.containsKey('features')) {
          // Authentic-schema layer (odd_man generators)
          final feats = (lm['features'] as List? ?? []).map((f) {
            final Map<String, dynamic> fm = Map<String, dynamic>.from(f as Map);
            final String shape = fm['shape'] as String? ?? 'ellipse';
            int rot = ((fm['rot'] as num?) ?? 0).toInt() % 360;

            // Symmetry normalization: shapes that look identical under
            // 180-degree rotation, or under any rotation (ellipse w==h).
            final double w = ((fm['w'] as num?) ?? 0.5).toDouble();
            final double h = ((fm['h'] as num?) ?? 0.5).toDouble();
            if (shape == 'rectangle') {
              rot = rot % 180;
            } else if (shape == 'ellipse') {
              rot = (w == h) ? 0 : rot % 180;
            }

            return 'sh:$shape-w:$w-h:$h-r:$rot'
                '-cx:${fm['cx']}-cy:${fm['cy']}-sc:${fm['scale']}-f:${fm['fill']}';
          }).join(',');
          return 'feat[$feats]-gb:${lm['grid_box']}';
        }

        // Legacy-schema layer (pattern/series/analogy generators)
        final int s = lm['surface'] as int? ?? 0;
        int r = lm['rotation'] as int? ?? 0;
        bool mir = lm['mirror_h'] as bool? ?? false;

        if (s == 1 || s == 2 || s == 9) {
          r = r % 2;
        } else if (s == 10) {
          r = 0;
        }

        return 's:$s-f:${lm['fill']}-r:$r-m:$mir-l:${lm['lines'] ?? 0}-dp:${lm['dot_pos'] ?? -1}';
      }).join('|');
      return 'sandia[$layerKeys]-gb:${m['grid_box']}';
    }
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
      'change_fill_pattern': _oddManChangeFillPattern,
      'fill_pattern_repetition': _oddManFillPatternRepetition,
      'translational_numerosity': _oddManTranslationalNumerosity,
      'arithmetic': _oddManArithmetic,
      'constant_attribute': _oddManConstantAttribute,
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
  static const List<String> _rotationSafeShapes = ['rectangle', 'triangle', 'tee', 'diamond', 'trapezoid'];

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

    final baseRotations = [0, 90, 180, 270]..shuffle(_r); // one per option
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

    final shape = _randomShape();
    final oddIndex = _r.nextInt(4);
    final rotations = [0, 90, 180, 270]..shuffle(_r);
    final fills = ['white', 'grey75', 'grey40', 'black']..shuffle(_r);
    final outerDims = _sgmRandomDims();
    final outerW = outerDims[0] * 1.05;
    final outerH = outerDims[1] * 1.05;

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final factor = (i == oddIndex) ? wrongFactor : correctFactor;

      options.add(_cell([
        _feature(shape, w: outerW, h: outerH, rot: rotations[i], fill: 'white'),
        _feature(shape, w: outerW * factor, h: outerH * factor, rot: rotations[i], fill: fills[i]),
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
    final fgW = fgDims[0] * 0.56;
    final fgH = fgDims[1] * 0.56;

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
        final others = _fillCycle.where((f) => f != sharedFill).toList()..shuffle(_r);
        fillB = others.first;
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
    final shape = _randomShape();
    final fill = _basicFillPool[_r.nextInt(_basicFillPool.length)];
    final majorityCount = [2, 3, 4][_r.nextInt(3)];
    int oddCount;
    do {
      oddCount = [2, 3, 4, 5][_r.nextInt(4)];
    } while (oddCount == majorityCount);

    final oddIndex = _r.nextInt(4);

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final count = (i == oddIndex) ? oddCount : majorityCount;
      options.add(_cell(_numerosityFeatures(shape, fill, count), gridBox: true));
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
  static ReasoningQuestion _oddManConstantAttribute() {
    final shape = _randomShape();
    final oddIndex = _r.nextInt(4);
    final rotation = [0, 90, 180, 270][_r.nextInt(4)];

    final majorityFill = _fillCycle[_r.nextInt(_fillCycle.length)];
    final oddFill = (_fillCycle.where((f) => f != majorityFill).toList()..shuffle(_r)).first;

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
    final finalCorner = _rotateCorner(cc, rot);
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
          ? _feature('triangle', w: 0.16, h: 0.16, rot: rot, cx: 0.5 + _cornerOffsets[overrideMarkerACorner][0], cy: 0.5 + _cornerOffsets[overrideMarkerACorner][1], fill: 'black')
          : _markerFeature('triangle', markerACorner, rot, mirror),
      overrideMarkerBCorner != null
          ? _feature('rectangle', w: 0.13, h: 0.13, rot: rot, cx: 0.5 + _cornerOffsets[overrideMarkerBCorner][0], cy: 0.5 + _cornerOffsets[overrideMarkerBCorner][1], fill: 'black')
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
    final innerW = outerW * 0.5;
    final innerH = outerH * 0.5;
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
          final correctA = _rotateCorner(markerACorner, rot);
          final wrongA = ([0, 1, 2, 3]..remove(correctA))[_r.nextInt(3)];
          distractors.add(build(rot: rot, mirror: false, overrideMarkerACorner: wrongA));
          break;
        case 'markerB':
        default:
          final correctB = _rotateCorner(markerBCorner, rot);
          final wrongB = ([0, 1, 2, 3]..remove(correctB))[_r.nextInt(3)];
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
          return _sgmCellAttrs(
              shape: _randomShape(), w: dims[0], h: dims[1], fill: _basicFillPool[_r.nextInt(_basicFillPool.length)]);
        });
        grid[r][c] = _sgmCopy(seed);
      }
    }
  }

  /// Logical AND/OR/XOR: exact port of SGMLayer's special-case derivation -
  /// the top-left 2x2 gets independent random {shapeX, shapeY} membership
  /// sets, row 0 and row 1's third column is derived by combining that
  /// row's first two cells, then row 2 is derived by combining rows 0 and 1
  /// column-by-column. This is the real algorithm (row-combine, then
  /// column-combine), not the odd-man-out generator's darkness stand-in.
  static void _sgmApplyLogicBase(List<List<Map<String, dynamic>>> grid, String op) {
    final pool = _shapePool.toList()..shuffle(_r);
    final shapeX = pool[0];
    final shapeY = pool[1];

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

    Set<String> randomSubset() {
      final s = <String>{};
      if (_r.nextBool()) s.add(shapeX);
      if (_r.nextBool()) s.add(shapeY);
      return s;
    }

    List<List<Set<String>>> base;
    // Retry if the 2x2 seed is entirely empty (nothing to see / combine).
    do {
      base = [
        [randomSubset(), randomSubset()],
        [randomSubset(), randomSubset()],
      ];
    } while (base[0][0].isEmpty && base[0][1].isEmpty && base[1][0].isEmpty && base[1][1].isEmpty);

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
              next['scale'] = (previous['scale'] as double) * 0.66;
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
      final shapes = (attrs['logicShapes'] as Set<String>).toList();
      final features = <Map<String, dynamic>>[];
      for (int i = 0; i < shapes.length; i++) {
        features.add(_feature(shapes[i], w: 0.4, h: 0.4, cx: i == 0 ? 0.28 : 0.72, cy: 0.5, fill: i == 0 ? 'grey40' : 'black'));
      }
      return features;
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

  static Map<String, dynamic> _sgmCellAt(List<List<List<Map<String, dynamic>>>> layerGrids, int r, int c) {
    final layers = <Map<String, dynamic>>[];
    for (final grid in layerGrids) {
      layers.add({'features': _sgmAttrsToFeatures(grid[r][c])});
    }
    return {'type': 'sandia_cell', 'grid_box': true, 'layers': layers};
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
        } while (usedTypes.contains(supp['type']) && guard < 10);
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
    do {
      final numLayers = _r.nextInt(10) < layerChance ? 2 : 1;
      layerConfigs = List.generate(numLayers, (_) => _sgmRandomLayerConfig(complexity));
      recipe = _sgmRecipeSignature(layerConfigs);
      attempts++;
    } while (_recentPatternRecipes.contains(recipe) && attempts < 30);

    _recentPatternRecipes.add(recipe);
    while (_recentPatternRecipes.length > _patternCooldown) {
      _recentPatternRecipes.removeAt(0);
    }

    final layerGrids = <List<List<Map<String, dynamic>>>>[];
    for (final cfg in layerConfigs) {
      layerGrids.add(_sgmBuildLayer(
        isLogic: cfg['isLogic'] as bool,
        baseTransform: cfg['baseTransform'] as String,
        logicOp: cfg['logicOp'] as String,
        supplements: cfg['supplements'] as List<Map<String, String>>,
      ));
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
      final targetScale = (refCell['scale'] as double) * 0.7;
      final refW = refCell['w'] as double;
      final refH = refCell['h'] as double;

      candidates.add((grids) => grids[li][2][2]['rot'] = targetRot);
      candidates.add((grids) => grids[li][2][2]['shape'] = targetShape);
      candidates.add((grids) => grids[li][2][2]['fill'] = targetFill);
      candidates.add((grids) => grids[li][2][2]['scale'] = targetScale);
      candidates.add((grids) {
        grids[li][2][2]['w'] = refH;
        grids[li][2][2]['h'] = refW;
      });
    }

    candidates.shuffle(_r);
    final chosen = candidates.take(count).toList();
    // Defensive fallback only - the loop above always produces at least 2
    // candidates per layer (4 for shape-repetition, 2-3 for logic), so this
    // should never actually trigger for a 1-or-2-layer question.
    while (chosen.length < count) {
      chosen.add((grids) => grids[0][2][2]['rot'] = ((grids[0][2][2]['rot'] as double) + 180) % 360);
    }
    return chosen;
  }

  // ===========================================================================
  // 3. HARD DENSE FIGURE SERIES & ANALOGY - unchanged
  // ===========================================================================

  static ReasoningQuestion _generateDenseMultiLayerSeries() {
    final bgShape = [0, 2, 6][_r.nextInt(3)];
    final fgShape = [4, 5, 7, 8][_r.nextInt(4)];

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
    final bgShape1 = [0, 2, 6][_r.nextInt(3)];
    final bgShape2 = [3, 4, 5, 8][_r.nextInt(4)];

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