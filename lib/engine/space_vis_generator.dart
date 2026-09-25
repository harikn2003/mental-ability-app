import 'dart:math';

import 'line_figure.dart';
import 'reasoning_question.dart';

/// A quarter of a grid cell: (cellX, cellY, side) - the triangle between
/// that side of the cell (0 top, 1 right, 2 bottom, 3 left) and the cell's
/// centre. Every straight cut the generator makes (horizontal, vertical or
/// 45°, through lattice points) runs along quarter edges, never through a
/// quarter, so any cut-up shape is exactly a set of quarters.
typedef Quarter = (int, int, int);

/// JNVST Part 9, Space Visualisation (2025 SS256J Q33-36): the question
/// shows a few cut-out pieces, scattered and turned; the options are the
/// assembled figure with its dividing lines drawn. Pick the figure the
/// pieces make.
///
/// Wrong options have the SAME outline divided differently, as in the exam,
/// so the outline alone never decides it. One or two are "near misses" (one
/// cut moved by a single step), the rest are other ways of cutting the same
/// outline. A wrong option's pieces never match the given pieces even if
/// they were flipped over, so the item has exactly one answer however a
/// child handles the pieces.
class SpaceVisGenerator {
  static Random _r = Random();

  static void seed(int s) => _r = Random(s);

  static const n = 4; // grid cells per side; drawn on a 2n doubled lattice

  /// Quarter centroid times 6 (integer): cell centre (6x+3, 6y+3) moved 2
  /// towards the quarter's side.
  static (int, int) _c6(Quarter a) {
    const o = [(0, -2), (2, 0), (0, 2), (-2, 0)];
    return (6 * a.$1 + 3 + o[a.$3].$1, 6 * a.$2 + 3 + o[a.$3].$2);
  }

  /// Outlines, as tests on a quarter's centroid (coordinates times 6, so a
  /// lattice line x = 2 is x6 = 12). Every boundary is a lattice line, so
  /// the tests never cut a quarter.
  static final Map<String, bool Function(int x, int y)> outlines = {
    'square': (x, y) => true,
    'rectangle': (x, y) => y < 18,
    'triangle': (x, y) => x + y < 24,
    'diamond': (x, y) => (x - 12).abs() + (y - 12).abs() < 12,
    'house': (x, y) => y > (x - 12).abs(),
    'octagon': (x, y) => (x - 12).abs() + (y - 12).abs() < 18,
    'chamfer': (x, y) => y < 18 && (x - 12).abs() < 6 + y,
  };

  static const easyOutlines = ['square', 'rectangle', 'triangle', 'house'];

  static Set<Quarter> outline(String name) {
    final test = outlines[name]!;
    return {
      for (int x = 0; x < n; x++)
        for (int y = 0; y < n; y++)
          for (int q = 0; q < 4; q++)
            if (test(_c6((x, y, q)).$1, _c6((x, y, q)).$2)) (x, y, q),
    };
  }

  // ── cutting ───────────────────────────────────────────────────────────────

  /// A straight cut: a·x + b·y = c on the unit lattice.
  static const axisDirs = [(1, 0), (0, 1)];
  static const diagDirs = [(1, 1), (1, -1)];

  static int _side(Quarter a, (int, int, int) line) {
    final (x, y) = _c6(a);
    return (line.$1 * x + line.$2 * y - 6 * line.$3).sign;
  }

  static List<Quarter> _neighbours(Quarter a) {
    final (x, y, q) = a;
    const across = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    return [(x, y, (q + 1) % 4), (x, y, (q + 3) % 4), (x + across[q].$1, y + across[q].$2, (q + 2) % 4)];
  }

  static bool _connected(Set<Quarter> s) {
    if (s.isEmpty) return false;
    final seen = <Quarter>{s.first};
    final todo = [s.first];
    while (todo.isNotEmpty) {
      for (final b in _neighbours(todo.removeLast())) {
        if (s.contains(b) && seen.add(b)) todo.add(b);
      }
    }
    return seen.length == s.length;
  }

  /// Cuts piece [i] along [line]: piece i keeps one side, the other side is
  /// appended. Null if the line misses the piece or leaves a part too small.
  static List<Set<Quarter>>? cut(List<Set<Quarter>> pieces, int i, (int, int, int) line, int minSize) {
    final a = {for (final q in pieces[i]) if (_side(q, line) < 0) q};
    final b = pieces[i].difference(a);
    if (a.length < minSize || b.length < minSize || !_connected(a) || !_connected(b)) return null;
    return [...pieces.sublist(0, i), a, ...pieces.sublist(i + 1), b];
  }

