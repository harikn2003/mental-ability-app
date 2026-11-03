// No figure in any question has a dot nobody can see: under a black
// half-cell or on a diagonal (tester, 2026-10-19: Figure Match target with
// a dot hidden under its triangle).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

/// Every line figure inside [m], however deeply nested.
Iterable<Map<String, dynamic>> lineFigs(Object? m) sync* {
  if (m is Map) {
    if (m['type'] == 'line_fig') yield Map<String, dynamic>.from(m);
    for (final v in m.values) {
      yield* lineFigs(v);
    }
  } else if (m is List) {
    for (final v in m) {
      yield* lineFigs(v);
    }
  }
}

void main() {
  const topics = ['odd_man', 'figure_match', 'pattern', 'figure_series', 'analogy', 'geo_completion',
      'mirror_shape', 'mirror_text', 'punch_hole', 'embedded', 'space_vis'];
  for (final topic in topics) {
    test('$topic: no hidden detail', () {
      final bad = <String>{};
      for (final d in Difficulty.values) {
        QuestionGenerator.seed(21);
        for (int i = 0; i < 300; i++) {
          if (i % 20 == 0) QuestionGenerator.resetSession();
          final q = QuestionGenerator.generate(topic, difficulty: d);
          for (final f in lineFigs({'p': q.puzzle, 'o': q.options})) {
            if (LineFig.fromMap(f).hasHiddenDetail) bad.add('${d.name} ${q.type}');
          }
        }
      }
      expect(bad, isEmpty);
    });
  }
}
