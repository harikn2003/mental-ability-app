// The child's result screen.
//
// Regression: "Incorrect" was totalQuestions - score, so skipped questions
// were counted as wrong answers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/screens/student_result_screen.dart';

/// The number shown in the stat pill labelled [label].
String pillValue(WidgetTester tester, String label) {
  final pill = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  final texts = tester.widgetList<Text>(find.descendant(of: pill, matching: find.byType(Text)));
  return texts.map((t) => t.data).firstWhere((s) => s != label)!;
}

Future<void> pumpResult(WidgetTester tester, {required String lang, required int skipped}) async {
  AppLocale.setLang(lang);
  tester.view.physicalSize = const Size(1084, 2412); // a typical phone
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: StudentResultScreen(
      score: 5,
      totalQuestions: 10,
      skipped: skipped,
      timeSpent: List.filled(10, 20),
      categoryStats: const {'analogy': [true, false]},
      attempts: const [],
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('skipped questions are not counted as incorrect', (tester) async {
    await pumpResult(tester, lang: 'EN', skipped: 3);
    expect(pillValue(tester, 'Correct'), '5');
    expect(pillValue(tester, 'Incorrect'), '2');
    expect(pillValue(tester, 'Skipped'), '3');
  });

  testWidgets('no Skipped pill when nothing was skipped', (tester) async {
    await pumpResult(tester, lang: 'EN', skipped: 0);
    expect(pillValue(tester, 'Incorrect'), '5');
    expect(find.text('Skipped'), findsNothing);
  });

  for (final lang in ['MR', 'HI']) {
    testWidgets('four pills fit on a phone in $lang', (tester) async {
      await pumpResult(tester, lang: lang, skipped: 3);
      expect(tester.takeException(), isNull); // no overflow
      expect(pillValue(tester, AppLocale.s('skipped_title')), '3');
    });
  }
}
