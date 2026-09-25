// Exam-style Figure Analogy (lib/engine/analogy_generator.dart), solved from
// the DRAWINGS: each family's solver reads A and B, works out what changed
// (which turn/flip, which marker became which; where each corner fill went;
// which shape of the row ended up at which depth), applies it to C and
// checks exactly one option is the result. Only the family name is taken
// from the puzzle.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/analogy_generator.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const runs = 300;

LineFig fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

// ── turn ─────────────────────────────────────────────────────────────────────

LineFig bare(LineFig f) => f.copyWith(glyphs: {});

String? solveTurn(LineFig a, LineFig b, LineFig c) {
  final ts = [for (int t = 0; t < 8; t++) if (AnalogyGenerator.transform(bare(a), t).key == bare(b).key) t];
  if (ts.length != 1) return null;
  final (fromKind, toKind) = (a.glyphs.single.$3, b.glyphs.single.$3);
  final (cx, cy, cKind) = c.glyphs.single;
  if (cKind != fromKind) return null;
  // Where C's marker lands: turn a figure holding only that marker.
  final (mx, my, _) = AnalogyGenerator.transform(LineFig(c.w, c.h, glyphs: {(cx, cy, 'dot')}), ts.single).glyphs.single;
  return AnalogyGenerator.transform(bare(c), ts.single).copyWith(glyphs: {(mx, my, toKind)}).key;
}

// ── corners ──────────────────────────────────────────────────────────────────

List<String> readCorners(LineFig f) => [
      for (final (x, y) in AnalogyGenerator.cornerCells)
        f.tris.contains((x, y, 0)) && f.tris.contains((x, y, 2))
            ? 'black'
            : f.hatch.contains((x, y, 4, 0))
                ? 'hatch'
                : f.hatch.contains((x, y, 4, 2))
                    ? 'lines'
                    : f.dots.contains((x, y))
                        ? 'dot'
                        : f.glyphs.contains((x, y, 'cross'))
                            ? 'cross'
                            : 'plain',
    ];

List<List<int>> perms(List<int> xs) =>
    xs.isEmpty ? [[]] : [for (final x in xs) for (final p in perms([...xs]..remove(x))) [x, ...p]];

String? solveCorners(LineFig a, LineFig b, LineFig c) {
  final ra = readCorners(a), rb = readCorners(b);
  final fits = [for (final p in perms([0, 1, 2, 3])) if (AnalogyGenerator.move(ra, p).join(',') == rb.join(',')) p];
  if (fits.length != 1) return null;
  return AnalogyGenerator.move(readCorners(c), fits.single).join(',');
}

// ── nest ─────────────────────────────────────────────────────────────────────

bool contains(LineFig f, LineFig part) => f.segs.containsAll(part.segs) && f.arcs.containsAll(part.arcs);

List<String>? readRow(LineFig f) {
  final out = <String>[];
  for (int i = 0; i < 3; i++) {
    final ks = [for (final k in AnalogyGenerator.kinds) if (contains(f, AnalogyGenerator.shape(k, 5 + 10 * i, 5, 4, 30, 10))) k];
    if (ks.length != 1) return null;
    out.add(ks.single);
  }
  return out;
}

List<String>? readNest(LineFig f) {
  final out = <String>[];
  for (final size in AnalogyGenerator.nestSizes) {
    final ks = [for (final k in AnalogyGenerator.kinds) if (contains(f, AnalogyGenerator.shape(k, 8, 8, size, 16, 16))) k];
    if (ks.length != 1) return null;
    out.add(ks.single);
  }
  return out;
}

String? solveNest(LineFig a, LineFig b, LineFig c) {
  final row = readRow(a), nest = readNest(b), rowC = readRow(c);
  if (row == null || nest == null || rowC == null) return null;
  // Depth of each row position, then the same depths for C's row.
  final depth = [for (final k in row) nest.indexOf(k)];
  final out = List<String>.filled(3, '');
  for (int i = 0; i < 3; i++) {
    out[depth[i]] = rowC[i];
  }
  return out.join(',');
}

String? nestReading(LineFig f) => readNest(f)?.join(',');

// ── checks ───────────────────────────────────────────────────────────────────

void check(ReasoningQuestion q) {
  final a = fig(q.puzzle['A']), b = fig(q.puzzle['B']), c = fig(q.puzzle['C']);
  final options = q.options.map(fig).toList();
  final (String? predicted, String? Function(LineFig) read) = switch (q.puzzle['rule']) {
    'turn' => (solveTurn(a, b, c), (LineFig o) => o.key),
    'corners' => (solveCorners(a, b, c), (LineFig o) => readCorners(o).join(',')),
    'nest' => (solveNest(a, b, c), nestReading),
    final r => throw StateError('unknown rule $r'),
  };
  expect(predicted, isNotNull, reason: 'no single rule takes A to B (${q.puzzle['rule']})');
  expect([for (int i = 0; i < 4; i++) if (read(options[i]) == predicted) i], [q.correctIndex]);
  expect(options.map((o) => o.key).toSet().length, 4);
  final shown = {a.key, b.key, c.key};
  for (int i = 0; i < 4; i++) {
    if (i != q.correctIndex) expect(shown.contains(options[i].key), isFalse, reason: 'wrong option copies a problem figure');
  }
}

