import 'dart:math';
import 'reasoning_question.dart';

/// HardQuestionGenerator - Generates dense, 3-4 layer composite visual
/// matrix and odd-man questions based on the Sandia Matrix Engine.
class HardQuestionGenerator {
  static Random _r = Random();
  static final Set<String> _sessionHistory = {};

  static void seed(int s) {
    _r = Random(s);
  }

  static void resetSession() {
    _sessionHistory.clear();
  }

  /// Main Dispatcher
  static ReasoningQuestion generate(String category) {
    for (int attempts = 0; attempts < 150; attempts++) {
      ReasoningQuestion q = _buildQuestionForCategory(category);

      final sig = '${q.category}:${q.type}:${q.puzzle}:${q.correctIndex}:${q.options}';
      if (_sessionHistory.add(sig)) {
        return q;
      }
    }
    return _buildQuestionForCategory(category);
  }

  static ReasoningQuestion _buildQuestionForCategory(String category) {
    switch (category) {
      case 'odd_man':
        return _generateDenseMultiLayerOddMan();
      case 'pattern':
        return _generateSandia3LayerMatrix();
      case 'figure_series':
        return _generateDenseMultiLayerSeries();
      case 'analogy':
        return _generateDenseMultiLayerAnalogy();
      default:
        return _generateDenseMultiLayerOddMan();
    }
  }

  // ===========================================================================
  // 1. DENSE MULTI-LAYER ODD MAN OUT GENERATOR
  // ===========================================================================

  /// Renders 3-4 overlapping layers per option.
  /// Rule: 3 options obey exact layer-dependency invariants (e.g. Layer 2 is
  /// rotated 180° relative to Layer 1, and Layer 3 has matching lines).
  /// 1 odd option breaks ONE subtle layer attribute.
  static ReasoningQuestion _generateDenseMultiLayerOddMan() {
    final oddIndex = _r.nextInt(4);
    final options = <Map<String, dynamic>>[];

    // Pick 3 surfaces for the composite stack
    final bgSurface = [0, 2, 6][_r.nextInt(3)];   // Trapezoid / Rectangle / Inv-Trapezoid
    final midSurface = [1, 3][_r.nextInt(2)];     // Oval / Diamond
    final fgSurface = [4, 5][_r.nextInt(2)];      // Triangle / Tee

    final baseRot = _r.nextInt(4);
    final bgFill = _r.nextInt(2) + 1; // Grey10 or Grey40
    final fgFill = _r.nextInt(2) + 2; // Grey40 or Black

    for (int i = 0; i < 4; i++) {
      final curRot = (baseRot + i) % 4;
      if (i == oddIndex) {
        // Odd option: Layer 3 has WRONG rotation offset or WRONG fill
        options.add({
          'type': 'sandia_cell',
          'layers': [
            {
              'surface': bgSurface,
              'fill': bgFill,
              'scale': 2.2,
              'rotation': curRot,
              'grid_box': true,
              'lines': 0,
            },
            {
              'surface': midSurface,
              'fill': 0, // White
              'scale': 1.5,
              'rotation': curRot,
              'lines': 1,
            },
            {
              'surface': fgSurface,
              'fill': fgFill,
              'scale': 1.0,
              'rotation': (curRot + 1) % 4, // TRAP: Rotated 90° out of phase!
              'lines': 2,
            },
          ],
        });
      } else {
        // Normal 3 options: All layers maintain perfect phase alignment
        options.add({
          'type': 'sandia_cell',
          'layers': [
            {
              'surface': bgSurface,
              'fill': bgFill,
              'scale': 2.2,
              'rotation': curRot,
              'grid_box': true,
              'lines': 0,
            },
            {
              'surface': midSurface,
              'fill': 0, // White
              'scale': 1.5,
              'rotation': curRot,
              'lines': 1,
            },
            {
              'surface': fgSurface,
              'fill': fgFill,
              'scale': 1.0,
              'rotation': curRot, // In-phase
              'lines': 2,
            },
          ],
        });
      }
    }

    return ReasoningQuestion(
      category: 'odd_man',
      type: 'odd_man_dense_multilayer',
      puzzle: {'type': 'odd_man'},
      options: options,
      correctIndex: oddIndex,
    );
  }

  // ===========================================================================
  // 2. SANDIA 3-LAYER MATRIX GENERATOR (Matching Reference Image Exact Style)
  // ===========================================================================

