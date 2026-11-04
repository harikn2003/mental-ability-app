// In the quiz: a wrong / skipped Mirror, Punch Hole or Embedded answer shows
// the explanation under the result, and Next waits for it; a right answer
// is unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/screens/quiz_screen.dart';
import 'package:mental_ability_app/widgets/explanation_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _next = find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'next_btn');
bool _nextEnabled(WidgetTester t) => t.widget<FloatingActionButton>(_next).onPressed != null;

Future<void> _start(WidgetTester tester, String topic) async {
  tester.view.physicalSize = const Size(1084, 2412); // the A142
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  QuestionGenerator.seed(17);
  await tester.pumpWidget(MaterialApp(
    home: QuizScreen(mode: topic, totalQuestions: 10, timePerQuestion: 'none', biasEnabled: false, initialWeights: const {}),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // cancels the quiz timer
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  for (final topic in ['mirror_shape', 'mirror_text', 'punch_hole', 'embedded']) {
    testWidgets('$topic: wrong answer explains, Next waits for it; right answer unchanged', (tester) async {
      await _start(tester, topic);
      var sawWrong = false, sawRight = false;
      for (int q = 0; q < 8 && !(sawWrong && sawRight); q++) {
        await tester.tap(find.text('A').first, warnIfMissed: false);
        await tester.pump();
        if (find.textContaining('Correct!').evaluate().isNotEmpty) {
          sawRight = true;
          expect(find.byType(ExplanationPanel), findsNothing);
          expect(_nextEnabled(tester), isTrue);
        } else {
          sawWrong = true;
          expect(find.byType(ExplanationPanel), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1500));
          expect(_nextEnabled(tester), isFalse, reason: 'Next unlocked before the explanation ended');
          await tester.pump(const Duration(milliseconds: 1800));
          expect(_nextEnabled(tester), isTrue, reason: 'Next still locked after the explanation');
        }
        // Next straight away: the panel goes mid-replay-free, nothing throws.
        await tester.tap(_next);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(sawWrong, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await _end(tester);
    });
  }

  testWidgets('skip: explanation shown, Next waits for it', (tester) async {
    await _start(tester, 'punch_hole');
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.byType(ExplanationPanel), findsOneWidget);
    expect(_nextEnabled(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 3300));
    expect(_nextEnabled(tester), isTrue);
    await _end(tester);
  });

  testWidgets('topic without explanations: wrong answer unlocks after 1.2 s as before', (tester) async {
    await _start(tester, 'odd_man');
    for (int q = 0; q < 8; q++) {
      await tester.tap(find.text('A').first, warnIfMissed: false);
      await tester.pump();
      if (find.textContaining('Correct!').evaluate().isEmpty) {
        expect(find.byType(ExplanationPanel), findsNothing);
        await tester.pump(const Duration(milliseconds: 1300));
        expect(_nextEnabled(tester), isTrue);
        break;
      }
      await tester.tap(_next);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _end(tester);
  });

  testWidgets('punch hole hard: the explanation is on screen, above the buttons', (tester) async {
    tester.view.physicalSize = const Size(1084, 2412);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    QuestionGenerator.seed(17);
    await tester.pumpWidget(MaterialApp(
      home: QuizScreen(mode: 'punch_hole', totalQuestions: 10, timePerQuestion: 'none', biasEnabled: false, initialWeights: const {}, isHardMode: true),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final r = tester.getRect(find.byType(ExplanationPanel));
    expect(r.bottom, lessThanOrEqualTo(screen.height - 76), reason: 'explanation hidden under the buttons');
    await _end(tester);
  });
}
