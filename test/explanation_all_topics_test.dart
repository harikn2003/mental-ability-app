// Every topic has an explanation for every question it generates, at every
// difficulty.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/widgets/explanation_panel.dart';

void main() {
  const topics = [
    'mirror_shape', 'mirror_text', 'punch_hole', 'embedded', 'figure_series', 'analogy',
    'pattern', 'odd_man', 'figure_match', 'geo_completion', 'space_vis',
  ];
  for (final topic in topics) {
    test('$topic: every question explained', () {
      for (final d in Difficulty.values) {
        QuestionGenerator.seed(77);
        for (int i = 0; i < 300; i++) {
          final q = QuestionGenerator.generate(topic, difficulty: d);
          expect(ExplanationPanel.has(q), isTrue, reason: '${q.type} (${d.name}) has no explanation');
        }
      }
    });
  }
}