  /// Renders a full 3x3 Sandia matrix with 3 stacked layers per cell:
  /// Layer 1: Outer Trapezoid/Rectangle (Horizontal Progression)
  /// Layer 2: Middle Oval/Diamond (Grayscale Shade Progression across columns)
  /// Layer 3: Inner Triangle/Tee (Diagonal Rotation + Bisector Lines)
  static ReasoningQuestion _generateSandia3LayerMatrix() {
    final layer1Surfaces = [0, 2, 6]..shuffle(_r); // Backgrounds
    final layer2Surfaces = [1, 3, 1]..shuffle(_r); // Middle
    final layer3Surfaces = [4, 5, 4]..shuffle(_r); // Foreground

    final cells = <Map<String, dynamic>>[];

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (r == 2 && c == 2) {
          cells.add({'empty': true}); // Cell #8 missing
        } else {
          cells.add(_buildDense3LayerCell(
            r, c,
            layer1Surfaces,
            layer2Surfaces,
            layer3Surfaces,
          ));
        }
      }
    }

    // Exact Correct missing cell at (Row 2, Col 2)
    final correctOption = _buildDense3LayerCell(
      2, 2,
      layer1Surfaces,
      layer2Surfaces,
      layer3Surfaces,
    );

    // Sandia MPS Distractors (Maximal Proper Subsets)
    // Every distractor looks almost identical and has 3 layers, but misses 1 layer rule!
    final d1 = _buildDense3LayerCell(2, 2, layer1Surfaces, layer2Surfaces, layer3Surfaces);
    ((d1['layers'] as List)[0] as Map)['surface'] = layer1Surfaces[0]; // Wrong Background

    final d2 = _buildDense3LayerCell(2, 2, layer1Surfaces, layer2Surfaces, layer3Surfaces);
    ((d2['layers'] as List)[1] as Map)['fill'] = 3; // Wrong Middle Shade (Black instead of Grey)

    final d3 = _buildDense3LayerCell(2, 2, layer1Surfaces, layer2Surfaces, layer3Surfaces);
    ((d3['layers'] as List)[2] as Map)['rotation'] = 0; // Wrong Foreground Rotation

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
    // Layer 1: Background Surface
    final l1 = {
      'surface': l1Surfaces[r % 3],
      'fill': (r == 0) ? 2 : (r == 1 ? 3 : 1), // Grey40, Black, Grey10
      'scale': 2.2,
      'rotation': 0,
      'grid_box': true,
      'lines': (c == 0) ? 0 : 2,
    };

    // Layer 2: Middle Enclosing Oval/Diamond
    final l2 = {
      'surface': l2Surfaces[(r + c) % 3],
      'fill': (c == 0) ? 0 : (c == 1 ? 1 : 2), // White -> Grey10 -> Grey40
      'scale': 1.5,
      'rotation': 0,
      'lines': 0,
    };

    // Layer 3: Foreground Acute Core
    final l3 = {
      'surface': l3Surfaces[c % 3],
      'fill': (r == c) ? 3 : 0, // Black if on diagonal, else White
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
  // 3. HARD DENSE FIGURE SERIES & ANALOGY
  // ===========================================================================

  static ReasoningQuestion _generateDenseMultiLayerSeries() {
    final seq = [
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': 0, 'fill': 1, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
          {'surface': 1, 'fill': 0, 'scale': 1.5, 'rotation': 0},
          {'surface': 4, 'fill': 3, 'scale': 1.0, 'rotation': 0, 'lines': 1},
        ],
      },
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': 0, 'fill': 2, 'scale': 2.2, 'rotation': 1, 'grid_box': true},
          {'surface': 1, 'fill': 1, 'scale': 1.5, 'rotation': 1},
          {'surface': 4, 'fill': 2, 'scale': 1.0, 'rotation': 1, 'lines': 2},
        ],
      },
      {
        'type': 'sandia_cell',
        'layers': [
          {'surface': 0, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
          {'surface': 1, 'fill': 2, 'scale': 1.5, 'rotation': 2},
          {'surface': 4, 'fill': 1, 'scale': 1.0, 'rotation': 2, 'lines': 3},
        ],
      },
    ];

    final correctOption = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 0, 'fill': 1, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 3},
        {'surface': 4, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };

    final d1 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 0, 'fill': 1, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 3},
        {'surface': 4, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };
    final d2 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 0, 'fill': 1, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 1, 'scale': 1.5, 'rotation': 3},
        {'surface': 4, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
      ],
    };
    final d3 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 0, 'fill': 3, 'scale': 2.2, 'rotation': 3, 'grid_box': true},
        {'surface': 1, 'fill': 3, 'scale': 1.5, 'rotation': 0},
        {'surface': 4, 'fill': 0, 'scale': 1.0, 'rotation': 3, 'lines': 0},
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
    final figA = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 4, 'fill': 0, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 1, 'fill': 1, 'scale': 1.2, 'rotation': 0},
      ],
    };
    final figB = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 4, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 1, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final figC = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 3, 'fill': 0, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 2, 'fill': 1, 'scale': 1.2, 'rotation': 0},
      ],
    };

    // Rule: Rotate all layers 180° + Invert Grayscale Shades
    final correctOption = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 3, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };

    final d1 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 3, 'fill': 0, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final d2 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 3, 'fill': 3, 'scale': 2.2, 'rotation': 0, 'grid_box': true},
        {'surface': 2, 'fill': 2, 'scale': 1.2, 'rotation': 2},
      ],
    };
    final d3 = {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 3, 'fill': 3, 'scale': 2.2, 'rotation': 2, 'grid_box': true},
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