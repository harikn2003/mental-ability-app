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

// A printed paper laid out like the JNVST Mental Ability Test: two columns
// a side, each part opening with its directions. A question with one
// problem figure sits on one line - problem figure, a divider, answer
// figures (A)-(D) with the letter below; one with several (series,
// analogy, folding steps) takes two lines, problem figures over the
// answers. Questions run down the left column, then the right. A side of
// A4 holds 20 questions, so one student's paper is one sheet printed on
// both sides. Sizes are in points (1/72 in).

const paperPageSize = Size(595, 842); // A4
const _margin = 24.0, _headerH = 54.0, _compactHeaderH = 22.0, _footerH = 12.0, _dirH = 26.0;
const _colGap = 14.0;
const _ink = Color(0xFF111111);
const _labelH = 9.0;

/// Questions on one side of A4.
const questionsPerSide = 20;

/// Sides per student: 40 questions, 20 a side.
const sidesPerSet = 2;

/// The pages of one student's set: questions 1-20, 21-40.
List<Widget> setPages(PaperSet set, int totalPages, int firstPage) => [
      for (int side = 0; side < sidesPerSet; side++)
        PaperPage(set: set, side: side, pageNumber: firstPage + side, totalPages: totalPages),
    ];

class PaperPage extends StatelessWidget {
  final PaperSet set;
  final int side, pageNumber, totalPages;
  const PaperPage({super.key, required this.set, required this.side, required this.pageNumber, required this.totalPages});

  static double get columnWidth => (paperPageSize.width - 2 * _margin - _colGap) / 2;

  /// This side's questions in order, each with its part and number.
  List<(PaperPart, ReasoningQuestion, int)> _questions() {
    final all = [
      for (final part in set.parts)
        for (final q in part.questions) (part, q),
    ];
    final first = side * questionsPerSide;
    return [
      for (int i = first; i < first + questionsPerSide && i < all.length; i++) (all[i].$1, all[i].$2, i + 1),
    ];
  }

  /// Flows directions and questions into two columns of [height] with
  /// figures [box] wide: the items of each column, or null if they don't fit.
  /// A part's directions never end a column without its first question.
  static List<List<Object>>? flow(List<(PaperPart, ReasoningQuestion, int)> qs, double box, double height) {
    final cols = <List<Object>>[[]];
    var used = 0.0;
    PaperPart? current;
    for (final (part, q, n) in qs) {
      final dir = !identical(part, current);
      current = part;
      final h = PaperQuestion.heightFor(q, box, columnWidth);
      final need = h + (dir ? _dirH : 0);
      if (used + need > height) {
        if (cols.length == 2) return null;
        cols.add([]);
        used = 0;
      }
      // A column carrying on a part opens with its directions again only
      // on a new side; within a side the part's directions are just above.
      if (dir) cols.last.add(part);
      cols.last.add((q, n, h));
      used += need;
    }
    return cols;
  }

  double get _height => paperPageSize.height - 2 * _margin - (side == 0 ? _headerH : _compactHeaderH) - _footerH;

