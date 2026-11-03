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

  test('embedded: wrong options never hide the shape, turned or flipped', () {
    for (final lite in [false, true]) {
      ExamStyleGenerator.seed(5);
      var n = 0;
      for (int i = 0; i < 300; i++) {
        final q = ExamStyleGenerator.embeddedFigure(lite: lite);
        if (q == null) continue;
        n++;
        final t = LineFig.fromMap(Map<String, dynamic>.from(q.puzzle['target'] as Map));
        for (int o = 0; o < 4; o++) {
          final host = LineFig.fromMap(Map<String, dynamic>.from(q.options[o]));
          final hits = t.dihedral().where(host.embeds).length;
          if (o == q.correctIndex) {
            expect(host.embeds(t), isTrue);
          } else {
            expect(hits, 0, reason: 'option $o hides the shape turned or flipped');
          }
        }
      }
      expect(n, greaterThan(200));
    }
  });

  test('pattern quarters: wrong options differ by a turn or by the black half, never a dot or one stroke', () {
    ExamStyleGenerator.seed(6);
    var n = 0;
    for (int i = 0; i < 300; i++) {
      final q = ExamStyleGenerator.patternQuarter();
      if (q == null) continue;
      n++;
      final opts = [for (final o in q.options) LineFig.fromMap(Map<String, dynamic>.from(o))];
      for (int a = 0; a < 4; a++) {
        for (int b = a + 1; b < 4; b++) {
          // Same figure turned or flipped, or the black half moved.
          final turned = flipClass(opts[a]) == flipClass(opts[b]);
          final blackMoved = flipClass(opts[a].copyWith(tris: {})) == flipClass(opts[b].copyWith(tris: {}));
          expect(turned || blackMoved, isTrue, reason: '${q.options[a]} vs ${q.options[b]}');
        }
      }
    }
    expect(n, greaterThan(200));
  });
}
