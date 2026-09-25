// Exam-style Figure Series (lib/engine/series_generator.dart), solved from
// the DRAWINGS: each family's solver reads the three problem figures, works
// out the rule (how far the arrow turned, which way the symbols moved, ...),
// predicts the fourth figure and checks exactly one option is that figure.
// Only the family name is taken from the puzzle - never the rule's numbers.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/series_generator.dart';

const runs = 300;

LineFig fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

int mod(int a, int n) => ((a % n) + n) % n;

/// A step that is the same between frames 0-1 and 1-2, on a cycle of n.
int? constantStep(List<int> xs, int n) {
  final a = mod(xs[1] - xs[0], n), b = mod(xs[2] - xs[1], n);
  return a == b ? a : null;
}

// ── solvers: frames -> predicted fourth figure's "reading" ───────────────────

/// Arrow: direction from the head, bar count from the segments that don't
/// lie along the shaft.
(int, int) readArrow(LineFig f) {
  final (x1, y1, x2, y2) = f.arrows.single;
  final d = SeriesGenerator.dir8.indexOf((x2 - x1, y2 - y1));
  expect(d, isNot(-1));
  final (vx, vy) = SeriesGenerator.dir8[d];
  final along = f.segs.where((s) => (s.$3 - s.$1) * vy - (s.$4 - s.$2) * vx == 0).length;
  return (d, (f.segs.length - along) ~/ 2);
}

String? solveArrow(List<LineFig> frames) {
  final r = frames.map(readArrow).toList();
  final turn = constantStep([for (final x in r) x.$1], 8);
  final bars = r[1].$2 - r[0].$2;
  if (turn == null || r[2].$2 - r[1].$2 != bars) return null;
  return '${mod(r[2].$1 + turn, 8)}/${r[2].$2 + bars}';
}

String arrowReading(LineFig f) => () {
      final (d, b) = readArrow(f);
      return '$d/$b';
    }();

/// Symbols: each symbol's position on the grid's border ring (clockwise),
/// read from where the glyphs are; symbols off the ring must stay put.
String? solveSymbols(List<LineFig> frames) {
  final ring = SeriesGenerator.ring(frames[0].w, frames[0].h);
  final n = ring.length;
  final predicted = <(int, int), String>{};
  int? step;
  for (final (x, y, g) in frames[0].glyphs) {
    final pos = <(int, int)>[
      for (final f in frames) f.glyphs.firstWhere((e) => e.$3 == g, orElse: () => (-1, -1, '')).$1 == -1
          ? (-1, -1)
          : () {
              final e = f.glyphs.firstWhere((e) => e.$3 == g);
              return (e.$1, e.$2);
            }(),
    ];
    if (pos.contains((-1, -1))) return null;
    if (!ring.contains((x, y))) {
      if (pos.toSet().length != 1) return null;
      predicted[pos[2]] = g;
      continue;
    }
    final s = constantStep([for (final p in pos) ring.indexOf(p)], n);
    if (s == null || (step != null && s != step)) return null;
    step = s;
    predicted[ring[mod(ring.indexOf(pos[2]) + s, n)]] = g;
  }
  return glyphReading(predicted);
}

String glyphReading(Map<(int, int), String> m) => ([for (final e in m.entries) '${e.key}${e.value}']..sort()).join();

String symbolReading(LineFig f) => glyphReading({for (final (x, y, g) in f.glyphs) (x, y): g});

/// Spokes: which of the 8 centre-to-edge lines are drawn; the dot's place
/// among the 4 between-spoke cells.
(Set<int>, int) readSpokes(LineFig f) {
  final spokes = <int>{};
  for (int i = 0; i < 8; i++) {
    final (ex, ey) = SeriesGenerator.spokeEnds[i];
    if (f.segs.containsAll(LineFig.line(2, 2, ex, ey))) spokes.add(i);
  }
  return (spokes, SeriesGenerator.dotCells.indexOf(f.dots.single));
}

String? solveSpokes(List<LineFig> frames) {
  final r = frames.map(readSpokes).toList();
  // The spoke that appeared or disappeared at each step.
  int? changed(Set<int> a, Set<int> b) {
    final diff = a.difference(b).union(b.difference(a));
    return diff.length == 1 ? diff.single : null;
  }

  final c1 = changed(r[0].$1, r[1].$1), c2 = changed(r[1].$1, r[2].$1);
  if (c1 == null || c2 == null) return null;
  final adding = r[1].$1.length > r[0].$1.length;
  if ((r[2].$1.length > r[1].$1.length) != adding) return null;
  final next = mod(c2 + (c2 - c1), 8);
  final spokes = adding ? {...r[2].$1, next} : r[2].$1.difference({next});
  final dStep = constantStep([for (final x in r) x.$2], 4);
  if (dStep == null || spokes.length == r[2].$1.length) return null;
  return '${(spokes.toList()..sort()).join(',')}/${mod(r[2].$2 + dStep, 4)}';
}

