// Printed test paper: 10 parts of 4 questions in JNVST order, each part
// going easy to hard; one shuffled set per student.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/test_paper.dart';

void main() {
  String key(Map<String, dynamic> o) => o.toString();

  test('10 parts of 4 questions in JNVST order', () {
    final paper = TestPaper.generate(seed: 3);
    expect(paper.parts.length, 10);
    expect(paper.parts.map((p) => p.questions.length), everyElement(4));
    expect([for (final p in paper.parts) p.id], TestPaper.partIds);
    for (final p in paper.parts) {
      for (final q in p.questions) {
        expect(TestPaper.partTopics[p.id], contains(q.category), reason: p.id);
      }
    }
    final mirror = paper.parts.firstWhere((p) => p.id == 'mirror');
    expect(mirror.questions.map((q) => q.category).toSet(), {'mirror_shape', 'mirror_text'});
  });

  test('no question appears twice on a paper', () {
    final paper = TestPaper.generate(seed: 4);
    final all = [for (final p in paper.parts) ...p.questions];
    final sigs = {for (final q in all) '${q.type}|${q.puzzle}|${q.options.map(key).join(',')}'};
    expect(sigs.length, 40);
  });

  test('each set holds the same questions with the right answers', () {
    final paper = TestPaper.generate(seed: 5);
    final sets = paper.sets(7, seed: 1);
    expect(sets.length, 7);
    expect([for (final s in sets) s.number], [1, 2, 3, 4, 5, 6, 7]);
    for (final s in sets) {
      expect(s.answerKey.length, 40);
      for (int p = 0; p < 10; p++) {
        final orig = paper.parts[p].questions;
        final mine = s.parts[p].questions;
        // Same questions (same puzzle, same four options), possibly
        // reordered, and each answer is still the same figure.
        String sig(q) => '${q.puzzle}|${(q.options.map(key).toList()..sort()).join(',')}';
        expect(mine.map(sig).toSet(), orig.map(sig).toSet());
        for (final q in mine) {
          final o = orig.firstWhere((x) => sig(x) == sig(q));
          expect(key(q.options[q.correctIndex]), key(o.options[o.correctIndex]));
        }
      }
    }
  });

  test('every part still goes easy to hard in every set', () {
    final paper = TestPaper.generate(seed: 6);
    for (final s in paper.sets(5, seed: 2)) {
      for (final p in s.parts) {
        expect(p.levels, TestPaper.partLevels, reason: 'set ${s.number} ${p.id}');
      }
    }
  });

  test('neighbouring students get different answer keys', () {
    final sets = TestPaper.generate(seed: 7).sets(6, seed: 3);
    for (int i = 0; i + 1 < sets.length; i++) {
      final a = sets[i].answerKey, b = sets[i + 1].answerKey;
      final same = [for (int k = 0; k < 40; k++) if (a[k] == b[k]) k].length;
      expect(same, lessThan(20), reason: 'sets ${i + 1} and ${i + 2} share $same answers');
    }
  });
}
