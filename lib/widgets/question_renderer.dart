import 'dart:math';

import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../painters/figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';

/// QuestionRenderer — renders the puzzle area for all 10 question types.
/// All shapes use FigurePainter (same vocabulary as the generator).
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

  Widget _fig(Map<String, dynamic> data, {double size = 64}) {
    if (data['type'] == 'mirror_text') {
      return CustomPaint(
        size: Size(size, size),
        painter: MirrorTextPainter(data),
      );
    }
    if (data['type'] == 'symbol_grid') {
      final symbols = (data['symbols'] as List).cast<String>();
      return SizedBox(
        width: size,
        height: size,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(size * 0.06),
          children: symbols
              .take(4)
              .map(
                (s) => Center(
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    return FigureWidget(data: data, size: size);
  }

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

  // ── Helper: Horizontal scrollable container with right-side cue ─────────────
  Widget _buildHorizontalScrollableContainer(
      {required Widget child, Key? scrollKey}) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: SingleChildScrollView(
            key: scrollKey,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: child,
          ),
        ),
        // Right-side gradient fade + arrow cue
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFF8FAFC).withValues(alpha: 0),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                    const Color(0xFFF8FAFC),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _blue.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'scroll',
                        style: TextStyle(
                          fontSize: 9,
                          color: _blue.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(AppLocale.s('instr_series')),
        const SizedBox(height: 14),
        _buildHorizontalScrollableContainer(
          scrollKey: PageStorageKey<String>('series-${puzzle.hashCode}'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              for (int i = 0; i < seq.length; i++) ...[
                _fig(seq[i], size: 64),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _subtle,
                      size: 20,
                    ),
                  ),
                ),
              ],
              _qBox(size: 64),
              const SizedBox(width: 4),
            ],
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
        _buildHorizontalScrollableContainer(
          scrollKey: PageStorageKey<String>('analogy-${puzzle.hashCode}'),
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
            painter: _GeoPiecePainter(piece),
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
  Widget _punchHole() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _label(AppLocale.s('find_unfolded')),
      const SizedBox(height: 14),
      CustomPaint(size: const Size(120, 120), painter: PunchPainter(puzzle)),
    ],
  );

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
    final cx = (l + r) / 2;
    final cy = (t + b) / 2;
    final rad = (r - l) / 2;

    Path path;
    switch (shape) {
      case 0:
        path = _squarePiece(l, t, r, b, cx, cy, cut, piece);
        break;
      case 1:
        path = _triPiece(l, t, r, b, cx, cy, cut, piece);
        break;
      default:
        path = _circlePiece(cx, cy, rad, cut, piece);
        break;
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  static Path _squarePiece(
    double l,
    double t,
    double r,
    double b,
    double cx,
    double cy,
    int cut,
    int piece,
  ) {
    switch (cut) {
      case 0:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(cx, t)
                ..lineTo(cx, b)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(cx, t)
                ..lineTo(r, t)
                ..lineTo(r, b)
                ..lineTo(cx, b)
                ..close());
      case 1:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(r, cy)
                ..lineTo(l, cy)
                ..close())
            : (Path()
                ..moveTo(l, cy)
                ..lineTo(r, cy)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 2:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(r, b)
                ..close())
            : (Path()
                ..moveTo(l, t)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 3:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(r, t)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 4:
        {
          final sx = l + (r - l) * 0.6;
          final sy = t + (b - t) * 0.4;
          return piece == 0
              ? (Path()
                  ..moveTo(l, t)
                  ..lineTo(sx, t)
                  ..lineTo(sx, sy)
                  ..lineTo(r, sy)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(sx, t)
                  ..lineTo(r, t)
                  ..lineTo(r, sy)
                  ..lineTo(sx, sy)
                  ..close());
        }
      case 5:
        {
          final sx = l + (r - l) * 0.6;
          final sy = t + (b - t) * 0.6;
          return piece == 0
              ? (Path()
                  ..moveTo(l, t)
                  ..lineTo(r, t)
                  ..lineTo(r, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(sx, sy)
                  ..lineTo(r, sy)
                  ..lineTo(r, b)
                  ..lineTo(sx, b)
                  ..close());
        }
      case 6:
        {
          final sx = l + (r - l) * 0.4;
          final sy = t + (b - t) * 0.6;
          return piece == 0
              ? (Path()
                  ..moveTo(l, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, t)
                  ..lineTo(r, t)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(l, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, b)
                  ..lineTo(l, b)
                  ..close());
        }
      default:
        {
          final sx = l + (r - l) * 0.4;
          final sy = t + (b - t) * 0.4;
          return piece == 0
              ? (Path()
                  ..moveTo(l, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, t)
                  ..lineTo(r, t)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(l, t)
                  ..lineTo(sx, t)
                  ..lineTo(sx, sy)
                  ..lineTo(l, sy)
                  ..close());
        }
    }
  }

  static Path _triPiece(
    double l,
    double t,
    double r,
    double b,
    double cx,
    double cy,
    int cut,
    int piece,
  ) {
    final ax = cx;
    final ay = t;
    final blx = l;
    final bly = b;
    final brx = r;
    final bry = b;
    switch (cut) {
      case 0:
        {
          final my = t + (b - t) * 0.5;
          final mll = l + (my - t) / (b - t) * (cx - l);
          final mlr = cx + (my - t) / (b - t) * (r - cx);
          return piece == 0
              ? (Path()
                  ..moveTo(ax, ay)
                  ..lineTo(mlr, my)
                  ..lineTo(mll, my)
                  ..close())
              : (Path()
                  ..moveTo(mll, my)
                  ..lineTo(mlr, my)
                  ..lineTo(brx, bry)
                  ..lineTo(blx, bly)
                  ..close());
        }
      case 1:
        return piece == 0
            ? (Path()
                ..moveTo(ax, ay)
                ..lineTo(cx, b)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(ax, ay)
                ..lineTo(r, b)
                ..lineTo(cx, b)
                ..close());
      case 2:
        {
          final mx = (ax + brx) / 2;
          final my = (ay + bry) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(blx, bly)
                  ..lineTo(ax, ay)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(blx, bly)
                  ..lineTo(mx, my)
                  ..lineTo(brx, bry)
                  ..close());
        }
      default:
        {
          final mx = (ax + blx) / 2;
          final my = (ay + bly) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(brx, bry)
                  ..lineTo(ax, ay)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(brx, bry)
                  ..lineTo(mx, my)
                  ..lineTo(blx, bly)
                  ..close());
        }
    }
  }

  static Path _circlePiece(double cx, double cy, double r, int cut, int piece) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final p = Path();
    switch (cut) {
      case 0:
        p.moveTo(cx, cy - r);
        p.arcTo(rect, -pi / 2, piece == 0 ? -pi : pi, false);
        p.close();
        return p;
      case 1:
        p.moveTo(cx - r, cy);
        p.arcTo(rect, pi, piece == 0 ? -pi : pi, false);
        p.close();
        return p;
      case 2:
        p.moveTo(cx, cy);
        if (piece == 0) {
          p.arcTo(rect, 0, 3 * pi / 2, false);
        } else {
          p.arcTo(rect, -pi / 2, pi / 2, false);
        }
        p.close();
        return p;
      default:
        p.moveTo(cx, cy);
        if (piece == 0) {
          p.arcTo(rect, pi / 2, 3 * pi / 2, false);
        } else {
          p.arcTo(rect, 0, pi / 2, false);
        }
        p.close();
        return p;
    }
  }

  @override
  bool shouldRepaint(covariant _GeoPiecePainter old) => old.data != data;
}
