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
    for (final family in hard ? SeriesGenerator.families : SeriesGenerator.easyFamilies) {
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
      expect(rules, (hard ? SeriesGenerator.families : SeriesGenerator.easyFamilies).toSet());
    }
  });

  test('the original series (kept in the mix) no longer give the answer away', () {
    // Attributes of a classic figure / Sandia cell, flattened.
    Map<String, Object?> attrs(Map o) {
      if (o['type'] == 'sandia_cell') {
        final out = <String, Object?>{};
        final layers = o['layers'] as List;
        for (int i = 0; i < layers.length; i++) {
          (layers[i] as Map).forEach((k, v) => out['L$i.$k'] = v);
        }
        return out;
      }
      return {for (final k in ['shape', 'rotation', 'filled', 'dots', 'inner', 'mirror']) k: o[k] ?? (k == 'mirror' ? false : null)};
    }

    int dist(Map a, Map b) {
      final x = attrs(a), y = attrs(b);
      return {...x.keys, ...y.keys}.where((k) => x[k] != y[k]).length;
    }

    for (final hard in [false, true]) {
      QuestionGenerator.seed(8);
      QuestionGenerator.resetSession();
      var classic = 0, central = 0;
      for (int i = 0; i < 1500 && classic < 400; i++) {
        if (i % 10 == 0) QuestionGenerator.resetSession();
        final q = QuestionGenerator.generate('figure_series', isHardMode: hard);
        if (q.type.startsWith('series_exam_')) continue;
        classic++;
        final opts = [for (final o in q.options) Map<String, dynamic>.from(o)];
        // Sandia cells: compare the full layer data (debugOptionKey only
        // understands classic figures and line figures).
        String key(Map<String, dynamic> o) => o['type'] == 'sandia_cell' ? '$o' : QuestionGenerator.debugOptionKey(o);
        expect(opts.map(key).toSet().length, 4, reason: '${q.type}: two options look the same');
        final totals = [for (final a in opts) opts.fold<int>(0, (s, b) => s + dist(a, b))];
        final best = totals.reduce((a, b) => a < b ? a : b);
        if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
      }
      // ignore: avoid_print
      print('original series ${hard ? 'hard' : 'easy'}: answer is the unique most-central option in '
          '${(100 * central / classic).toStringAsFixed(1)}% of $classic (was 64% easy / 100% hard)');
      expect(central / classic, lessThan(0.25));
    }
  });

  test('easy (grades 2-3): one thing changes per step', () {
    SeriesGenerator.seed(51);
    for (int i = 0; i < runs; i++) {
      // Arrow: bars never change, the turn is one 45° step.
      final a = SeriesGenerator.generate(family: 'arrow')!;
      final r = [for (final m in a.puzzle['sequence'] as List) readArrow(fig(m))];
      expect(r.map((x) => x.$2).toSet().length, 1, reason: 'easy arrow: bars stay the same');
      expect(mod(r[1].$1 - r[0].$1, 8), anyOf(1, 7), reason: 'easy arrow: 45° steps');
      // Spokes: the dot never moves.
      final sp = SeriesGenerator.generate(family: 'spokes')!;
      expect({for (final m in sp.puzzle['sequence'] as List) readSpokes(fig(m)).$2}.length, 1, reason: 'easy spokes: dot stays');
      // Symbols: two symbols on a 2x2 grid.
      final sy = SeriesGenerator.generate(family: 'symbols')!;
      final f0 = fig((sy.puzzle['sequence'] as List).first);
      expect((f0.w, f0.h, f0.glyphs.length), (2, 2, 2));
    }
    // The original series in Easy: one attribute changes between frames.
    QuestionGenerator.seed(12);
    var classic = 0;
    for (int i = 0; i < 800 && classic < 200; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      final q = QuestionGenerator.generate('figure_series');
      if (q.type.startsWith('series_exam_')) continue;
      classic++;
      final seq = [for (final m in q.puzzle['sequence'] as List) m as Map];
      final changing = {
        for (final k in ['shape', 'rotation', 'filled', 'dots', 'inner'])
          if ({for (final f in seq) f[k]}.length > 1) k,
      };
      expect(changing.length, 1, reason: '${q.type} changes $changing');
    }
  });

  test('hard still serves the classic multi-change series and the Sandia series', () {
    QuestionGenerator.seed(13);
    final types = <String>{};
    for (int i = 0; i < 300; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      types.add(QuestionGenerator.generate('figure_series', isHardMode: true).type);
    }
    expect(types, containsAll(['hard_series_sandia_3layer', 'series_rot_fill', 'series_morph', 'series_fill_toggle']));
  });
}