String spokeReading(LineFig f) {
  final (s, d) = readSpokes(f);
  return '${(s.toList()..sort()).join(',')}/$d';
}

/// Turning: the figure (everything but the dot) turned by the same amount
/// each step; the dot's corner.
LineFig bare(LineFig f) => f.copyWith(dots: {});

String? solveTurning(List<LineFig> frames) {
  int? turnBetween(LineFig a, LineFig b) {
    final ks = [for (int k = 1; k < 4; k++) if (bare(a).rot(k).key == bare(b).key) k];
    return ks.length == 1 ? ks.single : null;
  }

  final k1 = turnBetween(frames[0], frames[1]), k2 = turnBetween(frames[1], frames[2]);
  if (k1 == null || k1 != k2) return null;
  final corners = [for (final f in frames) SeriesGenerator.cornerCells.indexOf(f.dots.single)];
  final dStep = constantStep(corners, 4);
  if (dStep == null) return null;
  return '${bare(frames[2]).rot(k1).key}/${mod(corners[2] + dStep, 4)}';
}

String turningReading(LineFig f) => '${bare(f).key}/${SeriesGenerator.cornerCells.indexOf(f.dots.single)}';

// ── the checks ─────────────────────────────────────────────────────────────

void check(ReasoningQuestion q) {
  final frames = [for (final m in q.puzzle['sequence'] as List) fig(m)];
  final options = q.options.map(fig).toList();
  expect(frames.length, 3, reason: 'the exam shows three problem figures');
  final (String? predicted, String Function(LineFig) read) = switch (q.puzzle['rule']) {
    'arrow' => (solveArrow(frames), arrowReading),
    'symbols' => (solveSymbols(frames), symbolReading),
    'spokes' => (solveSpokes(frames), spokeReading),
    'turning' => (solveTurning(frames), turningReading),
    final r => throw StateError('unknown rule $r'),
  };
  expect(predicted, isNotNull, reason: 'no consistent rule in the problem figures (${q.puzzle['rule']})');
  expect([for (int i = 0; i < 4; i++) if (read(options[i]) == predicted) i], [q.correctIndex]);
  // No option copies a problem figure, and all four differ.
  final frameKeys = frames.map((f) => f.key).toSet();
  expect(options.where((o) => frameKeys.contains(o.key)), isEmpty);
  expect(options.map((o) => o.key).toSet().length, 4);
}

/// Parts two figures don't share.
int distance(LineFig a, LineFig b) {
  int d<T>(Set<T> x, Set<T> y) => x.difference(y).length + y.difference(x).length;
  return d(a.segs, b.segs) + d(a.arrows, b.arrows) + d(a.rings, b.rings) + d(a.dots, b.dots) + d(a.tris, b.tris) + d(a.glyphs, b.glyphs);
}

void main() {
  for (final hard in [false, true]) {
    for (final family in SeriesGenerator.families) {
      test('${hard ? 'hard' : 'easy'} $family: the rule read from the figures picks exactly one option', () {
        SeriesGenerator.seed(21);
        var central = 0;
        for (int i = 0; i < runs; i++) {
          final q = SeriesGenerator.generate(hard: hard, family: family);
          expect(q, isNotNull, reason: 'generator gave up on run $i');
          check(q!);
          final opts = q.options.map(fig).toList();
          final totals = [for (final a in opts) opts.fold<int>(0, (s, b) => s + distance(a, b))];
          final best = totals.reduce((a, b) => a < b ? a : b);
          if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
        }
        // ignore: avoid_print
        print('series ${hard ? 'hard' : 'easy'} $family: answer is the unique most-central option in '
            '${(100 * central / runs).toStringAsFixed(1)}% (guessing 25%)');
        expect(central / runs, lessThan(0.25));
      });
    }
  }

  test('both difficulties mix exam-style and the original series', () {
    QuestionGenerator.seed(3);
    for (final hard in [false, true]) {
      QuestionGenerator.resetSession();
      final rules = <String>{};
      var exam = 0;
      const n = 200;
      for (int i = 0; i < n; i++) {
        final q = QuestionGenerator.generate('figure_series', isHardMode: hard);
        if (!q.type.startsWith('series_exam_')) continue;
        exam++;
        rules.add(q.puzzle['rule'] as String);
        check(q);
      }
      // ~60% exam-style, the rest the original generators (kept on purpose).
      expect(exam / n, inInclusiveRange(0.45, 0.75), reason: '${hard ? 'hard' : 'easy'} exam-style share');
      expect(rules, SeriesGenerator.families.toSet());
    }
  });
}
