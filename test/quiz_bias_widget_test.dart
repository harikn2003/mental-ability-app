import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/screens/quiz_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const categories = [
    'pattern',
    'analogy',
    'odd_man',
    'mirror_shape',
    'figure_match',
    'figure_series',
    'geo_completion',
    'mirror_text',
    'punch_hole',
    'embedded',
  ];

  testWidgets('random mode bias updates weights over 50 answered questions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final controller = QuizTestController();
    final rng = Random(13579);
    final selectedCounts = <String, int>{for (final c in categories) c: 0};
    final wrongCounts = <String, int>{for (final c in categories) c: 0};

    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          mode: 'random',
          totalQuestions: 50,
          timePerQuestion: 'unlimited',
          biasEnabled: true,
          saveSessionHistory: false,
          disableWrongAnswerLockDelay: true,
          initialWeights: {for (final c in categories) c: 1},
          testController: controller,
        ),
      ),
    );
    await tester.pump();

    for (int i = 0; i < 50; i++) {
      final q = controller.currentQuestion;
      expect(q, isNotNull, reason: 'Missing current question at step $i');
      final question = q!;
      selectedCounts[question.category] =
          selectedCounts[question.category]! + 1;

      final answerCorrectly = rng.nextBool();
      final chosenIndex = answerCorrectly
          ? question.correctIndex
          : (question.correctIndex + 1) % question.options.length;
      if (!answerCorrectly) {
        wrongCounts[question.category] = wrongCounts[question.category]! + 1;
      }

      controller.answerIndex(chosenIndex);
      await tester.pump();

      controller.next();
      await tester.pump();
    }

    // Let the final summary route and dispose logic settle enough to observe it.
    await tester.pump(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final finalWeights = <String, int>{};
    for (final category in categories) {
      final weight = prefs.getInt('bias_weights_$category') ?? 1;
      finalWeights[category] = weight;
      expect(weight, inInclusiveRange(1, 10));
    }

    expect(finalWeights.values.any((w) => w > 1), isTrue);
    expect(selectedCounts.values.where((v) => v > 0).length, greaterThan(1));
    expect(find.text('Session Summary'), findsOneWidget);

    final highestWrong = wrongCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final lowestWrong = wrongCounts.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );
    expect(
      finalWeights[highestWrong.key]!,
      greaterThanOrEqualTo(finalWeights[lowestWrong.key]!),
    );
  });
}
