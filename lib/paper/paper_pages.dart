import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../engine/reasoning_question.dart';
import '../engine/test_paper.dart';
import '../painters/geo_piece_path.dart';
import '../painters/line_figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';

// A printed paper laid out like the JNVST Mental Ability Test: each part
// opens with its directions, then its questions, one full-width row each:
// problem figures, a divider, and answer figures (A)-(D) with the letter
// below. A side of A4 holds 10 questions, so one student's paper is two
// sheets printed on both sides; a part that runs onto the next side repeats
// its directions there. Sizes are in points (1/72 in).

const paperPageSize = Size(595, 842); // A4
const _margin = 24.0, _headerH = 54.0, _compactHeaderH = 22.0, _footerH = 12.0, _dirH = 24.0;
const _ink = Color(0xFF111111);
const _labelH = 9.0;

/// Questions on one side of A4.
const questionsPerSide = 10;

/// Sides per student: 40 questions, 10 a side.
const sidesPerSet = 4;

/// A 3x3 grid gets a taller row than the other questions, so its cells
/// stay readable.
double _rowWeight(ReasoningQuestion q) =>
    q.puzzle['type'] == 'matrix' && (q.puzzle['cells'] as List?)?.length == 9 ? 1.5 : 1;

/// The pages of one student's set: questions 1-10, 11-20, 21-30, 31-40.
List<Widget> setPages(PaperSet set, int totalPages, int firstPage) => [
      for (int side = 0; side < sidesPerSet; side++)
        PaperPage(set: set, side: side, pageNumber: firstPage + side, totalPages: totalPages),
    ];

class PaperPage extends StatelessWidget {
  final PaperSet set;
  final int side, pageNumber, totalPages;
  const PaperPage({super.key, required this.set, required this.side, required this.pageNumber, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    // This side's questions, numbered 1-40 across the set, with their part.
    final all = [
      for (final part in set.parts)
        for (final q in part.questions) (part, q),
    ];
    final first = side * questionsPerSide;
    final mine = all.sublist(first, first + questionsPerSide);
    final width = paperPageSize.width - 2 * _margin;
    final headerH = side == 0 ? _headerH : _compactHeaderH;
    final partsHere = {for (final (part, _) in mine) part}.length;
    final rowsH = paperPageSize.height - 2 * _margin - headerH - _footerH - partsHere * _dirH;
    final unit = rowsH / mine.fold<double>(0, (s, e) => s + _rowWeight(e.$2));

    final bands = <Widget>[];
    PaperPart? current;
    for (int i = 0; i < mine.length; i++) {
      final (part, q) = mine[i];
      if (!identical(part, current)) {
        current = part;
        final a = set.parts.indexOf(part) * 4 + 1;
        bands.add(SizedBox(
          height: _dirH,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              AppLocale.s('paper_dir_${part.id}').replaceAll('{a}', '$a').replaceAll('{b}', '${a + 3}'),
              maxLines: 2,
              style: const TextStyle(fontSize: 7.2, height: 1.25, color: _ink),
            ),
          ),
        ));
      }
      bands.add(PaperQuestion(number: first + i + 1, q: q, width: width, height: unit * _rowWeight(q)));
    }
    return _Sheet(
      setNumber: set.number,
      pageNumber: pageNumber,
      totalPages: totalPages,
      header: side == 0 ? _Header.full : _Header.compact,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bands),
    );
  }
}

enum _Header { full, compact, key }

