// The answer-explanation panel: plays once (~3 s), ends on the correct
// option, replays on demand, and respects "reduce motion".

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/painters/line_figure_painter.dart';
import 'package:mental_ability_app/widgets/explanation_panel.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';

ReasoningQuestion _q(String cat, Difficulty d, [bool Function(ReasoningQuestion)? ok]) {
  QuestionGenerator.seed(11);
  for (int i = 0; i < 400; i++) {
    final q = QuestionGenerator.generate(cat, difficulty: d);
    if (ok == null || ok(q)) return q;
  }
  throw StateError('no $cat question');
}

/// Every key of [answer] appears with the same value in a rendered option.
Finder _showsAnswer(Map<String, dynamic> answer) => find.byWidgetPredicate((w) =>
    w is OptionRenderer && answer.entries.every((e) => jsonEncode(w.data[e.key]) == jsonEncode(e.value)));

/// How visible the correct option is: its fade-in opacity, or for Embedded
/// (always shown) how far the rest has faded and the hidden shape lit up.
double _shown(WidgetTester tester, Map<String, dynamic> answer) {
  final f = _showsAnswer(answer).first;
  final data = tester.widget<OptionRenderer>(f).data;
  if (data.containsKey('dim')) return (data['dim'] as num).toDouble();
  return tester.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;
}

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  final cases = {
    'mirror shape': _q('mirror_shape', Difficulty.easy),
    'mirror line figure': _q('mirror_shape', Difficulty.hard, (q) => q.type == 'mirror_line_fig'),
    'mirror text': _q('mirror_text', Difficulty.easy),
    'mirror clock': _q('mirror_text', Difficulty.hard, (q) => q.type == 'mirror_clock'),
    'punch hole two folds': _q('punch_hole', Difficulty.hard, (q) => (q.puzzle['folds'] as List?)?.length == 2),
    'punch hole legacy': _q('punch_hole', Difficulty.easy),
    'paper fold': _q('punch_hole', Difficulty.medium, (q) => q.type == 'paper_fold'),
    'embedded shapes': _q('embedded', Difficulty.easy),
    'embedded lines': _q('embedded', Difficulty.hard, (q) => q.type == 'embedded_line'),
  };

  for (final MapEntry(key: name, value: q) in cases.entries) {
    testWidgets('$name: finishes once at ~3 s and ends on the correct option', (tester) async {
      var finished = 0;
      final answer = q.options[q.correctIndex];
      await tester.pumpWidget(_host(ExplanationPanel(question: q, onFinished: () => finished++)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_shown(tester, answer), 0, reason: 'answer shown before the explanation');
      await tester.pump(const Duration(milliseconds: 2300));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(finished, 1);
      expect(_shown(tester, answer), 1, reason: 'the last frame is not the correct option');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('replay plays it again', (tester) async {
    var finished = 0;
    await tester.pumpWidget(_host(ExplanationPanel(question: cases['mirror shape']!, onFinished: () => finished++)));
    await tester.pump(const Duration(milliseconds: 3100));
    expect(finished, 1);
    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.pump(); // the replay starts on this frame
    await tester.pump(const Duration(milliseconds: 1500));
    expect(finished, 1);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(finished, 2);
  });

  testWidgets('reduce motion: the end frame at once', (tester) async {
    var finished = 0;
    final q = cases['punch hole two folds']!;
    await tester.pumpWidget(_host(ExplanationPanel(question: q, onFinished: () => finished++), reduceMotion: true));
    await tester.pump();
    expect(finished, 1);
    await tester.pump();
    expect(_shown(tester, q.options[q.correctIndex]), 1, reason: 'reduce motion must show the end frame');
  });

  testWidgets('paper fold: the folded sheet ends where the answer appears (no sideways jump)', (tester) async {
    final q = cases['paper fold']!;
    final key = GlobalKey();
    await tester.pumpWidget(_host(RepaintBoundary(key: key, child: SizedBox(width: 380, child: ExplanationPanel(question: q)))));
    Future<(Uint8List, int)> grab() async {
      late Uint8List bytes;
      late int w;
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        w = img.width;
        bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        img.dispose();
      });
      return (bytes, w);
    }

    // The 140 px figure box, inset past the green frame.
    final box = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LineFigurePainter).first);
    final origin = tester.getTopLeft(find.byKey(key));
    final crop = box.shift(-origin).deflate(6);
    Set<int> ink((Uint8List, int) img) {
      final (b, w) = img;
      return {
        for (int y = crop.top.ceil(); y < crop.bottom.floor(); y++)
          for (int x = crop.left.ceil(); x < crop.right.floor(); x++)
            if (b[(y * w + x) * 4 + 3] > 128 && b[(y * w + x) * 4] < 110) y * w + x,
      };
    }

    await tester.pump(const Duration(milliseconds: 2400)); // folded, before the cross-fade
    final folded = ink(await grab());
    await tester.pump(const Duration(milliseconds: 700)); // the answer
    final (ab, aw) = await grab();
    final answer = ink((ab, aw));
    bool near(int p) {
      final x = p % aw, y = p ~/ aw;
      for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
          if (folded.contains((y + dy) * aw + x + dx)) return true;
        }
      }
      return false;
    }

    final missed = answer.where((p) => !near(p)).length;
    expect(answer, isNotEmpty);
    expect(missed / answer.length, lessThan(0.15), reason: '${(100 * missed / answer.length).round()}% of the answer has no folded line under it');
  });

  testWidgets('a topic without an explanation shows nothing', (tester) async {
    QuestionGenerator.seed(3);
    final q = QuestionGenerator.generate('odd_man');
    var finished = 0;
    await tester.pumpWidget(_host(ExplanationPanel(question: q, onFinished: () => finished++)));
    await tester.pump(const Duration(seconds: 4));
    expect(ExplanationPanel.has(q), isFalse);
    expect(find.byType(OptionRenderer), findsNothing);
    expect(finished, 0);
  });
}
