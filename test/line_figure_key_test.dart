// LineFig.key answers "do these two figures look alike", so a stroke that
// runs along a black half-cell's edge (and so can't be seen) must not make
// two figures count as different.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/exam_style_generator.dart';
import 'package:mental_ability_app/engine/line_figure.dart';

void main() {
  test('a stroke on a black half-cell edge does not change the key', () {
    // Black triangle in cell (0,0), right angle top-right: its long edge
    // runs from (0,0) to (1,1).
    final plain = LineFig(2, 2, segs: {(1, 1, 2, 1)}, tris: {(0, 0, 1)});
    expect(plain.copyWith(segs: {...plain.segs, (0, 0, 1, 1)}).key, plain.key, reason: 'long edge');
    expect(plain.copyWith(segs: {...plain.segs, (0, 0, 1, 0)}).key, plain.key, reason: 'short edge');
    expect(plain.copyWith(segs: {...plain.segs, (0, 1, 1, 0)}).key, isNot(plain.key), reason: 'a visible stroke');
  });

  test('a stroke on the frame does not change the key', () {
    final f = LineFig(4, 4, frame: true, segs: {(1, 1, 2, 2)});
    expect(f.copyWith(segs: {...f.segs, (0, 0, 1, 0)}).key, f.key, reason: 'top edge');
    expect(f.copyWith(segs: {...f.segs, (4, 2, 4, 3)}).key, f.key, reason: 'right edge');
    final open = LineFig(4, 4, segs: {(1, 1, 2, 2)});
    expect(open.copyWith(segs: {...open.segs, (0, 0, 1, 0)}).key, isNot(open.key), reason: 'no frame: the stroke shows');
  });

  test('a dot on a diagonal or a black half-cell does not change the key', () {
    final f = LineFig(4, 4, segs: {(1, 1, 2, 2)}, tris: {(3, 3, 0)});
    expect(f.copyWith(dots: {(1, 1)}).key, f.key, reason: 'dot on a diagonal');
    expect(f.copyWith(dots: {(3, 3)}).key, f.key, reason: 'dot on the black half-cell');
    expect(f.copyWith(dots: {(0, 0)}).key, isNot(f.key), reason: 'a visible dot');
  });

  test('figure match options never look alike', () {
    for (final lite in [true, false]) {
      ExamStyleGenerator.seed(9);
      for (int i = 0; i < 300; i++) {
        final q = ExamStyleGenerator.figureMatch(lite: lite)!;
        final keys = {for (final o in q.options) LineFig.fromMap(Map<String, dynamic>.from(o)).key};
        expect(keys, hasLength(4), reason: '${q.options}');
      }
    }
  });

  test('pattern quarter options never look alike', () {
    ExamStyleGenerator.seed(4);
    var n = 0;
    for (int i = 0; i < 400; i++) {
      final q = ExamStyleGenerator.patternQuarter();
      if (q == null) continue;
      n++;
      final keys = {for (final o in q.options) LineFig.fromMap(Map<String, dynamic>.from(o)).key};
      expect(keys, hasLength(4), reason: '${q.options}');
    }
    expect(n, greaterThan(300));
  });
}
