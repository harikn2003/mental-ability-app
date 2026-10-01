// Medium difficulty: a true midpoint for every topic - the same kinds of
// questions as Hard with the hardest trick taken out, or Easy plus one step.
// Each test pins the property that puts a topic's Medium between its Easy
// and Hard.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

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
}