/// White A4 page with the paper's header and footer. The full header (name,
/// roll number, date, instruction) is on a student's first side; later
/// sides carry only the title and set number.
class _Sheet extends StatelessWidget {
  final int? setNumber;
  final int pageNumber, totalPages;
  final _Header header;
  final Widget child;
  const _Sheet({this.setNumber, required this.pageNumber, required this.totalPages, required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    String blank(String k, int w) => '${AppLocale.s(k)}: ${'_' * w}';
    final full = header == _Header.full;
    return Container(
      width: paperPageSize.width,
      height: paperPageSize.height,
      color: Colors.white,
      padding: const EdgeInsets.all(_margin),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _ink, fontSize: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: full ? _headerH : _compactHeaderH,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(header == _Header.key ? AppLocale.s('paper_key') : AppLocale.s('paper_title'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (setNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: _ink, width: 1)),
                    child: Text(AppLocale.s('paper_set').replaceAll('{n}', '$setNumber'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ]),
              if (full) ...[
                const SizedBox(height: 8),
                Text('${blank('paper_name', 34)}   ${blank('paper_roll', 12)}   ${blank('paper_date', 12)}'),
                const SizedBox(height: 4),
                Text(AppLocale.s('paper_circle'), style: const TextStyle(fontSize: 7.5, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
          Expanded(child: child),
          SizedBox(
            height: _footerH,
            child: Text(AppLocale.s('paper_page').replaceAll('{p}', '$pageNumber').replaceAll('{n}', '$totalPages'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 7)),
          ),
        ]),
      ),
    );
  }
}

/// A geometry piece as plain line art: the app fills pieces a light grey.
class _PlainGeoPainter extends CustomPainter {
  final Map<String, dynamic> data;
  const _PlainGeoPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width * 0.1;
    final path = GeoPiecePath.of((data['shape'] as num?)?.toInt() ?? 0, (data['cut'] as num?)?.toInt() ?? 0,
        (data['piece'] as num?)?.toInt() ?? 1, Rect.fromLTRB(m, m, size.width - m, size.height - m));
    canvas.drawPath(
        path,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.width * 0.03).clamp(0.8, 2.0)
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_PlainGeoPainter old) => old.data != data;
}

/// Figure data marked for print: painters that fill a shape or the punched
/// sheet with a light tint draw it white instead.
Map<String, dynamic> _print(Map data) => {...Map<String, dynamic>.from(data), 'print': true};

/// Any figure as print line art: geometry pieces unfilled, tints white.
Widget _figure(Map data, double box) {
  final d = _print(data);
  return d['type'] == 'geo_piece'
      ? CustomPaint(size: Size.square(box), painter: _PlainGeoPainter(d))
      : OptionRenderer(data: d, size: box);
}

/// A problem-figure slot: [w] is its width in box widths.
typedef _Slot = ({double w, Widget Function(double box) build});

class PaperQuestion extends StatelessWidget {
  final int number;
  final ReasoningQuestion q;
  final double width, height;
  const PaperQuestion({super.key, required this.number, required this.q, required this.width, required this.height});

  static const _numW = 18.0, _divW = 12.0, _space = 4.0;

  static Widget _framed(double box, Widget child) => Container(
        width: box,
        height: box,
        color: Colors.white,
        foregroundDecoration: BoxDecoration(border: Border.all(color: _ink, width: 0.6)),
        child: child,
      );

  static _Slot _fig(Map data) => (w: 1, build: (b) => _framed(b, _figure(data, b)));
  static _Slot _paint(CustomPainter p, {double w = 1}) =>
      (w: w, build: (b) => _framed(b, CustomPaint(size: Size.square(b), painter: p)));
  static Widget _askMark(double b) => Center(child: Text('?', style: TextStyle(fontSize: b * 0.45, fontWeight: FontWeight.bold)));
  static final _Slot _ask = (w: 1, build: (b) => _framed(b, _askMark(b)));
  static _Slot _sep(String s) =>
      (w: 0.35, build: (b) => SizedBox(width: b * 0.35, child: Center(child: Text(s, style: TextStyle(fontSize: b * 0.3, fontWeight: FontWeight.bold)))));
  static final _Slot _mirror = (w: 0.3, build: (b) => SizedBox(width: b * 0.3, height: b, child: Center(child: Container(width: 1.4, color: _ink))));

  /// An [n] x [n] grid of thin-ruled cells, the missing one a '?'.
  static _Slot _grid(int n, List cells, int missing, Widget Function(Map cell, double size) draw) => (
        w: 1,
        build: (b) {
          final c = b / n;
          Widget? cell(int i) {
            if (i == missing) return _askMark(c);
            final m = cells[i];
            if (m is! Map || m['empty'] == true) return null;
            return Center(child: draw(m, c * 0.82));
          }

          return Container(
            width: b,
            height: b,
            foregroundDecoration: BoxDecoration(border: Border.all(color: _ink, width: 0.9)),
            child: Column(children: [
              for (int r = 0; r < n; r++)
                Row(children: [
                  for (int col = 0; col < n; col++)
                    Container(
                      width: c,
                      height: c,
                      decoration: BoxDecoration(border: Border.all(color: _ink, width: 0.4)),
                      child: cell(r * n + col),
                    ),
                ]),
            ]),
          );
        },
      );

