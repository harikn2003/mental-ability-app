// Printed test paper: every page lays out on A4 without overflow in all
// three languages, and the PDF holds two sides per student plus the key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/engine/test_paper.dart';
import 'package:mental_ability_app/paper/paper_pages.dart';
import 'package:mental_ability_app/paper/paper_pdf.dart';

void main() {
  for (final lang in ['EN', 'HI', 'MR']) {
    testWidgets('$lang: every page fits on A4', (tester) async {
      AppLocale.setLang(lang);
      addTearDown(() => AppLocale.setLang('EN'));
      tester.view.physicalSize = paperPageSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sets = TestPaper.generate(seed: 11).sets(3, seed: 1);
      for (final page in paperPrintout(sets)) {
        await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Align(alignment: Alignment.topLeft, child: page)));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('the PDF has two sides per student and an answer key', (tester) async {
    final sets = TestPaper.generate(seed: 12).sets(3, seed: 2);
    final done = <int>[];
    final bytes = await tester.runAsync(() => buildPaperPdf(sets, tester.view, onProgress: (d, _) => done.add(d)));
    expect(done, [1, 2, 3, 4, 5, 6, 7]);
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
  });

  test('the answer key moves to more pages for a big class', () {
    final sets = TestPaper.generate(seed: 13).sets(AnswerKeyPage.setsPerPage + 1, seed: 3);
    final pages = paperPrintout(sets);
    expect(pages.length, 2 * sets.length + 2);
  });
}