  /// Answer figure size on this side: the biggest that fits, at most 40 pt
  /// (14 mm); null if the questions don't fit even at 14 pt.
  double? get figureSize {
    final qs = _questions();
    for (var box = 40.0; box >= 14; box -= 0.5) {
      if (flow(qs, box, _height) != null) return box;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final qs = _questions();
    final height = _height;
    final box = figureSize ?? 14.0;
    final cols = flow(qs, box, height) ?? flow(qs, box, double.infinity)!;

    Widget column(List<Object> items) {
      final used = items.fold<double>(0, (s, e) => s + (e is PaperPart ? _dirH : (e as (ReasoningQuestion, int, double)).$3));
      final count = items.whereType<(ReasoningQuestion, int, double)>().length;
      // Spread spare height between the questions, a little at most.
      final gap = count == 0 ? 0.0 : ((height - used) / count).clamp(0.0, 10.0);
      return SizedBox(
        width: columnWidth,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in items)
            if (e is PaperPart)
              _directions(e)
            else
              () {
                final (q, n, h) = e as (ReasoningQuestion, int, double);
                return Padding(
                  padding: EdgeInsets.only(bottom: gap),
                  child: PaperQuestion(number: n, q: q, width: columnWidth, box: box),
                );
              }(),
        ]),
      );
    }

    return _Sheet(
      setNumber: set.number,
      pageNumber: pageNumber,
      totalPages: totalPages,
      header: side == 0 ? _Header.full : _Header.compact,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        column(cols[0]),
        Container(width: _colGap, alignment: Alignment.center, child: Container(width: 0.5, color: const Color(0xFF888888))),
        if (cols.length > 1) column(cols[1]),
      ]),
    );
  }

  Widget _directions(PaperPart part) {
    final a = set.parts.indexOf(part) * 4 + 1;
    return SizedBox(
      height: _dirH,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            AppLocale.s('paper_dir_${part.id}').replaceAll('{a}', '$a').replaceAll('{b}', '${a + 3}'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 6.6, height: 1.2, color: _ink),
          ),
        ),
      ),
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
                Text('${blank('paper_name', 48)}   ${blank('paper_date', 14)}'),
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

/// A problem-figure slot: [w] and [h] are its width and height in box widths.
typedef _Slot = ({double w, double h, Widget Function(double box) build});

class PaperQuestion extends StatelessWidget {
  final int number;
  final ReasoningQuestion q;
  final double width, box;
  const PaperQuestion({super.key, required this.number, required this.q, required this.width, required this.box});

  static const _numW = 16.0, _divW = 9.0, _space = 3.0, _lineGap = 3.0, _rowPad = 4.0;

  /// A 3x3 grid is drawn this much bigger than an answer figure, so its
  /// cells stay readable.
  static const gridScale = 1.4;

  static Widget _framed(double box, Widget child) => Container(
        width: box,
        height: box,
        color: Colors.white,
        foregroundDecoration: BoxDecoration(border: Border.all(color: _ink, width: 0.6)),
        child: child,
      );

  static _Slot _fig(Map data, {double w = 1}) => (w: w, h: w, build: (b) => _framed(b * w, _figure(data, b * w)));
  static _Slot _paint(CustomPainter p) => (w: 1, h: 1, build: (b) => _framed(b, CustomPaint(size: Size.square(b), painter: p)));
  static Widget _askMark(double b) => Center(child: Text('?', style: TextStyle(fontSize: b * 0.45, fontWeight: FontWeight.bold)));
  static final _Slot _ask = (w: 1, h: 1, build: (b) => _framed(b, _askMark(b)));
  static _Slot _sep(String s) => (
        w: 0.35,
        h: 1,
        build: (b) => SizedBox(width: b * 0.35, child: Center(child: Text(s, style: TextStyle(fontSize: b * 0.3, fontWeight: FontWeight.bold)))),
      );
  static final _Slot _mirror = (w: 0.3, h: 1, build: (b) => SizedBox(width: b * 0.3, height: b, child: Center(child: Container(width: 1.4, color: _ink))));
  static _Slot _caption(String s, double w) => (
        w: w,
        h: 1,
        build: (b) => SizedBox(
              width: b * w,
              height: b,
              child: Align(alignment: Alignment.centerLeft, child: Text(s, style: const TextStyle(fontSize: 6.6, height: 1.2))),
            ),
      );

