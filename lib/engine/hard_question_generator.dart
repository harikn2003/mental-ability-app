import 'dart:convert';
import 'dart:math';

import 'reasoning_question.dart';

/// HardQuestionGenerator - Complete Dart Implementation of Sandia Matrix
/// & RAVEN A-SIG Hierarchical Grammar Engine for Advanced Mental Ability Items.
class HardQuestionGenerator {
  static Random _r = Random();
  static final Set<String> _sessionHistory = {};

  static void seed(int s) {
    _r = Random(s);
  }

  static void resetSession() {
    _sessionHistory.clear();
  }

  /// Main Dispatch Method
  static ReasoningQuestion generate(String category) {
    for (int attempts = 0; attempts < 350; attempts++) {
      ReasoningQuestion q = _buildQuestionForCategory(category);

      // Verify all 4 options are 100% visually unique under symmetry normalization
      final optionKeys = q.options.map((o) => _visibleKey(o)).toSet();
      if (optionKeys.length < 4) {
        continue; // Discard and retry if options contain visual duplicates
      }

      final sig = _buildCanonicalSignature(q);
      if (_sessionHistory.add(sig)) {
        return q;
      }
    }
    return _buildQuestionForCategory(category);
  }

  static ReasoningQuestion _buildQuestionForCategory(String category) {
    switch (category) {
      case 'odd_man':
        return _generateHardOddMan();
      case 'pattern':
        return _generateSandia3LayerMatrix();
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

  static ReasoningQuestion _generateHardOddMan() {
    final subTypes = [
      _oddManRotationalRepetition,
      _oddManScalingRepetition,
      _oddManChangeFillPattern,
      _oddManFillPatternRepetition,
      _oddManTranslationalNumerosity,
      _oddManArithmetic,
      _oddManConstantAttribute,
      // NOTE: _oddManLogicalCombination is intentionally left out of
      // rotation. It went through two rounds of bugfixes (arbitrary
      // shape-category signal -> fill-darkness signal; dot colliding with
      // the candidate shape -> repositioned) and users still couldn't
      // solve it reliably. The remaining problem is structural, not a
      // rendering bug: it asks a solver to read three separate small
      // signals (key shade, candidate shade, a corner dot) and combine
      // them through a hidden AND/OR/XOR operator - too much simultaneous
      // inference for a 4-option glance-and-answer format. Left the
      // function defined below in case a future redesign wants to reuse
      // pieces of it, but it should stay out of the active pool.
    ];
    return subTypes[_r.nextInt(subTypes.length)]();
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
        _feature(shape, w: 0.78, h: 0.78, rot: outerRot, fill: outerFill),
        _feature(shape, w: 0.42, h: 0.42, rot: innerRot, fill: innerFill),
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

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      const outerW = 0.8, outerH = 0.8;
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
        _feature(bgShape, w: 0.8, h: 0.8, rot: bgRot, fill: bgFill),
        _feature(fgShape, w: 0.42, h: 0.42, rot: fgRot, fill: fgFill),
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
        _feature(shapeA, w: 0.4, h: 0.4, rot: rotA, cx: 0.26, cy: 0.5, fill: fillA),
        _feature(shapeB, w: 0.4, h: 0.4, rot: rotB, cx: 0.74, cy: 0.5, fill: fillB),
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
  static List<Map<String, dynamic>> _numerosityFeatures(String shape, String fill, int count) {
    final numPositions = sqrt(count).ceil();
    final positionStep = 1.0 / (numPositions + 1); // fraction of cell (pixel formula normalized to [0,1])
    final scaling = 0.75 / numPositions;

    final features = <Map<String, dynamic>>[];
    int col = 0, row = 0;
    for (int i = 0; i < count; i++) {
      final cx = (col + 1) * positionStep;
      final cy = (row + 1) * positionStep;
      features.add(_feature(shape, w: 0.85, h: 0.85, scale: scaling, cx: cx, cy: cy, fill: fill));
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
  static ReasoningQuestion _oddManConstantAttribute() {
    final shape = _randomShape();
    final oddIndex = _r.nextInt(4);
    final rotation = [0, 90, 180, 270][_r.nextInt(4)];

    final majorityFill = _fillCycle[_r.nextInt(_fillCycle.length)];
    final oddFill = (_fillCycle.where((f) => f != majorityFill).toList()..shuffle(_r)).first;

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final fill = (i == oddIndex) ? oddFill : majorityFill;
      options.add(_cell([
        _feature(shape, w: 0.72, h: 0.72, rot: rotation, fill: fill),
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
  // 2. SANDIA 3-LAYER MATRIX GENERATOR (PATTERN COMPLETION) - unchanged
  // ===========================================================================

  static ReasoningQuestion _generateSandia3LayerMatrix() {
    final bgPool = [0, 2, 6]..shuffle(_r);
    final midPool = [1, 3, 9]..shuffle(_r);
    final fgPool = [4, 5, 7, 8]..shuffle(_r);

    final cells = <Map<String, dynamic>>[];

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (r == 2 && c == 2) {
          cells.add({'empty': true});
        } else {
          cells.add(_buildDense3LayerCell(r, c, bgPool, midPool, fgPool));
        }
      }
    }

    final correctOption = _buildDense3LayerCell(2, 2, bgPool, midPool, fgPool);

    final d1 = _buildDense3LayerCell(2, 2, bgPool, midPool, fgPool);
    ((d1['layers'] as List)[0] as Map)['surface'] = bgPool[0];

    final d2 = _buildDense3LayerCell(2, 2, bgPool, midPool, fgPool);
    ((d2['layers'] as List)[1] as Map)['fill'] = 3;

    final d3 = _buildDense3LayerCell(2, 2, bgPool, midPool, fgPool);
    ((d3['layers'] as List)[2] as Map)['rotation'] = 0;

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
      category: 'pattern',
      type: 'sandia_3layer_matrix_dense',
      puzzle: {
        'type': 'matrix',
        'cells': cells,
        'missing': 8,
      },
      options: options,
      correctIndex: correctIndex,
    );
  }

  static Map<String, dynamic> _buildDense3LayerCell(
      int r,
      int c,
      List<int> l1Surfaces,
      List<int> l2Surfaces,
      List<int> l3Surfaces,
      ) {
    final l1 = {
      'surface': l1Surfaces[r % 3],
      'fill': (r == 0) ? 2 : (r == 1 ? 3 : 1),
      'scale': 2.2,
      'rotation': 0,
      'grid_box': true,
      'lines': (c == 0) ? 0 : 2,
    };

    final l2 = {
      'surface': l2Surfaces[(r + c) % 3],
      'fill': (c == 0) ? 0 : (c == 1 ? 1 : 2),
      'scale': 1.5,
      'rotation': 0,
      'lines': 0,
    };

    final l3 = {
      'surface': l3Surfaces[c % 3],
      'fill': (r == c) ? 3 : 0,
      'scale': 1.0,
      'rotation': (r + c) % 4,
      'lines': 1,
    };

    return {
      'type': 'sandia_cell',
      'layers': [l1, l2, l3],
    };
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