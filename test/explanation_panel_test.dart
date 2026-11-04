// The answer-explanation panel: plays once (~3 s), ends on the correct
// option, replays on demand, and respects "reduce motion".

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
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
      await tester.pumpWidget(_host(ExplanationPanel(question: q, onFinished: () => finished++)));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(finished, 1);
      expect(_showsAnswer(q.options[q.correctIndex]), findsWidgets);
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
    expect(_showsAnswer(q.options[q.correctIndex]), findsWidgets);
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
