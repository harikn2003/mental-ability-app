// The question screen must draw figures exactly like the answer options.
//
// Regression (device screenshot 2026-09-25): a Hard Mirror Shape target -
// filled diamond with an inner L and a corner mark - showed on the question
// screen as a plain black diamond, because the question screen used the old
// FigurePainter (inner shape in dark ink on the dark fill; no corner mark)
// while the options showed the details. The question couldn't be solved.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';
import 'package:mental_ability_app/widgets/question_renderer.dart';

Future<List<Uint8List>> _capture(WidgetTester tester, List<Widget> widgets, double size) async {
  final keys = [for (final _ in widgets) GlobalKey()];
  await tester.pumpWidget(MaterialApp(
    home: Material(
      color: Colors.white,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < widgets.length; i++)
          RepaintBoundary(key: keys[i], child: SizedBox.square(dimension: size, child: widgets[i])),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  final out = <Uint8List>[];
  await tester.runAsync(() async {
    for (final k in keys) {
      final img = await (k.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      out.add((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List());
      img.dispose();
    }
  });
  return out;
}

void main() {
  testWidgets('filled figure: the inner shape is visible on the question screen', (tester) async {
    // Filled diamond with an inner L (painter code 8 + 1), as Hard Mirror Shape uses.
    const target = {'shape': 3, 'filled': true, 'rotation': 0, 'mirror': false, 'dots': 0, 'inner': 9, 'lines': 0, 'missingCorner': 0, 'dense': true};
    const size = 88.0;
    final px = (await _capture(tester, [QuestionRenderer.figure(target, size: size)], size)).single;
    // Count light pixels in the central region, which lies inside the dark
    // diamond: they can only come from the inner shape / corner mark.
    var light = 0;
    for (int y = 30; y < 58; y++) {
      for (int x = 30; x < 58; x++) {
        final i = (y * size.toInt() + x) * 4;
        if (px[i] > 200 && px[i + 1] > 200 && px[i + 2] > 200) light++;
      }
    }
    expect(light, greaterThan(20), reason: 'inner L invisible - question figure drawn with the wrong painter?');
  });

  testWidgets('details on a filled shape stay visible where they leave the fill', (tester) async {
    // Device screenshot 2026-09-25: filled L (shape 8) + inner triangle +
    // corner mark; parts of the white details fell in the L's empty notch
    // and vanished white-on-white. Details are now orange with a white
    // outline - count orange pixels over the plain white background.
    const fig = {'shape': 8, 'filled': true, 'rotation': 0, 'mirror': false, 'dots': 0, 'inner': 3, 'lines': 0, 'missingCorner': 0, 'dense': true};
    const size = 88.0;
    final px = (await _capture(tester, [QuestionRenderer.figure(fig, size: size)], size)).single;
    bool isOrange(int i) => px[i] > 190 && px[i + 1] > 60 && px[i + 1] < 140 && px[i + 2] < 90;
    var orange = 0;
    for (int i = 0; i < px.length; i += 4) {
      if (isOrange(i)) orange++;
    }
    expect(orange, greaterThan(40), reason: 'details on a filled figure should be drawn in the contrasting colour');
  });

  testWidgets('question figures and answer options render identically', (tester) async {
    QuestionGenerator.seed(3);
    QuestionGenerator.resetSession();
    // Figure data from every category whose puzzle shows shape figures.
    final samples = <Map<String, dynamic>>[];
    for (final c in ['mirror_shape', 'embedded', 'analogy', 'figure_series', 'pattern', 'figure_match']) {
      for (final hard in [false, true]) {
        for (int i = 0; i < 6; i++) {
          final q = QuestionGenerator.generate(c, isHardMode: hard);
          for (final key in ['target', 'A', 'B', 'C']) {
            final v = q.puzzle[key];
            if (v is Map) samples.add(Map<String, dynamic>.from(v));
          }
        }
      }
    }
    expect(samples, isNotEmpty);
    for (final s in samples) {
      final both = await _capture(tester, [QuestionRenderer.figure(s, size: 64), OptionRenderer(data: s, size: 64)], 64);
      expect(both[0], both[1], reason: 'question/option render differ for $s');
    }
  });
}
