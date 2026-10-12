import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../engine/reasoning_question.dart';
import '../engine/test_paper.dart';
import '../painters/line_figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';

// A printed paper laid out like the JNVST Mental Ability Test: each part
// opens with its directions, then its questions, one row each: problem
// figures, a divider, and answer figures (A)-(D) with the letter below.
// Two questions sit side by side, so a side of A4 holds five parts (20
// questions) and one sheet the whole paper. Sizes are in points (1/72 in).

const paperPageSize = Size(595, 842); // A4
const _margin = 24.0, _headerH = 54.0, _footerH = 12.0, _dirH = 24.0, _rowH = 60.0, _gap = 12.0;
const _ink = Color(0xFF111111);
const _labelH = 9.0;

/// The pages of one student's set: questions 1-20, then 21-40.
List<Widget> setPages(PaperSet set, int totalPages, int firstPage) => [
      for (int side = 0; side < 2; side++)
        PaperPage(set: set, parts: set.parts.sublist(side * 5, side * 5 + 5), firstNumber: side * 20 + 1,
            pageNumber: firstPage + side, totalPages: totalPages),
    ];

class PaperPage extends StatelessWidget {
  final PaperSet set;
  final List<PaperPart> parts;
  final int firstNumber, pageNumber, totalPages;
  const PaperPage({super.key, required this.set, required this.parts, required this.firstNumber,
      required this.pageNumber, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    final colW = (paperPageSize.width - 2 * _margin - _gap) / 2;
    var n = firstNumber;
    final bands = <Widget>[];
    for (final part in parts) {
      final first = n;
      final qs = [for (final q in part.questions) (n++, q)];
      bands.add(SizedBox(
        height: _dirH,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            AppLocale.s('paper_dir_${part.id}').replaceAll('{a}', '$first').replaceAll('{b}', '${first + 3}'),
            maxLines: 2,
            style: const TextStyle(fontSize: 7.2, height: 1.25, color: _ink),
          ),
        ),
      ));
      for (int row = 0; row < 2; row++) {
        bands.add(Row(children: [
          PaperQuestion(number: qs[2 * row].$1, q: qs[2 * row].$2, width: colW),
          const SizedBox(width: _gap),
          PaperQuestion(number: qs[2 * row + 1].$1, q: qs[2 * row + 1].$2, width: colW),
        ]));
      }
    }
    return _Sheet(
      setNumber: set.number,
      pageNumber: pageNumber,
      totalPages: totalPages,
      student: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bands),
    );
  }
}

/// White A4 page with the paper's header and footer.
class _Sheet extends StatelessWidget {
  final int? setNumber;
  final int pageNumber, totalPages;
  final bool student;
  final Widget child;
  const _Sheet({this.setNumber, required this.pageNumber, required this.totalPages, required this.student, required this.child});

  @override
  Widget build(BuildContext context) {
    String blank(String k, int w) => '${AppLocale.s(k)}: ${'_' * w}';
    return Container(
      width: paperPageSize.width,
      height: paperPageSize.height,
      color: Colors.white,
      padding: const EdgeInsets.all(_margin),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _ink, fontSize: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: student ? _headerH : 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(student ? AppLocale.s('paper_title') : AppLocale.s('paper_key'),
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
              if (student) ...[
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

/// A problem-figure slot: [w] is its width in box widths.
typedef _Slot = ({double w, Widget Function(double box) build});

class PaperQuestion extends StatelessWidget {
  final int number;
  final ReasoningQuestion q;
  final double width;
  const PaperQuestion({super.key, required this.number, required this.q, required this.width});

  static const _numW = 15.0, _divW = 9.0, _space = 2.0, _maxBox = _rowH - _labelH - 6;

  static Widget _framed(double box, Widget child) => Container(
        width: box,
        height: box,
        color: Colors.white,
        foregroundDecoration: BoxDecoration(border: Border.all(color: _ink, width: 0.6)),
        child: child,
      );

  static _Slot _fig(Map data) =>
      (w: 1, build: (b) => _framed(b, OptionRenderer(data: Map<String, dynamic>.from(data), size: b)));
  static _Slot _paint(CustomPainter p, {double w = 1}) =>
      (w: w, build: (b) => _framed(b, CustomPaint(size: Size.square(b), painter: p)));
  static final _Slot _ask = (
    w: 1,
    build: (b) => _framed(b, Center(child: Text('?', style: TextStyle(fontSize: b * 0.45, fontWeight: FontWeight.bold)))),
  );
  static _Slot _sep(String s) =>
      (w: 0.35, build: (b) => SizedBox(width: b * 0.35, child: Center(child: Text(s, style: TextStyle(fontSize: b * 0.3, fontWeight: FontWeight.bold)))));
  static final _Slot _mirror = (w: 0.3, build: (b) => SizedBox(width: b * 0.3, height: b, child: Center(child: Container(width: 1.4, color: _ink))));
  // The app's own drawing of the whole puzzle, shrunk into [w] box widths.
  _Slot _whole(double w) => (
        w: w,
        build: (b) => SizedBox(width: b * w, height: b,
            child: FittedBox(child: QuestionRenderer(puzzle: q.puzzle, showInstruction: false))),
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
        final piece = p['piece'] as Map?;
        return [if (piece != null && piece['type'] == 'line_fig') _fig(piece) else _whole(1)];
      case 'mirror_shape':
        return [_fig(p['target'] as Map), _mirror];
      case 'mirror_text':
        return [
          _paint(MirrorTextPainter({...p, 'mirror_h': false, 'mirror_v': false, 'type': 'mirror_text'})),
          _mirror,
        ];
      case 'punch_hole':
        final folds = p['folds'] as List?;
        if (folds == null) return [_paint(PunchPainter(p))];
        return [for (int step = 0; step <= folds.length; step++) _paint(PunchPainter({...p, 'step': step}))];
      case 'embedded':
        return [_fig(p['target'] as Map)];
      case 'space_vis':
        // Pieces at the options' scale (see QuestionRenderer._spaceVis).
        final pieces = p['pieces'] as List;
        final scale = ((pieces.first as Map)['w'] as int) / ((p['figure_extent'] as int?) ?? 8);
        return [
          for (final piece in pieces)
            (w: scale, build: (b) => SizedBox.square(dimension: b * scale,
                child: CustomPaint(painter: LineFigurePainter(Map<String, dynamic>.from(piece as Map))))),
        ];
      default: // matrix, quad_pattern
        return [_whole(1)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem();
    final units = problem.fold<double>(0, (s, x) => s + x.w) + 4;
    final spaces = (problem.length + 4) * _space + (problem.isEmpty ? 0 : _divW);
    final box = ((width - _numW - spaces) / units).clamp(0.0, _maxBox);
    Widget answer(int i) => Padding(
          padding: const EdgeInsets.only(left: _space),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _framed(box, OptionRenderer(data: Map<String, dynamic>.from(q.options[i]), size: box)),
            SizedBox(height: _labelH, child: Text('(${'ABCD'[i]})', style: const TextStyle(fontSize: 6.8))),
          ]),
        );
    return SizedBox(
      width: width,
      height: _rowH,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: _numW, child: Text('$number.', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
        for (final s in problem)
          Padding(padding: const EdgeInsets.only(left: _space, bottom: _labelH), child: s.build(box)),
        if (problem.isNotEmpty)
          Container(width: _divW, height: _rowH - 8, alignment: Alignment.center,
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
      student: false,
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
