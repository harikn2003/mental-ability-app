// Coordinator-facing report details.
//
// Regression: the Detailed Report's time chart always drew "Limit (45s)" and
// flagged questions over 45s, whatever time per question was chosen.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/screens/session_summary_screen.dart';

void main() {
  test('time settings read the same everywhere', () {
    AppLocale.setLang('EN');
    expect(AppLocale.timeSettingLabel('30s'), '30s');
    expect(AppLocale.timeSettingLabel('2m'), '2m');
    expect(AppLocale.timeSettingLabel('unlimited'), 'Unlimited');
    expect(AppLocale.timeSettingSeconds('30s'), 30);
    expect(AppLocale.timeSettingSeconds('2m'), 120);
    expect(AppLocale.timeSettingSeconds('unlimited'), isNull);
  });

  for (final (setting, label) in [('30s', 'Limit (30s)'), ('2m', 'Limit (2m)'), ('unlimited', null)]) {
    testWidgets('report time chart shows the session limit: $setting', (tester) async {
      AppLocale.setLang('EN');
      tester.view.physicalSize = const Size(1084, 2412);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: SessionSummaryScreen(
          score: 1,
          totalQuestions: 3,
          timeSpent: const [10, 50, 30],
          categoryStats: const {'analogy': [true, false, false]},
          attempts: const [],
          timeSetting: setting,
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Limit (45s)'), findsNothing);
      // fl_chart draws the line label on its canvas, so check the chart's data.
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final lines = chart.data.extraLinesData.horizontalLines;
      if (label == null) {
        expect(lines, isEmpty);
      } else {
        expect(lines.single.y, AppLocale.timeSettingSeconds(setting)!.toDouble());
        expect(lines.single.label.labelResolver(lines.single), label);
      }
    });
  }

  testWidgets('category breakdown shows the score; Return to Home goes home', (tester) async {
    AppLocale.setLang('EN');
    tester.view.physicalSize = const Size(1084, 2412);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('HOME'))));
    // home -> result stand-in -> report
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('RESULT'))));
    nav.currentState!.push(MaterialPageRoute(
      builder: (_) => const SessionSummaryScreen(
        score: 1,
        totalQuestions: 3,
        timeSpent: [10, 50, 30],
        categoryStats: {'analogy': [true, false, false]},
        attempts: [],
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1/3'), findsOneWidget);
    await tester.ensureVisible(find.text(AppLocale.s('return_home')));
    await tester.tap(find.text(AppLocale.s('return_home')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('RESULT'), findsNothing);
  });
}