  static (int, int, int) _randomLine(bool diagonals) {
    final (a, b) = (diagonals && _r.nextBool() ? diagDirs : axisDirs)[_r.nextInt(2)];
    // Range of c that can cross the n x n grid.
    final int lo = min(0, a * n) + min(0, b * n), hi = max(0, a * n) + max(0, b * n);
    return (a, b, lo + 1 + _r.nextInt(hi - lo - 1));
  }

  /// A random cutting of [base] into [count] pieces: the cuts made, in order
  /// (which piece, which line), and the resulting pieces.
  static (List<(int, (int, int, int))>, List<Set<Quarter>>)? randomCutting(
      Set<Quarter> base, int count, bool diagonals, int minSize) {
    for (int attempt = 0; attempt < 60; attempt++) {
      var pieces = [base];
      final cuts = <(int, (int, int, int))>[];
      for (int guard = 0; pieces.length < count && guard < 80; guard++) {
        // Prefer cutting a big piece, so sizes stay comparable.
        final order = [for (int i = 0; i < pieces.length; i++) i]..sort((x, y) => pieces[y].length - pieces[x].length);
        final i = order[_r.nextInt(min(2, order.length))];
        final line = _randomLine(diagonals);
        final next = cut(pieces, i, line, minSize);
        if (next == null) continue;
        pieces = next;
        cuts.add((i, line));
      }
      if (pieces.length == count) return (cuts, pieces);
    }
    return null;
  }

  static List<Set<Quarter>>? replay(Set<Quarter> base, List<(int, (int, int, int))> cuts, int minSize) {
    var pieces = [base];
    for (final (i, line) in cuts) {
      final next = cut(pieces, i, line, minSize);
      if (next == null) return null;
      pieces = next;
    }
    return pieces;
  }

  // ── drawing ───────────────────────────────────────────────────────────────

  static (int, int, int, int) _norm(int a, int b, int c, int d) => (a < c || (a == c && b <= d)) ? (a, b, c, d) : (c, d, a, b);

  /// The unit segments (doubled lattice) of one quarter's three edges.
  static List<(int, int, int, int)> _edges(Quarter t) {
    final (x, y, q) = t;
    final corners = [(2 * x, 2 * y), (2 * x + 2, 2 * y), (2 * x + 2, 2 * y + 2), (2 * x, 2 * y + 2)];
    final (p1, p2) = (corners[q], corners[(q + 1) % 4]);
    final c = (2 * x + 1, 2 * y + 1);
    final mid = ((p1.$1 + p2.$1) ~/ 2, (p1.$2 + p2.$2) ~/ 2);
    return [
      _norm(p1.$1, p1.$2, mid.$1, mid.$2),
      _norm(mid.$1, mid.$2, p2.$1, p2.$2),
      _norm(p1.$1, p1.$2, c.$1, c.$2),
      _norm(p2.$1, p2.$2, c.$1, c.$2),
    ];
  }

  /// Outline of a set of quarters: the edges only one of its quarters has.
  static Set<(int, int, int, int)> boundary(Set<Quarter> s) {
    final count = <(int, int, int, int), int>{};
    for (final t in s) {
      for (final e in _edges(t)) {
        count[e] = (count[e] ?? 0) + 1;
      }
    }
    return {for (final e in count.entries) if (e.value == 1) e.key};
  }

  static LineFig pieceFigure(Set<Quarter> s) => LineFig(2 * n, 2 * n, segs: boundary(s)).normalized();

  /// The assembled figure: every piece's outline, i.e. the outer outline
  /// plus the cut lines.
  static LineFig assembled(List<Set<Quarter>> pieces) =>
      LineFig(2 * n, 2 * n, segs: {for (final p in pieces) ...boundary(p)}).normalized();

  /// A piece up to turning (and position).
  static String turnKey(LineFig f) => f.rotationClassKey;

  /// A piece up to turning AND flipping.
  static String flipKey(LineFig f) => ([for (final g in f.dihedral()) g.shapeKey]..sort()).first;

  static List<String> _multiset(List<Set<Quarter>> pieces, String Function(LineFig) key) =>
      [for (final p in pieces) key(pieceFigure(p))]..sort();

