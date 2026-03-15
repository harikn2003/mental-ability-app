import 'dart:math';

import 'reasoning_question.dart';

/// QuestionGenerator
/// Robust question generation with high-fidelity deduplication and symmetry-aware logic.
class QuestionGenerator {
  static final _r = Random();

  // Shapes: 0=circle 1=square 2=triangle 3=diamond 4=cross 5=pentagon 6=hexagon 7=arrow 8=L-shape
  static const _highlyAsymmetric = [2, 7, 8];
  static const _polygons = [1, 2, 5, 6];
  static const _nonCircle = [1, 2, 3, 4, 5, 6, 7, 8];

  // ── Question History ──────────────────────────────────────────────────────
  static final Set<String> _history = {};
  static const int _maxHistory = 100;

  static bool _seen(String sig) => _history.contains(sig);

  static void _markSeen(String sig) {
    _history.add(sig);
    if (_history.length > _maxHistory) _history.remove(_history.first);
  }

  static String _qSig(ReasoningQuestion q) =>
      '${q.category}:${q.type}:${q.puzzle.toString()}';

  static ReasoningQuestion generate(String category) {
    for (int attempt = 0; attempt < 50; attempt++) {
      final q = _generateRaw(category);
      final sig = _qSig(q);
      if (!_seen(sig)) {
        _markSeen(sig);
        return q;
      }
    }
    return _generateRaw(category);
  }

