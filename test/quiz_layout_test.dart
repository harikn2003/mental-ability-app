// The quiz screen's Skip / Next buttons must never cover the question.
//
// Regression (headless walkthrough, 2026-09-27): the buttons floated over the
// scrolling question area, so on tall questions (Space Visualisation, Figure
// Series, Hard Punch Hole) the result message ("Wrong - correct answer is
// Option B") and even option D sat underneath them until the child scrolled.
// Now the buttons have their own strip and the result scrolls into view.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/screens/quiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final (topic, hard) in [('space_vis', false), ('space_vis', true), ('figure_series', false), ('punch_hole', true), ('pattern', false)]) {
    testWidgets('$topic ${hard ? 'hard' : 'easy'}: result message is on screen, above the buttons', (tester) async {
      tester.view.physicalSize = const Size(1084, 2412); // the A142
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      QuestionGenerator.seed(17);
      await tester.pumpWidget(MaterialApp(
        home: QuizScreen(mode: topic, totalQuestions: 10, timePerQuestion: 'none', biasEnabled: false, initialWeights: const {}, isHardMode: hard),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      const strip = 76.0; // the button strip's height
      for (int q = 0; q < 3; q++) {
        await tester.tap(find.text('A').first, warnIfMissed: false);
        await tester.pump(); // result appears
        await tester.pump(); // scroll animation starts
        await tester.pump(const Duration(milliseconds: 400)); // ...and finishes
        final message = find.textContaining(RegExp(r'correct answer|Correct!'));
        expect(message, findsOneWidget);
        final r = tester.getRect(message);
        expect(r.bottom, lessThanOrEqualTo(screen.height - strip), reason: 'result message hidden under the buttons (question ${q + 1})');
        expect(r.top, greaterThanOrEqualTo(0));

        await tester.pump(const Duration(milliseconds: 1400)); // wrong answers lock Next briefly
        await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'next_btn'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpWidget(const SizedBox()); // cancels the quiz timer
      await tester.pump(const Duration(seconds: 2));
    });
  }

  // Medium: every topic renders at phone size, no overflow, result visible.
  const topics = ['odd_man', 'figure_match', 'pattern', 'figure_series', 'analogy',
      'geo_completion', 'mirror_shape', 'mirror_text', 'punch_hole', 'space_vis', 'embedded'];
  for (final topic in topics) {
    testWidgets('$topic medium: renders at phone size, result above the buttons', (tester) async {
      tester.view.physicalSize = const Size(1084, 2412);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      QuestionGenerator.seed(19);
      await tester.pumpWidget(MaterialApp(
        home: QuizScreen(mode: topic, totalQuestions: 10, timePerQuestion: 'none', biasEnabled: false, initialWeights: const {}, isMediumMode: true),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      const strip = 76.0;
      for (int q = 0; q < 4; q++) {
        await tester.tap(find.text('A').first, warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'question ${q + 1}');
        final r = tester.getRect(find.textContaining(RegExp(r'correct answer|Correct!')));
        expect(r.bottom, lessThanOrEqualTo(screen.height - strip), reason: 'question ${q + 1}');
        await tester.pump(const Duration(milliseconds: 1400));
        await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'next_btn'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
