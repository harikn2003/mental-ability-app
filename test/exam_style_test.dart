// Exam-style Hard Mode items (lib/engine/exam_style_generator.dart).
//
// Every correct answer is re-derived from the puzzle alone - never from the
// generator's own bookkeeping - and the answer sets are checked against the
// "context-blind" shortcut from Yang et al. 2021 (docs/2201.08450v1.pdf).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/exam_style_generator.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const runs = 300;

List<ReasoningQuestion> _make(ReasoningQuestion? Function() gen) {
  ExamStyleGenerator.seed(7);
  final out = <ReasoningQuestion>[];
  for (int i = 0; i < runs; i++) {
    final q = gen();
    expect(q, isNotNull, reason: 'generator gave up on run $i');
    out.add(q!);
  }
  return out;
}

LineFig _fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

List<int> _where(ReasoningQuestion q, bool Function(LineFig o) test) =>
    [for (int i = 0; i < q.options.length; i++) if (test(_fig(q.options[i]))) i];

/// Number of drawn parts two figures don't share.
int _distance(LineFig a, LineFig b) {
  int d<T>(Set<T> x, Set<T> y) => x.difference(y).length + y.difference(x).length;
  return d(a.segs, b.segs) + d(a.cells, b.cells) + d(a.tris, b.tris) + d(a.dots, b.dots) + d(a.rings, b.rings);
}

/// Context-blind check: how often is the correct option the unique
/// "most similar to all the others" option? Chance is 25%.
double _centralShare(List<ReasoningQuestion> qs, {bool upToTurning = false}) {
  var central = 0;
  for (final q in qs) {
    final figs = q.options.map(_fig).toList();
    int dist(LineFig a, LineFig b) => upToTurning
        ? [for (int r = 0; r < 4; r++) _distance(a.normalized(), b.rot(r).normalized())].reduce((x, y) => x < y ? x : y)
        : _distance(a, b);
    final totals = [for (final a in figs) figs.fold<int>(0, (s, b) => s + dist(a, b))];
    final best = totals.reduce((a, b) => a < b ? a : b);
    if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
  }
  // ignore: avoid_print
  print('context-blind share [${qs.first.type}]: ${(100 * central / qs.length).toStringAsFixed(1)}% (chance 25%)');
  return central / qs.length;
}