int distance(LineFig a, LineFig b) {
  int d<T>(Set<T> x, Set<T> y) => x.difference(y).length + y.difference(x).length;
  return d(a.segs, b.segs) + d(a.arcs, b.arcs) + d(a.tris, b.tris) + d(a.hatch, b.hatch) + d(a.dots, b.dots) + d(a.glyphs, b.glyphs);
}

void main() {
  for (final hard in [false, true]) {
    for (final family in AnalogyGenerator.families) {
      test('${hard ? 'hard' : 'easy'} $family: the change read from A -> B picks exactly one option', () {
        AnalogyGenerator.seed(31);
        var central = 0;
        for (int i = 0; i < runs; i++) {
          final q = AnalogyGenerator.generate(hard: hard, family: family);
          expect(q, isNotNull, reason: 'generator gave up on run $i');
          check(q!);
          final opts = q.options.map(fig).toList();
          final totals = [for (final x in opts) opts.fold<int>(0, (s, y) => s + distance(x, y))];
          final best = totals.reduce((x, y) => x < y ? x : y);
          if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
        }
        // ignore: avoid_print
        print('analogy ${hard ? 'hard' : 'easy'} $family: answer is the unique most-central option in '
            '${(100 * central / runs).toStringAsFixed(1)}% (guessing 25%)');
        expect(central / runs, lessThan(0.25));
      });
    }
  }

  test('both difficulties mix exam-style and the original analogy', () {
    QuestionGenerator.seed(3);
    for (final hard in [false, true]) {
      QuestionGenerator.resetSession();
      final rules = <String>{};
      var exam = 0;
      const n = 200;
      for (int i = 0; i < n; i++) {
        if (i % 20 == 0) QuestionGenerator.resetSession();
        final q = QuestionGenerator.generate('analogy', isHardMode: hard);
        if (!q.type.startsWith('analogy_exam_')) continue;
        exam++;
        rules.add(q.puzzle['rule'] as String);
        check(q);
      }
      expect(exam / n, inInclusiveRange(0.45, 0.75), reason: '${hard ? 'hard' : 'easy'} exam-style share');
      expect(rules, AnalogyGenerator.families.toSet());
    }
  });

  test('the original analogy (kept in the mix) no longer gives the answer away', () {
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

    int dist(Map x, Map y) {
      final ax = attrs(x), ay = attrs(y);
      return {...ax.keys, ...ay.keys}.where((k) => ax[k] != ay[k]).length;
    }

    for (final hard in [false, true]) {
      QuestionGenerator.seed(8);
      var classic = 0, central = 0;
      for (int i = 0; i < 1500 && classic < 400; i++) {
        if (i % 10 == 0) QuestionGenerator.resetSession();
        final q = QuestionGenerator.generate('analogy', isHardMode: hard);
        if (q.type.startsWith('analogy_exam_')) continue;
        classic++;
        final opts = [for (final o in q.options) Map<String, dynamic>.from(o)];
        String key(Map<String, dynamic> o) => o['type'] == 'sandia_cell' ? '$o' : QuestionGenerator.debugOptionKey(o);
        expect(opts.map(key).toSet().length, 4, reason: '${q.type}: two options look the same');
        final totals = [for (final x in opts) opts.fold<int>(0, (s, y) => s + dist(x, y))];
        final best = totals.reduce((x, y) => x < y ? x : y);
        if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
      }
      // ignore: avoid_print
      print('original analogy ${hard ? 'hard' : 'easy'}: answer is the unique most-central option in '
          '${(100 * central / classic).toStringAsFixed(1)}% of $classic (was 61% easy / 100% hard)');
      expect(central / classic, lessThan(0.25));
    }
  });

  test('easy stays a notch below hard', () {
    AnalogyGenerator.seed(41);
    for (int i = 0; i < runs; i++) {
      // Turn: quarter turns only, and no option is a mirror image of C -
      // every option is C (strokes) turned, never flipped.
      final t = AnalogyGenerator.generate(family: 'turn')!;
      final a = fig(t.puzzle['A']), b = fig(t.puzzle['B']), c = fig(t.puzzle['C']);
      final ts = [for (int k = 0; k < 8; k++) if (AnalogyGenerator.transform(bare(a), k).key == bare(b).key) k];
      expect(ts.single, anyOf(1, 3), reason: 'easy rule must be a quarter turn');
      final turns = {for (int k = 0; k < 4; k++) bare(c).rot(k).key};
      for (final o in t.options) {
        expect(turns.contains(bare(fig(o)).key), isTrue, reason: 'easy options must not include a mirror image');
      }
      expect(bare(c).segs.length, lessThanOrEqualTo(5), reason: 'easy figures are simpler');

      // Corners: only the bold fills.
      final q = AnalogyGenerator.generate(family: 'corners')!;
      for (final m in [q.puzzle['A'], q.puzzle['B'], q.puzzle['C'], ...q.options]) {
        expect(readCorners(fig(m)).toSet().difference({'black', 'dot', 'hatch', 'plain'}), isEmpty);
      }
    }
  });
}
