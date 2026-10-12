import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../engine/test_paper.dart';
import 'paper_pages.dart';

/// Print resolution: 300 dpi keeps thin lines and small dots sharp.
const _pixelRatio = 300 / 72;

/// Every page of the printout, in order: two sides per student, then the
/// teacher's answer key.
List<Widget> paperPrintout(List<PaperSet> sets) {
  final keyPages = (sets.length / AnswerKeyPage.setsPerPage).ceil();
  final total = 2 * sets.length + keyPages;
  return [
    for (final s in sets) ...setPages(s, total, 2 * s.number - 1),
    for (int k = 0; k < keyPages; k++)
      AnswerKeyPage(
        sets: sets.sublist(k * AnswerKeyPage.setsPerPage, ((k + 1) * AnswerKeyPage.setsPerPage).clamp(0, sets.length)),
        pageNumber: 2 * sets.length + k + 1,
        totalPages: total,
      ),
  ];
}

/// The printout as an A4 PDF. Pages are drawn by the app's own painters,
/// off screen, at 300 dpi; [onProgress] is told each finished page.
Future<Uint8List> buildPaperPdf(List<PaperSet> sets, ui.FlutterView view,
    {void Function(int done, int total)? onProgress}) async {
  final pages = paperPrintout(sets);
  final doc = pw.Document();
  for (int i = 0; i < pages.length; i++) {
    final png = await renderPage(pages[i], view);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
    ));
    onProgress?.call(i + 1, pages.length);
  }
  return doc.save();
}

/// Draws [page] (laid out at [paperPageSize]) off screen to a PNG.
Future<Uint8List> renderPage(Widget page, ui.FlutterView view) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(paperPageSize),
      physicalConstraints: BoxConstraints.tight(paperPageSize),
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: paperPageSize),
      child: Directionality(textDirection: TextDirection.ltr, child: page),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner
    ..buildScope(root)
    ..finalizeTree();
  pipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: _pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
