import 'dart:io' show ZLibCodec;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
// ignore: implementation_imports
import 'package:pdf/src/pdf/format/num.dart' show PdfNum;
import 'package:pdf/widgets.dart' as pw;

import '../engine/test_paper.dart';
import 'paper_pages.dart';

/// Print resolution: 300 dpi keeps thin lines and small dots sharp.
const _pixelRatio = 300 / 72;

/// Every page of the printout, in order: four sides per student, then the
/// teacher's answer key.
List<Widget> paperPrintout(List<PaperSet> sets) {
  final keyPages = (sets.length / AnswerKeyPage.setsPerPage).ceil();
  final studentPages = sidesPerSet * sets.length;
  final total = studentPages + keyPages;
  return [
    for (final s in sets) ...setPages(s, total, sidesPerSet * (s.number - 1) + 1),
    for (int k = 0; k < keyPages; k++)
      AnswerKeyPage(
        sets: sets.sublist(k * AnswerKeyPage.setsPerPage, ((k + 1) * AnswerKeyPage.setsPerPage).clamp(0, sets.length)),
        pageNumber: studentPages + k + 1,
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
    final image = await _grayPage(doc.document, await renderPage(pages[i], view));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(pw.ImageProxy(image), fit: pw.BoxFit.fill),
    ));
    onProgress?.call(i + 1, pages.length);
  }
  return doc.save();
}

/// A rendered page as a grayscale PDF image, compressed now. The paper is
/// black on white, so grey loses nothing; compressing page by page keeps
/// memory flat (raw pages would stay in memory, ~10 MB each, until the PDF
/// is saved). This was ~6x faster than handing the pdf package a PNG, which
/// it decodes and re-encodes in Dart. The package has no public way to add
/// pre-compressed data, so a 1x1 image is made and its size, colour space,
/// filter and data replaced.
Future<PdfImage> _grayPage(PdfDocument doc, ui.Image page) async {
  final w = page.width, h = page.height;
  final rgba = (await page.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  page.dispose();
  final gray = Uint8List(w * h);
  for (int i = 0, j = 0; i < gray.length; i++, j += 4) {
    gray[i] = (rgba[j] * 77 + rgba[j + 1] * 150 + rgba[j + 2] * 29) >> 8;
  }
  final data = ZLibCodec(level: 6).encode(gray);
  final image = PdfImage(doc, image: Uint8List(3), width: 1, height: 1, alpha: false);
  image.params['/Width'] = PdfNum(w);
  image.params['/Height'] = PdfNum(h);
  image.params['/ColorSpace'] = const PdfName('/DeviceGray');
  image.params['/Filter'] = const PdfName('/FlateDecode'); // written as is
  image.buf.setBytes(0, data.take(3)); // over the 1x1 image's 3 bytes
  image.buf.putBytes(data.sublist(3));
  return image;
}

/// Draws [page] (laid out at [paperPageSize]) off screen at print size.
Future<ui.Image> renderPage(Widget page, ui.FlutterView view) async {
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
  return boundary.toImage(pixelRatio: _pixelRatio);
}

/// [renderPage] as PNG bytes, for previews and tests.
Future<Uint8List> renderPagePng(Widget page, ui.FlutterView view) async {
  final image = await renderPage(page, view);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
