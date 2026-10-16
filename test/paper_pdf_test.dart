// Printed test paper: every page lays out on A4 without overflow in all
// three languages with 20 questions a side in two columns, and the PDF
// holds two sides (one sheet) per student plus the key.

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
        if (page is PaperPage) expect(find.byType(PaperQuestion), findsNWidgets(questionsPerSide));
      }
    });
  }

  testWidgets('the PDF has two sides per student and an answer key, as grey images', (tester) async {
    final sets = TestPaper.generate(seed: 12).sets(3, seed: 2);
    final done = <int>[];
    final bytes = await tester.runAsync(() => buildPaperPdf(sets, tester.view, onProgress: (d, _) => done.add(d)));
    expect(done, [for (int p = 1; p <= 7; p++) p]);
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
    final text = String.fromCharCodes(bytes);
    expect('/DeviceGray'.allMatches(text).length, 7);
  });

  test('every side fits 20 questions with figures at least 10 mm wide', () {
    for (int seed = 1; seed <= 40; seed++) {
      final set = TestPaper.generate(seed: seed).sets(1, seed: seed).single;
      for (int side = 0; side < sidesPerSet; side++) {
        final size = PaperPage(set: set, side: side, pageNumber: 1, totalPages: 1).figureSize;
        expect(size, isNotNull, reason: 'seed $seed side $side does not fit');
        expect(size, greaterThanOrEqualTo(28.3), reason: 'seed $seed side $side: ${size! / 72 * 25.4} mm');
      }
    }
  });

  test('the answer key moves to more pages for a big class', () {
    final sets = TestPaper.generate(seed: 13).sets(AnswerKeyPage.setsPerPage + 1, seed: 3);
    final pages = paperPrintout(sets);
    expect(pages.length, sidesPerSet * sets.length + 2);
  });
}
