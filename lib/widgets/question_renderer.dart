import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../painters/geo_piece_path.dart';
import '../painters/line_figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';
import 'option_renderer.dart';

/// QuestionRenderer — renders the puzzle area for all 10 question types.
/// Figures are drawn by OptionRenderer, the same code as the answer options.
class QuestionRenderer extends StatelessWidget {
  final Map<String, dynamic> puzzle;
  const QuestionRenderer({super.key, required this.puzzle});

  static const Color _subtle = Color(0xFF64748B);
  static const Color _blue = Color(0xFF195DE6);
  static const Color _ink = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    switch (puzzle['type']) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'matrix':
        return _matrix();
      case 'quad_pattern':
        return _quadPattern();
      case 'series':
        return _series();
      case 'analogy':
        return _analogy();
      case 'geo_completion':
        return _geoJigsaw();
      case 'mirror_shape':
        return _mirrorShape();
      case 'mirror_text':
        return _mirrorTextQ();
      case 'punch_hole':
        return _punchHole();
      case 'embedded':
        return _embedded();
      default:
        return const Center(child: Text('?'));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fig(Map<String, dynamic> data, {double size = 64}) => figure(data, size: size);

  /// Draws a question figure with exactly the same code as the answer
  /// options. BUGFIX: question figures used the older FigurePainter, which
  /// draws an inner shape in dark ink even on a filled (dark) shape - so it
  /// vanished - and ignores the 'dense' corner mark. On a Hard mirror
  /// question the target lost the very details that decide the answer while
  /// the options showed them (device screenshot, 2026-09-25). Sharing the
  /// options' renderer makes that mismatch impossible.
  static Widget figure(Map<String, dynamic> data, {double size = 64}) => OptionRenderer(data: data, size: size);

