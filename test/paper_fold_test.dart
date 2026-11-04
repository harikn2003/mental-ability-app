import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/paper_fold.dart';

Set<String> _pts(List<Map<String, dynamic>> hs) =>
    {for (final h in hs) '${((h['x'] as num) * 100).round()},${((h['y'] as num) * 100).round()}'};

void main() {
  test('one vertical fold mirrors the hole sideways', () {
    expect(_pts(PaperFold.unfold([{'x': 0.2, 'y': 0.3}], ['v'])), {'20,30', '80,30'});
  });

  test('two folds give four holes', () {
    final hs = PaperFold.unfold([{'x': 0.2, 'y': 0.3}], ['v', 'h']);
    expect(hs.length, 4);
    expect(_pts(hs), contains('80,70'));
  });

  test('a triangle unfolded across a vertical fold points the other way', () {
    final hs = PaperFold.unfold([{'x': 0.2, 'y': 0.6, 'shape': 'tri', 'dir': 1}], ['v']);
    final twin = hs.firstWhere((h) => ((h['x'] as num) * 100).round() == 80);
    expect(twin['dir'], 3);
  });

  test('legacy fold_axis maps to fold codes; folds list wins', () {
    expect(PaperFold.foldsOf({'fold_axis': 0}), ['v']);
    expect(PaperFold.foldsOf({'fold_axis': 1}), ['h']);
    expect(PaperFold.foldsOf({'fold_axis': 2}), ['v', 'h']);
    expect(PaperFold.foldsOf({'folds': ['d', 'a'], 'fold_axis': -1}), ['d', 'a']);
  });

  test('holesKey ignores order and tolerates missing shape', () {
    expect(PaperFold.holesKey([{'x': 0.8, 'y': 0.3}, {'x': 0.2, 'y': 0.3}]),
        PaperFold.holesKey([{'x': 0.2, 'y': 0.3}, {'x': 0.8, 'y': 0.3}]));
  });
}