  static ReasoningQuestion _generateRaw(String category) {
    switch (category) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'pattern':
        final v = _r.nextInt(3);
        if (v == 0) return _matrixShapeCycle();
        if (v == 1) return _matrixDotRotation();
        return _matrixLogic();
      case 'figure_series':
        final v = _r.nextInt(3);
        if (v == 0) return _seriesRotation();
        if (v == 1) return _seriesDots();
        return _seriesFillToggle();
      case 'analogy':
        return _analogy();
      case 'geo_completion':
        return _matrixShapeCycle();
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

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Map<String, dynamic> _f(
    int shape, {
    bool filled = false,
    int rot = 0,
    bool mirror = false,
    int dots = 0,
    int inner = 0,
    int lines = 0,
    int missingCorner = 0,
    bool isPiece = false,
  }) => {
    'shape': shape,
    'filled': filled,
    'rotation': rot,
    'mirror': mirror,
    'dots': dots,
    'inner': inner,
    'lines': lines,
    'missingCorner': missingCorner,
    'isPiece': isPiece,
  };

  /// Returns a string that uniquely identifies the VISUAL state of a figure.
  static String _key(Map<String, dynamic> m) {
    if (m.containsKey('holes')) {
      final holes =
          (m['holes'] as List)
              .map(
                (h) =>
                    '${(h['x'] as num).toStringAsFixed(2)},${(h['y'] as num).toStringAsFixed(2)}',
              )
              .toList()
            ..sort();
      return 'punch:${holes.join('|')}';
    }
    if (m.containsKey('content')) {
      String char = m['content'] ?? '';
      bool h = m['mirror_h'] ?? false;
      bool v = m['mirror_v'] ?? false;
      if (['S', 'Z', 'N', '2', '5'].contains(char)) {
        if (h && v) return 'txt:$char|none';
        if (h || v) return 'txt:$char|flipped';
        return 'txt:$char|none';
      }
      if (['H', 'I', 'O', 'X', '8', '0'].contains(char))
        return 'txt:$char|symmetric';
      return 'txt:$char|h:$h|v:$v';
    }

    int s = m['shape'] ?? 0;
    int r = m['rotation'] ?? 0;
    bool mir = m['mirror'] ?? false;
    int inner = m['inner'] ?? 0;
    int lines = m['lines'] ?? 0;
    int missing = m['missingCorner'] ?? 0;
    int dots = m['dots'] ?? 0;
    bool isP = m['isPiece'] ?? false;

    if (inner == 0 && lines == 0 && missing == 0 && dots == 0) {
      if (s == 0 || s == 1 || s == 4) {
        r = 0;
        mir = false;
      } else if (s == 3 || s == 6) {
        r = r % 2;
        mir = false;
      } else if (s == 7) {
        if (mir) {
          mir = false;
          r = (r + 2) % 4;
        }
      }
    }
    return 's:$s|f:${m['filled']}|r:$r|m:$mir|d:$dots|i:$inner|l:$lines|mc:$missing|p:$isP';
  }

  static ({List<Map<String, dynamic>> opts, int idx}) _pack(
    Map<String, dynamic> correct,
    List<Map<String, dynamic>> wrongs,
  ) {
    final List<Map<String, dynamic>> finalOpts = [];
    final Set<String> seenKeys = {};

    void addIfUnique(Map<String, dynamic> m) {
      if (finalOpts.length >= 4) return;
      final k = _key(m);
      if (!seenKeys.contains(k)) {
        finalOpts.add(m);
        seenKeys.add(k);
      }
    }

    addIfUnique(correct);
    for (var w in wrongs) addIfUnique(w);

    int safety = 0;
    while (finalOpts.length < 4 && safety < 100) {
      safety++;
      final fallback = _f(
        _nonCircle[_r.nextInt(_nonCircle.length)],
        rot: _r.nextInt(4),
        filled: _r.nextBool(),
        dots: _r.nextInt(4),
        mirror: _r.nextBool(),
      );
      addIfUnique(fallback);
    }

    final correctKey = _key(correct);
    finalOpts.shuffle(_r);
    final newIdx = finalOpts.indexWhere((o) => _key(o) == correctKey);
    return (opts: finalOpts, idx: newIdx);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. ODD MAN OUT - FIXED: NEVER identical options, always unique orientations
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion _oddMan() {
    for (int attempt = 0; attempt < 30; attempt++) {
      final v = _r.nextInt(6);
      List<Map<String, dynamic>> opts = [];
      int oddIdx = _r.nextInt(4);
      final rots = [0, 1, 2, 3]..shuffle(_r);
      final s = _nonCircle[_r.nextInt(_nonCircle.length)];

      switch (v) {
        case 0: // Chirality Logic (3 same orientation, 1 mirrored)
          final shape = 8; // L-shape
          for (int i = 0; i < 4; i++) {
            opts.add(_f(shape, rot: rots[i], mirror: i == oddIdx));
          }
          break;

        case 1: // Rotation sequence (3 follow rule, 1 breaks)
          final shape = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
          final start = _r.nextInt(4);
          for (int i = 0; i < 4; i++) {
            int r = (start + i) % 4;
            if (i == oddIdx) r = (r + 2) % 4;
            opts.add(_f(shape, rot: r));
          }
          break;

        case 2: // Side count math (Dots = Sides)
          final poly = _polygons[_r.nextInt(_polygons.length)];
          int sides(int s) => s == 1 ? 4 : (s == 2 ? 3 : (s == 5 ? 5 : 6));
          for (int i = 0; i < 4; i++) {
            int d = sides(poly);
            if (i == oddIdx) d = (d == 3) ? 4 : 3;
            opts.add(_f(poly, rot: rots[i], dots: d));
          }
          break;

        case 3: // Property match (3 same fill, 1 flip)
          final fill = _r.nextBool();
          for (int i = 0; i < 4; i++) {
            opts.add(_f(s, rot: rots[i], filled: i == oddIdx ? !fill : fill));
          }
          break;

        case 4: // Missing Corner (3 same corner, 1 different)
          final shape = 1; // Square
          final baseM = _r.nextInt(4) + 1;
          for (int i = 0; i < 4; i++) {
            int m = baseM;
            if (i == oddIdx)
              do {
                m = _r.nextInt(4) + 1;
              } while (m == baseM);
            opts.add(_f(shape, rot: rots[i], missingCorner: m));
          }
          break;

        default: // Dot count (3 same count, 1 different)
          final baseD = _r.nextInt(2) + 1;
          for (int i = 0; i < 4; i++) {
            int d = baseD;
            if (i == oddIdx) d = baseD + 2;
            opts.add(_f(s, rot: rots[i], dots: d));
          }
      }

      // FINAL VETO: Are all 4 options visually unique?
      if (opts.map(_key).toSet().length == 4) {
        return ReasoningQuestion(
          category: 'odd_man',
          type: 'odd_v$v',
          puzzle: {'type': 'odd_man'},
          options: opts,
          correctIndex: oddIdx,
        );
      }
    }
    return _oddMan(); // Retry on failure
  }

  // 2. FIGURE MATCH
  static ReasoningQuestion _figureMatch() {
    final s = _nonCircle[_r.nextInt(_nonCircle.length)];
    final r = _r.nextInt(4);
    final f = _r.nextBool();
    final d = _r.nextInt(3);
    final target = _f(s, rot: r, filled: f, dots: d);
    final res = _pack(target, [
      _f(s, rot: (r + 1) % 4, filled: f, dots: d),
      _f(s, rot: r, filled: !f, dots: d),
      _f(s, rot: r, filled: f, dots: (d + 1) % 4),
      _f(
        _nonCircle[(_nonCircle.indexOf(s) + 1) % _nonCircle.length],
        rot: r,
        filled: f,
        dots: d,
      ),
    ]);
    return ReasoningQuestion(
      category: 'figure_match',
      type: 'fig_match',
      puzzle: {'type': 'figure_match', 'target': target},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 3. PATTERN
  static ReasoningQuestion _matrixShapeCycle() {
    final shapes = _nonCircle.toList()..shuffle(_r);
    final s1 = shapes[0], s2 = shapes[1], s3 = shapes[2];
    final grid = [s1, s2, s3, s2, s3, s1, s3, s1, s2];
    final cells = List.generate(9, (i) => _f(grid[i], dots: (i % 3)));
    final ans = cells[8];
    final res = _pack(ans, [cells[0], cells[1], cells[2], cells[3]]);
    final display = List<Map<String, dynamic>>.from(cells)
      ..[8] = {'empty': true};
    return ReasoningQuestion(
      category: 'pattern',
      type: 'mat_cycle',
      puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  static ReasoningQuestion _matrixDotRotation() {
    final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    final br = _r.nextInt(4);
    final cells = List.generate(
      9,
      (i) => _f(s, rot: (br + (i % 3)) % 4, dots: (i ~/ 3) + 1),
    );
    final ans = cells[8];
    final res = _pack(ans, [cells[7], cells[5], cells[0], cells[1]]);
    final display = List<Map<String, dynamic>>.from(cells)
      ..[8] = {'empty': true};
    return ReasoningQuestion(
      category: 'pattern',
      type: 'mat_dot',
      puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  static ReasoningQuestion _matrixLogic() {
    final s = _r.nextInt(4) + 1;
    final cells = List.generate(
      9,
      (i) => _f(s, dots: (i % 3) + 1, filled: (i ~/ 3) == 1),
    );
    final ans = cells[8];
    final res = _pack(ans, [cells[0], cells[3], cells[6], cells[1]]);
    final display = List<Map<String, dynamic>>.from(cells)
      ..[8] = {'empty': true};
    return ReasoningQuestion(
      category: 'pattern',
      type: 'mat_logic',
      puzzle: {'type': 'matrix', 'cells': display, 'missing': 8},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 4. SERIES
  static ReasoningQuestion _seriesRotation() {
    final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    final st = _r.nextInt(4);
    final seq = List.generate(3, (i) => _f(s, rot: (st + i) % 4));
    final ans = _f(s, rot: (st + 3) % 4);
    final res = _pack(ans, [
      _f(s, rot: st),
      _f(s, rot: (st + 1) % 4),
      _f(s, rot: (st + 2) % 4),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'ser_rot',
      puzzle: {'type': 'series', 'sequence': seq},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  static ReasoningQuestion _seriesDots() {
    final s = _r.nextInt(4) + 1;
    final seq = List.generate(3, (i) => _f(s, dots: i + 1));
    final ans = _f(s, dots: 4);
    final res = _pack(ans, [_f(s, dots: 1), _f(s, dots: 2), _f(s, dots: 3)]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'ser_dots',
      puzzle: {'type': 'series', 'sequence': seq},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  static ReasoningQuestion _seriesFillToggle() {
    final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    final seq = List.generate(3, (i) => _f(s, filled: i.isEven));
    final ans = _f(s, filled: false);
    final res = _pack(ans, [
      _f(s, filled: true),
      _f(s, dots: 1),
      _f(s, rot: 1),
    ]);
    return ReasoningQuestion(
      category: 'figure_series',
      type: 'ser_fill',
      puzzle: {'type': 'series', 'sequence': seq},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 5. ANALOGY
  static ReasoningQuestion _analogy() {
    final s1 = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    int s2;
    do {
      s2 = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    } while (s2 == s1);
    final a = _f(s1, rot: 0, filled: false);
    final b = _f(s1, rot: 1, filled: true);
    final c = _f(s2, rot: 0, filled: false);
    final d = _f(s2, rot: 1, filled: true);
    final res = _pack(d, [
      _f(s2, rot: 0, filled: false),
      _f(s2, rot: 2, filled: true),
      _f(s1, rot: 1, filled: true),
    ]);
    return ReasoningQuestion(
      category: 'analogy',
      type: 'analogy',
      puzzle: {'type': 'analogy', 'A': a, 'B': b, 'C': c},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 7. MIRROR SHAPE
  static ReasoningQuestion _mirrorShape() {
    final s = _highlyAsymmetric[_r.nextInt(_highlyAsymmetric.length)];
    final r = _r.nextInt(4);
    final f = _r.nextBool();
    final d = _r.nextInt(3);
    final target = _f(s, rot: r, filled: f, dots: d, mirror: false);
    final ans = _f(s, rot: r, filled: f, dots: d, mirror: true);
    final res = _pack(ans, [
      _f(s, rot: r, filled: f, dots: d, mirror: false),
      _f(s, rot: (r + 2) % 4, filled: f, dots: d, mirror: false),
      _f(s, rot: (r + 1) % 4, filled: !f, dots: d, mirror: false),
    ]);
    return ReasoningQuestion(
      category: 'mirror_shape',
      type: 'mirror_s',
      puzzle: {'type': 'mirror_shape', 'target': target},
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 8. MIRROR TEXT
  static ReasoningQuestion _mirrorText() {
    const chars = [
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'J',
      'K',
      'L',
      'P',
      'Q',
      'R',
      'S',
      'Z',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '9',
    ];
    final char = chars[_r.nextInt(chars.length)];
    final base = {'content': char, 'is_clock': false};
    Map<String, dynamic> mk(bool h, bool v) => {
      ...base,
      'type': 'mirror_text',
      'mirror_h': h,
      'mirror_v': v,
    };
    final res = _pack(mk(true, false), [
      mk(false, false),
      mk(false, true),
      mk(true, true),
    ]);
    return ReasoningQuestion(
      category: 'mirror_text',
      type: 'mirror_t',
      puzzle: {
        ...base,
        'type': 'mirror_text',
        'mirror_h': false,
        'mirror_v': false,
      },
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 9. PUNCH HOLE
  static ReasoningQuestion _punchHole() {
    final bool isDoubleFold = _r.nextBool();
    final hx = 0.2 + _r.nextDouble() * 0.2;
    final hy = 0.2 + _r.nextDouble() * 0.2;
    final hole = {'x': hx, 'y': hy};
    final int foldAxis = isDoubleFold ? 2 : _r.nextInt(2);

    List<Map<String, double>> unfold(double x, double y, int axis) {
      if (axis == 2)
        return [
          {'x': x, 'y': y},
          {'x': 1 - x, 'y': y},
          {'x': x, 'y': 1 - y},
          {'x': 1 - x, 'y': 1 - y},
        ];
      if (axis == 0)
        return [
          {'x': x, 'y': y},
          {'x': 1 - x, 'y': y},
        ];
      return [
        {'x': x, 'y': y},
        {'x': x, 'y': 1 - y},
      ];
    }

    final ansHoles = unfold(hx, hy, foldAxis);
    final ans = {'type': 'punch_hole', 'unfolded': true, 'holes': ansHoles};
    final wrongs = [
      {
        'type': 'punch_hole',
        'unfolded': true,
        'holes': [
          {'x': hx, 'y': hy},
        ],
      },
      {
        'type': 'punch_hole',
        'unfolded': true,
        'holes': unfold(hx, hy, foldAxis == 2 ? 0 : 2),
      },
      {
        'type': 'punch_hole',
        'unfolded': true,
        'holes': unfold(hx, hy, foldAxis == 0 ? 1 : 0),
      },
    ];
    final res = _pack(ans, wrongs);
    return ReasoningQuestion(
      category: 'punch_hole',
      type: 'punch',
      puzzle: {
        'type': 'punch_hole',
        'folded': true,
        'fold_axis': foldAxis,
        'holes': [hole],
      },
      options: res.opts,
      correctIndex: res.idx,
    );
  }

  // 10. EMBEDDED FIGURE
  static ReasoningQuestion _embedded() {
    final s = _nonCircle[_r.nextInt(_nonCircle.length)];
    final target = _f(s);
    final ans = _f(s, lines: 2);
    final otherShapes = _nonCircle.where((x) => x != s).toList()..shuffle(_r);
    final res = _pack(ans, [
      _f(otherShapes[0], lines: 2),
      _f(otherShapes[1], lines: 3),
      _f(otherShapes[2], lines: 2),
    ]);
    return ReasoningQuestion(
      category: 'embedded',
      type: 'embed',
      puzzle: {'type': 'embedded', 'target': target},
      options: res.opts,
      correctIndex: res.idx,
    );
  }
}