  // ── the question ──────────────────────────────────────────────────────────

  static ReasoningQuestion? generate({bool hard = false}) {
    for (int attempt = 0; attempt < 200; attempt++) {
      final outlineName = hard ? outlines.keys.elementAt(_r.nextInt(outlines.length)) : easyOutlines[_r.nextInt(easyOutlines.length)];
      final base = outline(outlineName);
      final count = hard ? 3 + _r.nextInt(2) : 2 + _r.nextInt(2);
      final minSize = hard ? 4 : 8;
      final made = randomCutting(base, count, hard, minSize);
      if (made == null) continue;
      final (cuts, pieces) = made;
      final given = _multiset(pieces, flipKey).join('|');

      // Wrong options: near misses first (one cut moved one step), then
      // other cuttings of the same outline.
      final wrongs = <List<Set<Quarter>>>[];
      final figures = <String>{assembled(pieces).rotationClassKey};
      bool tryAdd(List<Set<Quarter>>? w) {
        if (w == null || w.length != count) return false;
        if (_multiset(w, flipKey).join('|') == given) return false;
        if (!figures.add(assembled(w).rotationClassKey)) return false;
        wrongs.add(w);
        return true;
      }

      List<(int, (int, int, int))> moved(List<(int, (int, int, int))> cs, int k, int d) {
        final (i, (a, b, c)) = cs[k];
        return [...cs.sublist(0, k), (i, (a, b, c + d)), ...cs.sublist(k + 1)];
      }

      if (hard) {
        // Balanced set: {as is, cut j moved} x {as is, cut k moved}. Two
        // one-step misses alone would make the answer the option closest to
        // all the others (Yang et al. 2021) - measured 58% in the tests.
        final combos = [
          for (int j = 0; j < cuts.length; j++)
            for (int k = j + 1; k < cuts.length; k++)
              for (final d in [-1, 1])
                for (final e in [-1, 1]) (j, k, d, e),
        ]..shuffle(_r);
        for (final (j, k, d, e) in combos) {
          final a = replay(base, moved(cuts, j, d), minSize);
          final b = replay(base, moved(cuts, k, e), minSize);
          final ab = replay(base, moved(moved(cuts, j, d), k, e), minSize);
          final before = figures.toSet();
          if (tryAdd(a) && tryAdd(b) && tryAdd(ab)) break;
          wrongs.clear();
          figures
            ..clear()
            ..addAll(before);
        }
      } else {
        // One near miss, two other cuttings of the same outline.
        final nearTries = [
          for (int k = 0; k < cuts.length; k++)
            for (final d in [-1, 1]) (k, d),
        ]..shuffle(_r);
        for (final (k, d) in nearTries) {
          if (tryAdd(replay(base, moved(cuts, k, d), minSize))) break;
        }
        for (int guard = 0; wrongs.length < 3 && guard < 60; guard++) {
          tryAdd(randomCutting(base, count, hard, minSize)?.$2);
        }
      }
      if (wrongs.length < 3) continue;

      // The pieces, each turned; shown at the options' scale.
      final shown = [
        for (final p in pieces)
          () {
            final f = pieceFigure(p);
            // Symmetric pieces look the same turned; only count real turns.
            final turns = hard ? _r.nextInt(4) : [0, 1, 3][_r.nextInt(3)];
            return f.rot(turns).normalized();
          }(),
      ]..shuffle(_r);
      // At least one piece must visibly differ from how it sits in the figure.
      final inPlace = {for (final p in pieces) pieceFigure(p).key};
      if (shown.every((f) => inPlace.contains(f.key))) continue;

      // One shared scale for all pieces - the largest piece's extent - so
      // their sizes compare correctly and they're drawn as large as fits.
      final extent = shown.map((f) => max(f.w, f.h)).reduce(max);
      final options = [for (final w in wrongs) assembled(w).toMap()];
      final correct = assembled(pieces).toMap();
      final idx = _r.nextInt(4);
      return ReasoningQuestion(
        category: 'space_vis',
        type: 'space_vis_pieces',
        puzzle: {
          'type': 'space_vis',
          'outline': outlineName,
          'pieces': [
            for (final f in shown) {...f.toMap(), 'w': extent, 'h': extent, 'center': true},
          ],
        },
        options: [...options.sublist(0, idx), correct, ...options.sublist(idx)],
        correctIndex: idx,
      );
    }
    return null;
  }
}
