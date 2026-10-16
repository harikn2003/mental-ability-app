// The guide book's question types (BookGenerator): each test solves every
// question from its data alone and checks exactly one option is right.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/book_generator.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const runs = 300;

LineFig fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

String text(dynamic m) => (m as Map)['content'] as String;

/// Runs [make] [runs] times; most draws must succeed.
List<ReasoningQuestion> draw(ReasoningQuestion? Function() make) {
  final qs = [for (int i = 0; i < runs; i++) make()].whereType<ReasoningQuestion>().toList();
  expect(qs.length, greaterThan(runs * 0.6), reason: 'too many failed draws');
  for (final q in qs) {
    expect(q.options, hasLength(4));
    expect({for (final o in q.options) o.toString()}, hasLength(4), reason: 'two options alike');
  }
  return qs;
}

/// The one index where [right] holds.
int only(ReasoningQuestion q, bool Function(Map o) right) {
  final hits = [for (int i = 0; i < 4; i++) if (right(q.options[i])) i];
  expect(hits, hasLength(1), reason: '${q.type}: right options $hits');
  return hits.single;
}

void main() {
  setUp(() => BookGenerator.seed(11));

  for (final medium in [false, true]) {
    test('odd man letters (${medium ? 'medium' : 'easy'}): three words share their letters, one does not', () {
      for (final q in draw(() => BookGenerator.oddManLetters(medium: medium))) {
        String letters(Map o) => (text(o).split('')..sort()).join();
        final counts = <String, int>{};
        for (final o in q.options) {
          counts[letters(o)] = (counts[letters(o)] ?? 0) + 1;
        }
        expect(counts.values.toList()..sort(), [1, 3]);
        expect(only(q, (o) => counts[letters(o)] == 1), q.correctIndex);
        expect(text(q.options[0]).length, medium ? 4 : 3);
      }
    });

    test('series letters (${medium ? 'medium' : 'easy'}): the answer is the next shift', () {
      for (final q in draw(() => BookGenerator.seriesLetters(medium: medium))) {
        final seq = [for (final s in q.puzzle['sequence'] as List) text(s)];
        final n = seq[0].length;
        expect(n, medium ? 5 : 4);
        String shift(String s, int k) => s.substring(k % n) + s.substring(0, k % n);
        final k = [for (int k = 1; k < n; k++) if (shift(seq[0], k) == seq[1]) k].single;
        expect(shift(seq[1], k), seq[2]);
        expect(only(q, (o) => text(o) == shift(seq[2], k)), q.correctIndex);
      }
    });

    test('series round the box (${medium ? 'medium' : 'easy'}): each symbol keeps its step', () {
      const ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)];
      for (final q in draw(() => BookGenerator.seriesRound(medium: medium))) {
        final seq = [for (final s in q.puzzle['sequence'] as List) fig(s)];
        Map<String, int> places(LineFig f) => {for (final g in f.glyphs) g.$3: ring.indexOf((g.$1, g.$2))};
        final p = [for (final f in seq) places(f)];
        expect(p[0].length, medium ? 2 : 1);
        final next = <String, int>{};
        for (final g in p[0].keys) {
          final step = (p[1][g]! - p[0][g]!) % 8;
          expect((p[2][g]! - p[1][g]!) % 8, step, reason: '$g changes its step');
          next[g] = (p[2][g]! + step) % 8;
        }
        expect(only(q, (o) => places(fig(o)).toString() == next.toString()), q.correctIndex);
      }
    });
  }

  test('odd man counting: three have the same counts, one the other way round', () {
    for (final q in draw(BookGenerator.oddManCount)) {
      String counts(Map o) {
        final c = <String, int>{};
        for (final g in fig(o).glyphs) {
          c[g.$3] = (c[g.$3] ?? 0) + 1;
        }
        return (c.entries.map((e) => '${e.key}${e.value}').toList()..sort()).join();
      }

      final all = [for (final o in q.options) counts(o)];
      expect(only(q, (o) => all.where((c) => c == counts(o)).length == 1), q.correctIndex);
    }
  });

  test('paper folding: the answer is the left half with the right half flipped onto it', () {
    for (final q in draw(BookGenerator.paperFold)) {
      final sheet = fig(q.puzzle['sheet']);
      expect((q.puzzle['sheet'] as Map)['fold'], [2, 0, 2, 4]);
      final folded = <(int, int, int, int)>{};
      for (final (x1, y1, x2, y2) in sheet.segs) {
        expect(x1 == 2 && x2 == 2, isFalse, reason: 'a line on the fold');
        // Right-half segments land at x -> 4 - x.
        folded.add(x1 + x2 <= 4 ? (x1, y1, x2, y2) : (4 - x1, y1, 4 - x2, y2));
      }
      final want = LineFig(2, 4, frame: true, segs: folded).key;
      expect(only(q, (o) => fig(o).key == want), q.correctIndex);
    }
  });

  test('Easy and Medium serve the book types; Hard does not', () {
    Set<String> types(String topic, Difficulty d, {int n = 400}) {
      QuestionGenerator.seed(5);
      final out = <String>{};
      for (int i = 0; i < n; i++) {
        if (i % 30 == 0) QuestionGenerator.resetSession();
        out.add(QuestionGenerator.generate(topic, difficulty: d).type);
      }
      return out;
    }

    expect(types('odd_man', Difficulty.easy), contains('odd_letters'));
    expect(types('figure_series', Difficulty.easy), containsAll(['series_letters', 'series_round']));
    expect(types('odd_man', Difficulty.medium), containsAll(['odd_letters_medium', 'odd_count']));
    expect(types('figure_series', Difficulty.medium), containsAll(['series_letters_medium', 'series_round_medium']));
    expect(types('punch_hole', Difficulty.medium), contains('paper_fold'));
    for (final t in ['odd_man', 'figure_series', 'punch_hole']) {
      expect(types(t, Difficulty.hard, n: 200).where((s) => s.startsWith('odd_letters') || s.startsWith('series_letters') ||
          s.startsWith('series_round') || s == 'odd_count' || s == 'paper_fold'), isEmpty);
    }
  });
}
