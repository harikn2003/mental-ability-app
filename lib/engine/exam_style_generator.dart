import 'dart:math';

import 'line_figure.dart';
import 'reasoning_question.dart';

/// Exam-style Hard Mode items, modelled on the real JNVST papers in docs/
/// (2024 paper + Arihant's JNV 2003-2019 past questions): grid-based line
/// figures for Geometrical Completion, Embedded Figure, Pattern Completion,
/// Figure Matching and Mirror Image.
///
/// ANSWER SETS: every item uses a *balanced* answer set - two independent
/// changes, all four combinations - following the "context-blind" finding
/// in Yang et al. 2021 (docs/2201.08450v1.pdf, §3.3): when every wrong
/// answer is a one-change variant of the right one, the right one is the
/// option "most similar to all the others" and can be picked without
/// looking at the question. In a 2x2 set no option is central.
class ExamStyleGenerator {
  static Random _r = Random();

  static void seed(int s) => _r = Random(s);

  static T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  /// Places [correct] at a random index among the 3 [wrongs].
  static ReasoningQuestion _question(String category, String type, Map<String, dynamic> puzzle,
      Map<String, dynamic> correct, List<Map<String, dynamic>> wrongs) {
    assert(wrongs.length == 3);
    final idx = _r.nextInt(4);
    return ReasoningQuestion(
      category: category,
      type: type,
      puzzle: puzzle,
      options: [...wrongs.sublist(0, idx), correct, ...wrongs.sublist(idx)],
      correctIndex: idx,
    );
  }