void main() {
  test('geo: exactly one piece fills the hole (turning allowed, flipping not)', () {
    final qs = _make(ExamStyleGenerator.geoCompletion);
    for (final q in qs) {
      final frame = _fig(q.puzzle['piece']);
      final hole = {for (int x = 0; x < frame.w; x++) for (int y = 0; y < frame.h; y++) (x, y)}.difference(frame.cells);
      final holeKey = LineFig(4, 4, cells: hole, segs: LineFig.cellBoundary(hole)).normalized().rotationClassKey;
      expect(_where(q, (o) => o.rotationClassKey == holeKey), [q.correctIndex]);
      // Every option is the same size as the hole - area alone can't decide.
      for (final o in q.options) {
        expect(_fig(o).cells.length, hole.length);
      }
    }
    expect(_centralShare(qs, upToTurning: true), lessThan(0.35));
  });

  test('embedded: exactly one drawing hides the figure as shown', () {
    final qs = _make(ExamStyleGenerator.embeddedFigure);
    for (final q in qs) {
      final t = _fig(q.puzzle['target']);
      expect(_where(q, (o) => o.embeds(t)), [q.correctIndex]);
      // ...and every drawing hides it in SOME orientation.
      for (final o in q.options) {
        expect(t.dihedral().any(_fig(o).embeds), isTrue);
      }
    }
  });

  test('pattern: the missing quarter follows the design symmetry; no option repeats a visible quarter', () {
    final qs = _make(ExamStyleGenerator.patternQuarter);
    for (final q in qs) {
      final tiles = [for (final t in q.puzzle['tiles'] as List) t == null ? null : _fig(t)];
      final missing = q.puzzle['missing'] as int;
      // Candidate designs from any visible quarter; keep those consistent
      // with every visible quarter.
      final expected = <String>{};
      for (int known = 0; known < 4; known++) {
        final k = tiles[known];
        if (k == null) continue;
        // Recover TL from the known quarter, then rebuild all four.
        final mirrorTL = [k, k.mirrorX(), k.mirrorY(), k.mirrorX().mirrorY()][known];
        final turnTL = [k, k.rot(3), k.rot(1), k.rot(2)][known];
        for (final design in [
          [mirrorTL, mirrorTL.mirrorX(), mirrorTL.mirrorY(), mirrorTL.mirrorX().mirrorY()],
          [turnTL, turnTL.rot(1), turnTL.rot(3), turnTL.rot(2)],
        ]) {
          final fits = [for (int i = 0; i < 4; i++) i == missing || design[i].key == tiles[i]!.key].every((b) => b);
          if (fits) expected.add(design[missing].key);
        }
      }
      expect(expected.length, 1, reason: 'design must be unambiguous');
      expect(_where(q, (o) => o.key == expected.single), [q.correctIndex]);
      final visible = {for (final t in tiles) if (t != null) t.key};
      expect(q.options.where((o) => visible.contains(_fig(o).key)), isEmpty);
    }
    expect(_centralShare(qs), lessThan(0.35));
  });

  test('punch hole: exactly one card matches unfolding every fold', () {
    ExamStyleGenerator.seed(7);
    // Independent re-implementation of unfolding, from the fold codes alone.
    (double, double, int?) reflect(String f, double x, double y, int? dir) {
      const v = [(0, -1), (1, 0), (0, 1), (-1, 0)];
      final d = dir == null ? null : v[dir];
      return switch (f) {
        'v' => (1 - x, y, d == null ? null : v.indexOf((-d.$1, d.$2))),
        'h' => (x, 1 - y, d == null ? null : v.indexOf((d.$1, -d.$2))),
        'd' => (y, x, d == null ? null : v.indexOf((d.$2, d.$1))),
        _ => (1 - y, 1 - x, d == null ? null : v.indexOf((-d.$2, -d.$1))),
      };
    }

    String key(Iterable<(double, double, int?)> hs, String shape) =>
        ([for (final h in hs) '${(h.$1 * 100).round()},${(h.$2 * 100).round()},$shape,${h.$3 ?? ''}']..sort()).join(';');

    for (int i = 0; i < runs; i++) {
      final q = ExamStyleGenerator.punchHole()!;
      final folds = (q.puzzle['folds'] as List).cast<String>();
      final holes = q.puzzle['holes'] as List;
      final shape = holes.first['shape'] as String;
      var set = [
        for (final h in holes) ((h['x'] as double), (h['y'] as double), shape == 'tri' ? h['dir'] as int : null)
      ];
      for (final f in folds.reversed) {
        set = [...set, for (final h in set) reflect(f, h.$1, h.$2, h.$3)];
      }
      final want = key(set, shape);
      final matching = [
        for (int o = 0; o < 4; o++)
          if (key([
                for (final h in q.options[o]['holes'] as List)
                  ((h['x'] as double), (h['y'] as double), shape == 'tri' ? h['dir'] as int : null)
              ], shape) ==
              want)
            o
      ];
      expect(matching, [q.correctIndex], reason: 'folds $folds holes $holes');
      // No two unfolded holes may overlap (hole ~0.16 wide).
      for (int a = 0; a < set.length; a++) {
        for (int b = a + 1; b < set.length; b++) {
          final dx = set[a].$1 - set[b].$1, dy = set[a].$2 - set[b].$2;
          expect(dx * dx + dy * dy, greaterThan(0.16 * 0.16), reason: 'holes overlap: $folds $holes');
        }
      }
    }
  });

  test('figure match: exactly one exact copy', () {
    final qs = _make(ExamStyleGenerator.figureMatch);
    for (final q in qs) {
      final t = _fig(q.puzzle['target']);
      expect(_where(q, (o) => o.key == t.key), [q.correctIndex]);
    }
    expect(_centralShare(qs), lessThan(0.35));
  });

  test('mirror line figure: exactly one true mirror image', () {
    final qs = _make(ExamStyleGenerator.mirrorLineFigure);
    for (final q in qs) {
      final t = _fig(q.puzzle['target']);
      expect(_where(q, (o) => o.key == t.mirrorX().key), [q.correctIndex]);
    }
    expect(_centralShare(qs), lessThan(0.35));
  });
}
