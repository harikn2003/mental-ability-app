import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/main.dart';

void main() {
  testWidgets('App launches and shows session config screen', (
      WidgetTester tester) async {
    AppLocale.setLang('EN');
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // App title is correct
    expect(find.text('New Session'), findsOneWidget);

    // Core UI elements are present
    expect(find.text('Random Mix'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Language toggle switches between EN and MR', (
      WidgetTester tester) async {
    AppLocale.setLang('EN');
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // EN is the default
    expect(find.text('New Session'), findsOneWidget);

    // Tap the language toggle
    await tester.tap(find.text('EN'));
    await tester.pump();

    // Should now show Marathi title
    expect(find.text('नवीन सत्र'), findsOneWidget);

    // Tap again to reach Hindi
    await tester.tap(find.text('मर'));
    await tester.pump();

    expect(find.text('नया सत्र'), findsOneWidget);
  });
}