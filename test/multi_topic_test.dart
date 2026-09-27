// Coordinators can combine several topics in one session.
//
// Also a regression: weak-areas practice passed weights for the weak topics
// only, and the quiz still drew every other topic at weight 1. A topic list
// now restricts the session to exactly those topics.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/screens/quiz_screen.dart';
import 'package:mental_ability_app/screens/session_config_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real letter widths (the default test font's glyphs are much wider than
/// any real font's, which makes rows overflow that fit on a phone).
Future<void> _realFont() async {
  const dir = 'C:/Flutter/flutter/bin/cache/artifacts/material_fonts';
  final f = File('$dir/roboto-regular.ttf');
  if (!f.existsSync()) return;
  Future<ByteData> load(String n) async => ByteData.sublistView(File('$dir/$n').readAsBytesSync());
  for (final family in ['Roboto', 'Lexend']) {
    await (FontLoader(family)..addFont(load('roboto-regular.ttf'))..addFont(load('roboto-bold.ttf'))).load();
  }
}

void main() {
  setUpAll(_realFont);
  setUp(() {
    AppLocale.setLang('EN');
    SharedPreferences.setMockInitialValues({});
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1084, 2412);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  testWidgets('a topic list keeps the whole session on those topics', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(
      home: QuizScreen(
        mode: 'random',
        totalQuestions: 12,
        timePerQuestion: 'unlimited',
        biasEnabled: true,
        // Weak-areas style: high weight on one, the other listed too.
        initialWeights: {'analogy': 5, 'mirror_shape': 2},
        topics: ['analogy', 'mirror_shape'],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    // Header topic labels for the allowed topics.
    final allowed = {AppLocale.s('topic_analogy'), AppLocale.s('topic_mirror')};
    final seen = <String>{};
    for (int q = 0; q < 12; q++) {
      // The header shows the current topic's label; find which one it is.
      const keys = ['topic_pattern', 'topic_mirror', 'topic_odd', 'topic_analogy', 'topic_figmatch', 'topic_series',
          'topic_geo', 'topic_punch', 'topic_embedded', 'topic_space_vis'];
      final all = {for (final k in keys) AppLocale.s(k)};
      final topic = all.firstWhere((l) => find.text(l).evaluate().isNotEmpty);
      seen.add(topic);
      if (q == 11) break; // don't press Finish (that saves the session)
      await tester.tap(find.byIcon(Icons.skip_next_rounded).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'next_btn'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(seen.difference(allowed), isEmpty, reason: 'questions from other topics: ${seen.difference(allowed)}');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tapping topic tiles combines them; Random Mix clears them', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: const SessionConfigScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text(text));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Start Random Challenge'), findsOneWidget);
    await tap(AppLocale.s('analogy'));
    expect(find.text('Start ${AppLocale.s('cat_analogy')}'), findsOneWidget);
    await tap(AppLocale.s('mirror_shape'));
    expect(find.text('Start 2 Topics'), findsOneWidget);
    await tap(AppLocale.s('analogy')); // untick
    expect(find.text('Start ${AppLocale.s('cat_mirror_shape')}'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pump(const Duration(milliseconds: 300));
    await tap(AppLocale.s('random_mix'));
    expect(find.text('Start Random Challenge'), findsOneWidget);
  });

  testWidgets('the last setup comes back on the next launch', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({
      'last_setup_count': 40,
      'last_setup_time': '1m',
      'last_setup_hard': true,
      'last_setup_bias': false,
      'last_setup_mode': 'topics',
      'last_setup_topics': ['analogy', 'figure_series'],
    });
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: const SessionConfigScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('40 ${AppLocale.s('questions_label')}'), findsOneWidget);
    expect(find.text('Start 2 Topics'), findsOneWidget);
    expect(find.text(AppLocale.s('hard_desc')), findsOneWidget); // Hard is selected
  });

  testWidgets('a remembered weak-areas session falls back to Random Mix when nothing is weak', (tester) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({'last_setup_mode': 'weak_areas'});
    await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: const SessionConfigScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Start Random Challenge'), findsOneWidget);
  });
}
