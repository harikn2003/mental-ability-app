// Coordinator's print screen: the student counter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/screens/print_paper_screen.dart';

void main() {
  testWidgets('the counter steps by one and never goes below 1', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrintPaperScreen()));
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    for (int i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
    }
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