  List<_Slot> _problem() {
    final p = q.puzzle;
    switch (p['type']) {
      case 'odd_man':
        return [];
      case 'figure_match':
        return [
          p['subtype'] == 'letter'
              ? _fig({'type': 'mirror_text', 'content': p['content'], 'is_clock': false, 'mirror_h': false, 'mirror_v': false})
              : _fig(p['target'] as Map),
        ];
      case 'series':
        return [for (final s in p['sequence'] as List) _fig(s as Map), _ask];
      case 'analogy':
        return [_fig(p['A'] as Map), _sep(':'), _fig(p['B'] as Map), _sep('::'), _fig(p['C'] as Map), _sep(':'), _ask];
      case 'geo_completion':
        return [_fig(p['piece'] as Map)];
      case 'mirror_shape':
        return [_fig(p['target'] as Map), _mirror];
      case 'mirror_text':
        return [
          _paint(MirrorTextPainter({...p, 'mirror_h': false, 'mirror_v': false, 'type': 'mirror_text'})),
          _mirror,
        ];
      case 'punch_hole':
        final folds = p['folds'] as List?;
        if (folds == null) return [_paint(PunchPainter(_print(p)))];
        return [for (int step = 0; step <= folds.length; step++) _paint(PunchPainter({..._print(p), 'step': step}))];
      case 'embedded':
        return [_fig(p['target'] as Map)];
      case 'space_vis':
        // Pieces at the options' scale (see QuestionRenderer._spaceVis).
        final pieces = p['pieces'] as List;
        final scale = ((pieces.first as Map)['w'] as int) / ((p['figure_extent'] as int?) ?? 8);
        return [
          for (final piece in pieces)
            (w: scale, build: (b) => SizedBox.square(dimension: b * scale,
                child: CustomPaint(painter: LineFigurePainter(_print(piece as Map))))),
        ];
      case 'quad_pattern':
        return [
          _grid(2, p['tiles'] as List, p['missing'] as int? ?? 3,
              (t, s) => CustomPaint(size: Size.square(s), painter: LineFigurePainter(_print(t)))),
        ];
      case 'matrix':
        final cells = p['cells'] as List;
        if (cells.length == 9) return [_grid(3, cells, p['missing'] as int? ?? 8, _figure)];
        return [_whole(1)];
      default:
        return [_whole(1)];
    }
  }

  // The app's own drawing of the whole puzzle, shrunk into [w] box widths:
  // only for a puzzle type with no print drawing above.
  _Slot _whole(double w) => (
        w: w,
        build: (b) => SizedBox(width: b * w, height: b,
            child: FittedBox(child: QuestionRenderer(puzzle: q.puzzle, showInstruction: false))),
      );

  @override
  Widget build(BuildContext context) {
    final problem = _problem();
    final units = problem.fold<double>(0, (s, x) => s + x.w) + 4;
    final spaces = (problem.length + 4) * _space + (problem.isEmpty ? 0 : _divW);
    // Most rows are height-limited; a wide one (series, analogy) may be
    // width-limited.
    final box = ((width - _numW - spaces) / units).clamp(0.0, height - _labelH - 8);
    Widget answer(int i) => Padding(
          padding: const EdgeInsets.only(left: _space),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _framed(box, _figure(q.options[i], box)),
            SizedBox(height: _labelH, child: Text('(${'ABCD'[i]})', style: const TextStyle(fontSize: 7))),
          ]),
        );
    return SizedBox(
      width: width,
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: _numW, child: Text('$number.', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
        for (final s in problem)
          Padding(padding: const EdgeInsets.only(left: _space, bottom: _labelH), child: s.build(box)),
        if (problem.isNotEmpty)
          Container(width: _divW, height: height - 10, alignment: Alignment.center,
              child: Container(width: 0.6, color: const Color(0xFF888888))),
        for (int i = 0; i < 4; i++) answer(i),
      ]),
    );
  }
}

/// Teacher's answer key: one row per set, the correct letter for 1-40.
class AnswerKeyPage extends StatelessWidget {
  final List<PaperSet> sets;
  final int pageNumber, totalPages;
  const AnswerKeyPage({super.key, required this.sets, required this.pageNumber, required this.totalPages});

  /// Sets that fit on one key page.
  static const setsPerPage = 48;

  @override
  Widget build(BuildContext context) {
    const setW = 34.0;
    final cellW = (paperPageSize.width - 2 * _margin - setW) / 40;
    Widget cell(String s, double w, {bool bold = false, bool shade = false}) => Container(
          width: w,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: shade ? const Color(0xFFEEEEEE) : null,
            border: Border.all(color: const Color(0xFF999999), width: 0.4),
          ),
          child: Text(s, style: TextStyle(fontSize: 6.8, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        );
    return _Sheet(
      pageNumber: pageNumber,
      totalPages: totalPages,
      header: _Header.key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          cell(AppLocale.s('paper_key_set'), setW, bold: true, shade: true),
          for (int k = 1; k <= 40; k++) cell('$k', cellW, bold: true, shade: true),
        ]),
        for (final s in sets)
          Row(children: [
            cell('${s.number}', setW, bold: true),
            for (final (k, a) in s.answerKey.indexed) cell('ABCD'[a], cellW, shade: (k ~/ 4).isOdd),
          ]),
      ]),
    );
  }
}