  /// An [n] x [n] grid of thin-ruled cells, the missing one a '?', [scale]
  /// box widths across.
  static _Slot _grid(int n, List cells, int missing, Widget Function(Map cell, double size) draw, {double scale = 1}) => (
        w: scale,
        h: scale,
        build: (box) {
          final b = box * scale, c = b / n;
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

  static List<_Slot> _problem(ReasoningQuestion q) {
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
      case 'paper_fold':
        // The part's directions are about punching, so the sheet says what
        // to do itself.
        return [_fig(p['sheet'] as Map, w: 1.2), _caption(AppLocale.s('instr_paper_fold'), 3.2)];
      case 'embedded':
        return [_fig(p['target'] as Map)];
      case 'space_vis':
        // Pieces at the options' scale (see QuestionRenderer._spaceVis).
        final pieces = p['pieces'] as List;
        final scale = ((pieces.first as Map)['w'] as int) / ((p['figure_extent'] as int?) ?? 8);
        return [
          for (final piece in pieces)
            (w: scale, h: scale, build: (b) => SizedBox.square(dimension: b * scale,
                child: CustomPaint(painter: LineFigurePainter(_print(piece as Map))))),
        ];
      case 'quad_pattern':
        return [
          _grid(2, p['tiles'] as List, p['missing'] as int? ?? 3,
              (t, s) => CustomPaint(size: Size.square(s), painter: LineFigurePainter(_print(t)))),
        ];
      case 'matrix':
        final cells = p['cells'] as List;
        if (cells.length == 9) return [_grid(3, cells, p['missing'] as int? ?? 8, _figure, scale: gridScale)];
        return [_whole(q, 1)];
      default:
        return [_whole(q, 1)];
    }
  }

  // The app's own drawing of the whole puzzle, shrunk into [w] box widths:
  // only for a puzzle type with no print drawing above.
  static _Slot _whole(ReasoningQuestion q, double w) => (
        w: w,
        h: 1,
        build: (b) => SizedBox(width: b * w, height: b,
            child: FittedBox(child: QuestionRenderer(puzzle: q.puzzle, showInstruction: false))),
      );

  /// Several problem figures (a series, an analogy, folding steps) go on a
  /// line of their own above the answers.
  static bool _twoLines(List<_Slot> problem) => problem.fold<double>(0, (s, x) => s + x.w) > 1.5;

  /// Whether [q] takes two lines.
  static bool twoLines(ReasoningQuestion q) => _twoLines(_problem(q));

  /// Figure size on the problem line: [box], or smaller if the line is too
  /// long for [width].
  static double _problemBox(List<_Slot> problem, double box, double width) {
    final units = problem.fold<double>(0, (s, x) => s + x.w);
    if (units == 0) return box;
    final room = width - _numW - problem.length * _space - (_twoLines(problem) ? 0 : _divW + 4 * (box + _space));
    return (room / units).clamp(0.0, box);
  }

  static double _problemH(List<_Slot> problem, double b) => problem.fold<double>(0, (s, x) => s > x.h * b ? s : x.h * b);

  /// The question's height with answer figures [box] wide in a column [width] wide.
  static double heightFor(ReasoningQuestion q, double box, double width) {
    final problem = _problem(q);
    final ph = _problemH(problem, _problemBox(problem, box, width));
    final answers = box + _labelH;
    return (_twoLines(problem) ? ph + _lineGap + answers : (ph > answers ? ph : answers)) + _rowPad;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem(q);
    final pb = _problemBox(problem, box, width);
    final two = _twoLines(problem);
    Widget answer(int i) => Padding(
          padding: const EdgeInsets.only(left: _space),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _framed(box, _figure(q.options[i], box)),
            SizedBox(height: _labelH, child: Text('(${'ABCD'[i]})', style: const TextStyle(fontSize: 6.5))),
          ]),
        );
    final answers = [for (int i = 0; i < 4; i++) answer(i)];
    final figures = [for (final s in problem) Padding(padding: const EdgeInsets.only(left: _space), child: s.build(pb))];
    final num = SizedBox(width: _numW, child: Text('$number.', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)));
    return SizedBox(
      width: width,
      height: heightFor(q, box, width),
      child: two
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [num, ...figures]),
              const SizedBox(height: _lineGap),
              Row(children: [const SizedBox(width: _numW), ...answers]),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              num,
              ...figures,
              if (problem.isNotEmpty)
                Container(width: _divW, height: box, alignment: Alignment.center,
                    child: Container(width: 0.6, color: const Color(0xFF888888))),
              ...answers,
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