  Widget _label(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 13, color: _subtle, height: 1.4),
  );

  Widget _qBox({double size = 64}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade400),
    ),
    child: const Center(
      child: Text(
        '?',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _subtle,
        ),
      ),
    ),
  );

  Widget _mirrorLine() => Container(
    width: 2.5,
    height: 90,
    decoration: BoxDecoration(
      color: _blue.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  // ── 1. Odd Man Out ─────────────────────────────────────────────────────────
  Widget _oddMan() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: _label(AppLocale.s('find_odd')),
  );

  // ── 2. Figure Match ────────────────────────────────────────────────────────
  Widget _figureMatch() {
    late Map<String, dynamic> target;
    if (puzzle['subtype'] == 'letter') {
      target = {
        'type': 'mirror_text',
        'content': puzzle['content'] as String,
        'is_clock': false,
        'mirror_h': false,
        'mirror_v': false,
      };
    } else {
      target = Map<String, dynamic>.from(puzzle['target'] as Map);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_match')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _blue, width: 2),
          ),
          child: _fig(target, size: 80),
        ),
      ],
    );
  }

  // ── 3. Pattern Completion (3×3 matrix) ────────────────────────────────────
  Widget _matrix() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(
          puzzle['category'] == 'geo_completion'
              ? AppLocale.s('instr_geo')
              : AppLocale.s('instr_pattern'),
        ),
        const SizedBox(height: 12),
        _buildMatrix(),
      ],
    );
  }

  // ── 4. Figure Series ───────────────────────────────────────────────────────
  Widget _series() {
    final seq = (puzzle['sequence'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    // Two rows instead of one sideways-scrolling row: testers found scrolling
    // back and forth to compare figures cumbersome, and the last figure was
    // hidden behind the scroll edge (tracker: "Figure match horiz scroll is
    // tough to see"). The first row ends with an arrow so the order reads on.
    final tiles = <Widget>[for (final s in seq) _fig(s, size: 64), _qBox(size: 64)];
    final firstRow = (tiles.length + 1) ~/ 2;
    Widget arrow() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, color: _subtle, size: 20),
        );
    Widget row(List<Widget> items, {required bool trailingArrow}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) arrow(),
              items[i],
            ],
            if (trailingArrow) arrow(),
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_series')),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row(tiles.sublist(0, firstRow), trailingArrow: true),
                const SizedBox(height: 12),
                row(tiles.sublist(firstRow), trailingArrow: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 5. Analogy ─────────────────────────────────────────────────────────────
  Widget _analogy() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_analogy')),
        const SizedBox(height: 14),
        // Shrink to fit rather than scroll sideways (same tester feedback as
        // the series row) - A : B :: C : ? is one short line.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 4),
              _fig(Map<String, dynamic>.from(puzzle['A'] as Map), size: 58),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              _fig(Map<String, dynamic>.from(puzzle['B'] as Map), size: 58),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '::',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                  ),
                ),
              ),
              _fig(Map<String, dynamic>.from(puzzle['C'] as Map), size: 58),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              _qBox(size: 58),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  // ── 6. Geo Completion ──────────────────────────────────────────────────────

  // Extracted matrix builder so both _matrix() and _geoCompletion() can use it
  Widget _buildMatrix() {
    final rawCells = puzzle['cells'] as List;
    // Guard: old generator sent 4-element bool lists for geo_completion.
    // If we get a non-9-element list, show a safe fallback rather than crashing.
    if (rawCells.length != 9) {
      return _label(AppLocale.s('instr_error'));
    }
    final cells = rawCells
        .map(
          (e) => (e == null || e is! Map)
              ? <String, dynamic>{'empty': true}
              : Map<String, dynamic>.from(e),
        )
        .toList();
    final missing = puzzle['missing'] as int? ?? 8;
    const cellSize = 68.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (col) {
              final idx = row * 3 + col;
              final cell = cells[idx];
              final isQ = idx == missing;
              return Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: isQ ? const Color(0xFFE2E8F0) : Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: isQ
                    ? const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _subtle,
                          ),
                        ),
                      )
                    : (cell['empty'] == true
                    ? const SizedBox()
                    : Center(child: _fig(cell, size: 46))),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── 3b. Pattern Completion, exam style: a square design of four quarters ──
  // (TL, TR, BL, BR) with one quarter missing - JNVST Part 3.
  Widget _quadPattern() {
    final tiles = puzzle['tiles'] as List;
    final missing = puzzle['missing'] as int? ?? 3;
    const tile = 64.0;
    Widget quarter(int i) => Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: i == missing ? const Color(0xFFE2E8F0) : Colors.white,
            border: Border.all(color: _ink, width: 1.2),
          ),
          child: i == missing
              ? const Center(
                  child: Text('?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _subtle)))
              : CustomPaint(
                  size: const Size(tile, tile),
                  painter: LineFigurePainter(Map<String, dynamic>.from(tiles[i] as Map)),
                ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_pattern')),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(border: Border.all(color: _ink, width: 2)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [quarter(0), quarter(1)]),
            Row(mainAxisSize: MainAxisSize.min, children: [quarter(2), quarter(3)]),
          ]),
        ),
      ],
    );
  }

  // ── 6. Geo Completion (jigsaw piece-fitting) ──────────────────────────────
  Widget _geoJigsaw() {
    final piece = Map<String, dynamic>.from(puzzle['piece'] as Map);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_geo')),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _blue.withValues(alpha: 0.3), width: 1.5),
          ),
          child: CustomPaint(
            size: const Size(100, 100),
            painter: piece['type'] == 'line_fig' ? LineFigurePainter(piece) : _GeoPiecePainter(piece),
          ),
        ),
      ],
    );
  }

  // ── 7. Mirror Shape ────────────────────────────────────────────────────────
  Widget _mirrorShape() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_mirror')),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show the shape larger so mirror difference is clearly visible
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue.withValues(alpha: 0.2)),
              ),
              child: _fig(target, size: 88),
            ),
            const SizedBox(width: 16),
            // Mirror line with arrows indicating reflection direction
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: _blue.withValues(alpha: 0.7),
                ),
                Container(
                  width: 3,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: 16,
                  color: _blue.withValues(alpha: 0.7),
                ),
              ],
            ),
            const SizedBox(width: 16),
            _qBox(size: 88),
          ],
        ),
      ],
    );
  }

  // ── 8. Mirror Text / Clock ─────────────────────────────────────────────────
  Widget _mirrorTextQ() {
    final orig = Map<String, dynamic>.from(puzzle)
      ..['mirror_h'] = false
      ..['mirror_v'] = false
      ..['type'] = 'mirror_text';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_mirror')),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(80, 80),
              painter: MirrorTextPainter(orig),
            ),
            const SizedBox(width: 20),
            _mirrorLine(),
            const SizedBox(width: 20),
            _qBox(size: 80),
          ],
        ),
      ],
    );
  }

  // ── 9. Punch Hole ──────────────────────────────────────────────────────────
  Widget _punchHole() {
    final folds = puzzle['folds'] as List?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('find_unfolded')),
        const SizedBox(height: 14),
        if (folds == null)
          CustomPaint(size: const Size(120, 120), painter: PunchPainter(puzzle))
        else
          // Exam-style fold sequence: one panel per step, arrows between.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int step = 0; step <= folds.length; step++) ...[
                if (step > 0) Icon(Icons.arrow_forward_rounded, size: 16, color: _blue.withValues(alpha: 0.7)),
                CustomPaint(
                  size: Size.square(folds.length > 1 ? 78 : 96),
                  painter: PunchPainter({...puzzle, 'step': step}),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // ── 10. Embedded Figure ────────────────────────────────────────────────────
  Widget _embedded() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_embedded')),
        const SizedBox(height: 12),
        // Show target with a highlight box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _blue, width: 2),
          ),
          child: _fig(target, size: 72),
        ),
      ],
    );
  }
}

// ── Geo piece painter (inline) ────────────────────────────────────────────────
class _GeoPiecePainter extends CustomPainter {
  final Map<String, dynamic> data;
  static const Color _ink = Color(0xFF1E293B);
  static const Color _fill = Color(0xFFE2E8F0);

  const _GeoPiecePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final int shape = (data['shape'] as num?)?.toInt() ?? 0;
    final int cut = (data['cut'] as num?)?.toInt() ?? 0;
    final int piece = (data['piece'] as num?)?.toInt() ?? 0;

    final stroke = Paint()
      ..color = _ink
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = _fill
      ..style = PaintingStyle.fill;

    final m = size.width * 0.08;
    final l = m;
    final t = m;
    final r = size.width - m;
    final b = size.height - m;

    final path = GeoPiecePath.of(shape, cut, piece, Rect.fromLTRB(l, t, r, b));
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }




  @override
  bool shouldRepaint(covariant _GeoPiecePainter old) => old.data != data;
}
