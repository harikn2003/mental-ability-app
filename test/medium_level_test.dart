// Medium difficulty: a true midpoint for every topic - the same kinds of
// questions as Hard with the hardest trick taken out, or Easy plus one step.
// Each test pins the property that puts a topic's Medium between its Easy
// and Hard.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const topics = ['odd_man', 'figure_match', 'pattern', 'figure_series', 'analogy',
    'geo_completion', 'mirror_shape', 'mirror_text', 'punch_hole', 'space_vis', 'embedded'];

void main() {
  test('generate() reports the difficulty it was asked for', () {
    final seen = <Difficulty>[];
    QuestionGenerator.onGenerate = (_, d) => seen.add(d);
    addTearDown(() => QuestionGenerator.onGenerate = null);
    QuestionGenerator.generate('analogy');
    QuestionGenerator.generate('analogy', isHardMode: true);
    QuestionGenerator.generate('analogy', difficulty: Difficulty.medium);
    expect(seen, [Difficulty.easy, Difficulty.hard, Difficulty.medium]);
  });

  test('every topic builds Medium questions with 4 distinct options', () {
    QuestionGenerator.seed(41);
    QuestionGenerator.resetSession();
    for (final t in topics) {
      for (int i = 0; i < 30; i++) {
        final q = QuestionGenerator.generate(t, difficulty: Difficulty.medium);
        expect(q.category, t);
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    }
  });

  List<ReasoningQuestion> medium(String topic, {int n = 200, int seed = 7}) {
    QuestionGenerator.seed(seed);
    QuestionGenerator.resetSession();
    return [for (int i = 0; i < n; i++) QuestionGenerator.generate(topic, difficulty: Difficulty.medium)];
  }

  test('Medium never serves the Sandia matrices except in Pattern', () {
    for (final t in ['odd_man', 'figure_match', 'figure_series', 'analogy']) {
      for (final q in medium(t, n: 100)) {
        expect(q.options.first['type'], isNot('sandia_cell'), reason: '$t served Sandia: ${q.type}');
      }
    }
  });

  test('Medium Analogy (classic share) never changes three things', () {
    final types = {for (final q in medium('analogy')) q.type};
    expect(types.intersection({'analogy_r4', 'analogy_r8'}), isEmpty);
  });

  test('Medium Series (classic share) has no morph series', () {
    final types = {for (final q in medium('figure_series')) q.type};
    expect(types.contains('series_morph'), isFalse);
  });

  test('Medium Pattern serves mirror quarters, never turn quarters', () {
    final quarters = medium('pattern').where((q) => q.type == 'pattern_quarter').toList();
    expect(quarters, isNotEmpty);
    for (final q in quarters) {
      expect(q.puzzle['symmetry'], 'mirror');
    }
  });

  test('Medium Figure Match mixes the lite exam item with the classic one', () {
    final types = {for (final q in medium('figure_match')) q.type};
    expect(types, contains('figure_match_exam'));
  });

  test('Medium Mirror Text words are 4 characters', () {
    for (final q in medium('mirror_text')) {
      if (q.puzzle['is_clock'] == true) continue;
      expect((q.puzzle['content'] as String).length, 4, reason: q.type);
    }
  });
}
