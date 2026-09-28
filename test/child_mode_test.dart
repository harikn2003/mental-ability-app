// Child mode: once a coordinator starts a session and hands the device over,
// the child can't get back to the setup screen without a teacher's hold.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/screens/quiz_screen.dart';
import 'package:mental_ability_app/screens/session_config_screen.dart';
import 'package:mental_ability_app/screens/student_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppLocale.setLang('EN');
    SharedPreferences.setMockInitialValues({});
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1084, 2412);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  testWidgets('quiz: a tap on Leave only says "ask your teacher"; a hold offers to leave', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(
      home: QuizScreen(mode: 'analogy', totalQuestions: 5, timePerQuestion: 'unlimited', biasEnabled: false, childMode: true),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final leave = find.text(AppLocale.s('leave_quiz'));
    await tester.tap(leave);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppLocale.s('child_locked_hint')), findsOneWidget);
    expect(find.text(AppLocale.s('abandon_quiz_title')), findsNothing);

    await tester.longPress(leave);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppLocale.s('abandon_quiz_title')), findsOneWidget);
    await tester.tap(find.text(AppLocale.s('cancel')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('result: Try Again restarts the session, no Full Report, teacher hold exits to setup', (tester) async {
    phone(tester);
    Widget result() => StudentResultScreen(
          score: 1,
          totalQuestions: 2,
          timeSpent: const [5, 5],
          categoryStats: const {'analogy': [true, false]},
          attempts: const [],
          childMode: true,
          restart: () => const QuizScreen(mode: 'analogy', totalQuestions: 2, timePerQuestion: 'unlimited', biasEnabled: false, childMode: true),
        );
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: result()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(AppLocale.s('full_report')), findsNothing);

    await tester.ensureVisible(find.text(AppLocale.s('try_again')));
    await tester.tap(find.text(AppLocale.s('try_again')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.byType(SessionConfigScreen), findsNothing);

    // Back on a fresh result screen: a teacher's hold leaves to setup.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: result()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text(AppLocale.s('teacher_hold_exit')));
    await tester.longPress(find.text(AppLocale.s('teacher_hold_exit')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionConfigScreen), findsOneWidget);
  });

  testWidgets('New Session: the child-mode switch is saved with the setup', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: const SessionConfigScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start Random Challenge'));
    await tester.pump(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('last_setup_child'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