  static const _dirs8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)];

  /// A connected stroke figure: [count] unit segments grown from a random
  /// point inside a w x h lattice, mixing straight and diagonal steps.
  static Set<(int, int, int, int)> _strokes(int w, int h, int count, {bool diagonals = true}) {
    final segs = <(int, int, int, int)>{};
    final pts = <(int, int)>[(_r.nextInt(w + 1), _r.nextInt(h + 1))];
    final dirs = diagonals ? _dirs8 : _dirs8.sublist(0, 4);
    for (int guard = 0; segs.length < count && guard < 200; guard++) {
      final (x, y) = _pick(pts);
      final (dx, dy) = _pick(dirs);
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx > w || ny > h) continue;
      // Two diagonals crossing mid-cell read as an X, not as strokes; allow
      // it (the exam uses X's too) but never duplicate a segment.
      if (segs.add(LineFig.line(x, y, nx, ny).first)) pts.add((nx, ny));
    }
    return segs;
  }

  static bool _fullyAsymmetric(LineFig f) => f.dihedral().map((g) => g.key).toSet().length == 8;

  // ═══════════════════════════════════════════════════════════════════════════
  // GEOMETRICAL FIGURE COMPLETION
  // A square with an irregular piece cut out of it (as in JNV 2003-2019:
  // stepped / notched pieces); the answer pieces are shown turned, so the
  // piece has to be turned mentally to fit. Pieces can't be flipped over.
  // Answer set: {piece, mirror-image piece} x {as is, one cell moved}.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion? geoCompletion() {
    const n = 4;
    final all = {for (int x = 0; x < n; x++) for (int y = 0; y < n; y++) (x, y)};
    List<(int, int)> nbrs((int, int) c) => [(c.$1 + 1, c.$2), (c.$1 - 1, c.$2), (c.$1, c.$2 + 1), (c.$1, c.$2 - 1)];
    bool connected(Set<(int, int)> s) {
      if (s.isEmpty) return false;
      final seen = {s.first};
      final todo = [s.first];
      while (todo.isNotEmpty) {
        for (final m in nbrs(todo.removeLast())) {
          if (s.contains(m) && seen.add(m)) todo.add(m);
        }
      }
      return seen.length == s.length;
    }

    bool isRect(Set<(int, int)> s) {
      final xs = s.map((c) => c.$1), ys = s.map((c) => c.$2);
      return (xs.reduce(max) - xs.reduce(min) + 1) * (ys.reduce(max) - ys.reduce(min) + 1) == s.length;
    }

    LineFig piece(Set<(int, int)> cells) => LineFig(n, n, cells: cells, segs: LineFig.cellBoundary(cells)).normalized();

    /// Move one cell of [p] somewhere else along its edge, keeping it one piece.
    Set<(int, int)>? moveOneCell(Set<(int, int)> p, Set<String> avoid) {
      final removable = p.toList()..shuffle(_r);
      for (final c in removable) {
        final rest = {...p}..remove(c);
        if (!connected(rest)) continue;
        final adds = {for (final q in rest) ...nbrs(q)}.where((q) => all.contains(q) && !p.contains(q)).toList()..shuffle(_r);
        for (final a in adds) {
          final cand = {...rest, a};
          if (isRect(cand) || !connected(all.difference(cand))) continue;
          if (!avoid.contains(piece(cand).rotationClassKey)) return cand;
        }
      }
      return null;
    }

    for (int attempt = 0; attempt < 200; attempt++) {
      final size = 4 + _r.nextInt(3); // 4-6 of the 16 cells
      final border = all.where((c) => c.$1 == 0 || c.$2 == 0 || c.$1 == n - 1 || c.$2 == n - 1).toList();
      final p = {_pick(border)};
      while (p.length < size) {
        final grow = {for (final c in p) ...nbrs(c)}.where((q) => all.contains(q) && !p.contains(q)).toList();
        p.add(_pick(grow));
      }
      final rest = all.difference(p);
      if (isRect(p) || !connected(rest)) continue;

      final correct = piece(p);
      final seen = {correct.rotationClassKey};
      final mirrored = correct.mirrorX();
      final chiral = seen.add(mirrored.rotationClassKey);

      // Second change: mirror image if the piece has one, else another move.
      final moved = moveOneCell(p, seen);
      if (moved == null) continue;
      seen.add(piece(moved).rotationClassKey);
      late final LineFig b, ab;
      if (chiral) {
        b = mirrored;
        ab = piece(moved).mirrorX();
      } else {
        final moved2 = moveOneCell(p, seen);
        if (moved2 == null) continue;
        b = piece(moved2);
        final both = moveOneCell(moved2, {...seen, b.rotationClassKey});
        if (both == null) continue;
        ab = piece(both);
      }
      final options = [correct, b, piece(moved), ab];
      if (options.map((o) => o.rotationClassKey).toSet().length != 4) continue;

      // Show every piece turned by a random amount (the real papers do), all
      // on the square's own 4x4 scale so sizes can be compared.
      final shown = [
        for (final o in options)
          () {
            final g = o.rot(_r.nextInt(4)).normalized();
            return {...g.shift(0, 0, n, n).toMap(), 'center': true};
          }(),
      ];
      final question = LineFig(n, n, cells: rest, segs: LineFig.cellBoundary(rest));
      return _question('geo_completion', 'geo_grid_cut', {'type': 'geo_completion', 'piece': question.toMap()},
          shown[0], shown.sublist(1));
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMBEDDED FIGURE
  // A small line figure hidden inside dense line drawings (JNV 2013-2019
  // style: grids, diagonals, diamonds). Every option hides a version of it;
  // only one hides it as shown - the others hide it flipped and/or turned.
  // Answer set: {as shown, mirrored} x {as shown, turned 90°}.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion? embeddedFigure() {
    const n = 4;
    final structures = <Set<(int, int, int, int)>>[
      {...LineFig.line(0, 0, 4, 0), ...LineFig.line(4, 0, 4, 4), ...LineFig.line(4, 4, 0, 4), ...LineFig.line(0, 4, 0, 0)}, // frame
      {...LineFig.line(0, 0, 4, 4), ...LineFig.line(4, 0, 0, 4)}, // both diagonals
      {...LineFig.line(2, 0, 2, 4), ...LineFig.line(0, 2, 4, 2)}, // cross
      {...LineFig.line(2, 0, 4, 2), ...LineFig.line(4, 2, 2, 4), ...LineFig.line(2, 4, 0, 2), ...LineFig.line(0, 2, 2, 0)}, // diamond
      {...LineFig.line(1, 0, 1, 4), ...LineFig.line(3, 0, 3, 4)}, // two verticals
      {...LineFig.line(0, 1, 4, 1), ...LineFig.line(0, 3, 4, 3)}, // two horizontals
    ];

    for (int attempt = 0; attempt < 200; attempt++) {
      final t = LineFig(2, 2, segs: _strokes(2, 2, 3 + _r.nextInt(2))).normalized();
      if (t.w < 1 || t.h < 1 || !_fullyAsymmetric(t)) continue;
      if (!t.segs.any((s) => s.$1 != s.$3 && s.$2 != s.$4) || t.segs.every((s) => s.$1 != s.$3 && s.$2 != s.$4)) {
        continue; // mix of straight and diagonal strokes
      }
      final variants = [t, t.mirrorX(), t.rot90(), t.mirrorX().rot90()];

      LineFig? host(LineFig v, bool mustEmbed) {
        for (int k = 0; k < 40; k++) {
          final vn = v.normalized();
          final dx = _r.nextInt(n - vn.w + 1), dy = _r.nextInt(n - vn.h + 1);
          final placed = vn.shift(dx, dy, n, n).segs;
          final base = (List.of(structures)..shuffle(_r)).take(2).expand((s) => s).toSet();
          final f = LineFig(n, n, segs: {...base, ...placed, ..._strokes(n, n, 2 + _r.nextInt(3))});
          // The hidden figure must not be a trivial copy of the structure
          // (at least one of its strokes is not part of the base lines)...
          if (placed.every(base.contains)) continue;
          // ...and only the correct option may contain the target as shown.
          if (f.embeds(t) == mustEmbed) return f;
        }
        return null;
      }

      final hosts = [for (int i = 0; i < 4; i++) host(variants[i], i == 0)];
      if (hosts.any((h) => h == null)) continue;
      if (hosts.map((h) => h!.key).toSet().length != 4) continue;
      return _question('embedded', 'embedded_line', {'type': 'embedded', 'target': t.toMap()}, hosts[0]!.toMap(),
          [for (final h in hosts.skip(1)) h!.toMap()]);
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PATTERN COMPLETION
  // A square design made of four quarters with mirror or turn symmetry; one
  // quarter is missing (JNVST Part 3, "without changing the direction").
  // Answer set: {correct transform, wrong kind of transform} x {as is, one
  // detail changed}. Options deliberately never equal a visible quarter -
  // otherwise "the one option not shown in the puzzle" gives it away.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion? patternQuarter() {
    for (int attempt = 0; attempt < 200; attempt++) {
      final tri = _r.nextBool() ? {(_r.nextInt(2), _r.nextInt(2), _r.nextInt(4))} : <(int, int, int)>{};
      final t = LineFig(2, 2, segs: _strokes(2, 2, 3 + _r.nextInt(3)), tris: tri, dots: _r.nextBool() ? {(_r.nextInt(2), _r.nextInt(2))} : {});
      if (!_fullyAsymmetric(t)) continue;

      final mirrorDesign = _r.nextBool();
      // Quarters in reading order TL, TR, BL, BR.
      final tiles = mirrorDesign
          ? [t, t.mirrorX(), t.mirrorY(), t.mirrorX().mirrorY()]
          : [t, t.rot(1), t.rot(3), t.rot(2)];
      final missing = _r.nextInt(4);
      final correct = tiles[missing];
      final visible = {for (int i = 0; i < 4; i++) if (i != missing) tiles[i].key};

      // Wrong kind of transform: a quarter turn in a mirror design, a flip in
      // a turn design - either way outside the design's own symmetry.
      final LineFig Function(LineFig) wrong = mirrorDesign
          ? (_r.nextBool() ? (g) => g.rot(1) : (g) => g.rot(3))
          : (_r.nextBool() ? (g) => g.mirrorX() : (g) => g.mirrorY());
      final d = _changeOneDetail(correct);
      if (d == null) continue;
      final opts = [correct, wrong(correct), d, wrong(d)];
      if (opts.map((o) => o.key).toSet().length != 4) continue;
      if (opts.skip(1).any((o) => visible.contains(o.key))) continue;

      return _question('pattern', 'pattern_quarter', {
        'type': 'quad_pattern',
        'tiles': [for (int i = 0; i < 4; i++) i == missing ? null : tiles[i].toMap()],
        'missing': missing,
      }, correct.toMap(), [for (final o in opts.skip(1)) o.toMap()]);
    }
    return null;
  }

  /// One small, clearly visible change to a figure: move a dot, flip which
  /// half of a cell is black, or drop / add a stroke.
  static LineFig? _changeOneDetail(LineFig f, {Set<String> kinds = const {'dot', 'tri', 'seg'}}) {
    final options = <LineFig Function()>[];
    if (kinds.contains('dot') && f.dots.isNotEmpty) {
      options.add(() {
        final d = _pick(f.dots.toList());
        final moves = [(d.$1 + 1, d.$2), (d.$1 - 1, d.$2), (d.$1, d.$2 + 1), (d.$1, d.$2 - 1)]
            .where((c) => c.$1 >= 0 && c.$2 >= 0 && c.$1 < f.w && c.$2 < f.h && !f.dots.contains(c))
            .toList();
        return moves.isEmpty ? f : f.copyWith(dots: {...f.dots}..remove(d)..add(_pick(moves)));
      });
    }
    if (kinds.contains('tri') && f.tris.isNotEmpty) {
      options.add(() {
        final t = _pick(f.tris.toList());
        return f.copyWith(tris: {...f.tris}..remove(t)..add((t.$1, t.$2, (t.$3 + 2) % 4)));
      });
    }
    if (kinds.contains('seg') && f.segs.length > 3) {
      options.add(() => f.copyWith(segs: {...f.segs}..remove(_pick(f.segs.toList()))));
    }
    if (kinds.contains('seg')) {
      options.add(() {
        for (int k = 0; k < 20; k++) {
          final extra = _strokes(f.w, f.h, 1);
          if (extra.isNotEmpty && !f.segs.containsAll(extra)) return f.copyWith(segs: {...f.segs, ...extra});
        }
        return f;
      });
    }
    options.shuffle(_r);
    for (final o in options) {
      final g = o();
      if (g.key != f.key) return g;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIGURE MATCHING
  // Find the exact copy among near-identical figures, none turned (JNVST
  // Part 2 / JNV 2013-2019). Answer set: {as is, change A} x {as is, change B}
  // where A and B touch different details, so no option is central.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion? figureMatch() {
    for (int attempt = 0; attempt < 200; attempt++) {
      final segs = _strokes(4, 4, 7 + _r.nextInt(3));
      final f = LineFig(4, 4,
          frame: _r.nextBool(),
          segs: segs,
          tris: {for (int i = 0; i < 1 + _r.nextInt(2); i++) (_r.nextInt(4), _r.nextInt(4), _r.nextInt(4))},
          dots: {for (int i = 0; i < 1 + _r.nextInt(2); i++) (_r.nextInt(4), _r.nextInt(4))});
      final kinds = ['dot', 'tri', 'seg']..shuffle(_r);
      final a = _changeOneDetail(f, kinds: {kinds[0]});
      if (a == null) continue;
      // Apply B to both the original and to A, choosing the same concrete
      // change: re-derive it as a diff so AB = A + B exactly.
      final b = _changeOneDetail(f, kinds: {kinds[1]});
      if (b == null) continue;
      final ab = _combine(f, a, b);
      final opts = [f, a, b, ab];
      if (opts.map((o) => o.key).toSet().length != 4) continue;
      return _question('figure_match', 'figure_match_exam', {'type': 'figure_match', 'target': f.toMap()}, f.toMap(),
          [for (final o in opts.skip(1)) o.toMap()]);
    }
    return null;
  }

  /// Both changes at once: base, minus what either change removed, plus what
  /// either change added - part by part.
  static LineFig _combine(LineFig base, LineFig a, LineFig b) {
    Set<T> merge<T>(Set<T> o, Set<T> x, Set<T> y) => {...o}
      ..removeAll(o.difference(x))
      ..removeAll(o.difference(y))
      ..addAll(x.difference(o))
      ..addAll(y.difference(o));
    return base.copyWith(
      segs: merge(base.segs, a.segs, b.segs),
      tris: merge(base.tris, a.tris, b.tris),
      dots: merge(base.dots, a.dots, b.dots),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MIRROR IMAGE (line figure)
  // Line figures with small asymmetric decorations (JNV 2018-2019: arrow
  // heads, end circles, flags). Mirror held on the right.
  // Answer set: {mirror image, water image} x {all flipped, one decoration
  // left where it was}.
  // ═══════════════════════════════════════════════════════════════════════════
  static ReasoningQuestion? mirrorLineFigure() {
    for (int attempt = 0; attempt < 200; attempt++) {
      final segs = _strokes(4, 4, 5 + _r.nextInt(4));
      final ends = {for (final s in segs) ...[(s.$1, s.$2), (s.$3, s.$4)]}.toList()..shuffle(_r);
      final f = LineFig(4, 4,
          segs: segs,
          tris: {(_r.nextInt(4), _r.nextInt(4), _r.nextInt(4))},
          dots: {(_r.nextInt(4), _r.nextInt(4))},
          rings: {ends.first});
      if (!_fullyAsymmetric(f)) continue;

      final mirror = f.mirrorX(), water = f.mirrorY();
      // "Forgot to flip the dot": the flipped figure with the dot left put.
      LineFig dotStays(LineFig g) => g.copyWith(dots: f.dots);
      final opts = [mirror, water, dotStays(mirror), dotStays(water)];
      if (opts.map((o) => o.key).toSet().length != 4) continue;
      return _question('mirror_shape', 'mirror_line_fig', {'type': 'mirror_shape', 'target': f.toMap()}, mirror.toMap(),
          [for (final o in opts.skip(1)) o.toMap()]);
    }
    return null;
  }
}
