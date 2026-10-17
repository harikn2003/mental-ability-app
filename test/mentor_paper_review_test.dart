// Mentors' review of a printed paper (2026-10-17): no series shows a fifth
// figure, and no Geo option is the answer piece flipped over (a cut-out
// piece can be turned over, so a mirror image fits too).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/exam_style_generator.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

/// Same for a piece and its turned or flipped copies.
String flipClass(LineFig f) => ([for (final g in f.dihedral()) g.shapeKey]..sort()).first;

void main() {
  test('every series shows three figures, then the question mark', () {
    for (final d in Difficulty.values) {
      QuestionGenerator.seed(2);
      for (int i = 0; i < 400; i++) {
        if (i % 20 == 0) QuestionGenerator.resetSession();
        final q = QuestionGenerator.generate('figure_series', difficulty: d);
        expect(q.puzzle['sequence'] as List, hasLength(3), reason: '${d.name} ${q.type}');
      }
    }
  });

  test('geo grid cut: no option is another one turned or flipped', () {
    for (final halfTurns in [false, true]) {
      ExamStyleGenerator.seed(3);
      var n = 0;
      for (int i = 0; i < 300; i++) {
        final q = ExamStyleGenerator.geoCompletion(halfTurnsOnly: halfTurns);
        if (q == null || q.type != 'geo_grid_cut') continue;
        n++;
        final classes = {for (final o in q.options) flipClass(LineFig.fromMap(Map<String, dynamic>.from(o)))};
        expect(classes, hasLength(4), reason: 'two options are the same piece turned or flipped');
      }
      expect(n, greaterThan(200));
    }
  });
}
