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
