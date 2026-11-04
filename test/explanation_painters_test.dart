// Drawing support for answer explanations: the punched paper opening fold by
// fold (ending exactly on the answer card) and the hidden-figure highlight.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/explanation.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/painters/line_figure_painter.dart';
import 'package:mental_ability_app/painters/punch_painter.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';

const _size = 120.0;

/// Paints [painter] on a white square and returns the pixels composited over
/// white (RGBA rows).
Future<Uint8List> _paint(WidgetTester tester, CustomPainter painter) async {
  late Uint8List out;
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _size, _size), Paint()..color = Colors.white);
    painter.paint(canvas, const Size(_size, _size));
    final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
    out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    img.dispose();
  });
  return out;
}

List<int> _px(Uint8List b, int x, int y) {
  final o = (y * _size.toInt() + x) * 4;
  return [b[o], b[o + 1], b[o + 2]];
}

ReasoningQuestion _find(String cat, Difficulty d, bool Function(ReasoningQuestion) ok) {
  QuestionGenerator.seed(7);
  for (int i = 0; i < 400; i++) {
    final q = QuestionGenerator.generate(cat, difficulty: d);
    if (ok(q)) return q;
  }
  throw StateError('no $cat question found');
}

void main() {
  for (final (name, folds) in [('one fold', 1), ('two folds', 2)]) {
    testWidgets('unfold ($name): every frame paints; the last equals the answer card', (tester) async {
      final q = _find('punch_hole', Difficulty.hard, (q) => q.type == 'punch_hole_exam' && (q.puzzle['folds'] as List).length == folds);
      final e = Explanation.of(q) as UnfoldExplanation;
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, folds.toDouble()]) {
        if (p > folds) continue;
        await _paint(tester, UnfoldPainter(folds: e.folds, stages: e.stages, progress: p));
      }
      final last = await _paint(tester, UnfoldPainter(folds: e.folds, stages: e.stages, progress: folds.toDouble()));
      final card = await _paint(tester, PunchPainter(e.answer));
      var differ = 0;
      for (int i = 0; i < last.length; i += 4) {
        if ((last[i] - card[i]).abs() + (last[i + 1] - card[i + 1]).abs() + (last[i + 2] - card[i + 2]).abs() > 75) differ++;
      }
      expect(differ / (last.length / 4), lessThan(0.01), reason: 'end frame differs from the answer card');
    });
  }

  testWidgets('legacy double fold (fold_axis 2) unfolds too', (tester) async {
    final q = _find('punch_hole', Difficulty.hard, (q) => q.type == 'punch_hole_double_fold');
    final e = Explanation.of(q) as UnfoldExplanation;
    expect(e.folds, ['v', 'h']);
    for (final p in [0.0, 0.5, 1.0, 1.5, 2.0]) {
      await _paint(tester, UnfoldPainter(folds: e.folds, stages: e.stages, progress: p));
    }
  });

  testWidgets('line drawing: dim fades the lines, the hidden figure turns green', (tester) async {
    final fig = {
      'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false,
      'segs': [[0, 0, 4, 0], [0, 2, 4, 2]],
    };
    final plain = await _paint(tester, LineFigurePainter(fig));
    final lit = await _paint(tester, LineFigurePainter({...fig, 'dim': 1.0, 'highlight_segs': [[0, 2, 4, 2]]}));
    // Lattice: pad 12% of 120 = 14.4, unit = (120 - 28.8) / 4 = 22.8.
    final top = (14.4).round(), mid = (14.4 + 2 * 22.8).round();
    final g = _px(lit, 60, mid);
    expect(g[1], greaterThan(g[0] + 60), reason: 'highlighted line is green: $g');
    expect(_px(plain, 60, top)[0], lessThan(80), reason: 'normal line is dark');
    expect(_px(lit, 60, top)[0], greaterThan(150), reason: 'dimmed line is faint');
  });

  testWidgets('three-shape option: highlight and dim paint at every step', (tester) async {
    final q = _find('embedded', Difficulty.easy, (q) => q.options[q.correctIndex]['type'] == 'embedded_option');
    final e = Explanation.of(q) as EmbeddedExplanation;
    for (final dim in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(MaterialApp(
        home: OptionRenderer(data: {...e.answer, 'highlight': e.shapeIndex, 'dim': dim}, size: 140),
      ));
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(Opacity), findsNWidgets(2));
  });
}
