import 'dart:math';

import 'package:flutter/material.dart';

import '../painters/figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';

/// OptionRenderer — renders one answer option.
/// Dispatches to the correct painter/widget based on 'type'.
class OptionRenderer extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const OptionRenderer({super.key, required this.data, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';

    if (type == 'symbol_grid') {
      final symbols = (data['symbols'] as List).cast<String>();
      return _SymbolGridOption(symbols: symbols, size: size);
    }
    if (type == 'mirror_text') {
      return CustomPaint(
        size: Size(size, size),
        painter: MirrorTextPainter(data),
      );
    }
    if (type == 'punch_hole') {
      return CustomPaint(size: Size(size, size), painter: PunchPainter(data));
    }
    if (type == 'geo_piece') {
      return CustomPaint(
        size: Size(size, size),
        painter: _GeoPieceOptionPainter(data),
      );
    }
    if (type == 'geo_cell') {
      return _GeoCell(data: data, size: size);
    }
    if (type == 'embedded_option') {
      return _EmbeddedOption(data: data, size: size);
    }
    return FigureWidget(data: data, size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Geo completion option — a single filled or empty cell
// ─────────────────────────────────────────────────────────────────────────────
class _GeoCell extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;
  const _GeoCell({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final filled = data['filled'] as bool? ?? false;
    final mark = data['mark'] as String? ?? 'none';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: !filled && mark != 'none'
          ? Center(child: _mark(mark, size))
          : null,
    );
  }

  Widget _mark(String mark, double size) {
    final color = const Color(0xFFCBD5E1);
    final s = size * 0.28;
    if (mark == 'dot') {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    // cross
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: _CrossPainter(color)),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  const _CrossPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded figure option — two shapes overlaid / adjacent
// Shows two small shapes so student can see if the target is one of them
// ─────────────────────────────────────────────────────────────────────────────
class _EmbeddedOption extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;
  const _EmbeddedOption({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final shapes = (data['shapes'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final s = size * 0.42; // each sub-shape at ~42% of card size

    // 3-shape layout: triangle arrangement
    //   shape[0] — top-left
    //   shape[1] — top-right
    //   shape[2] — bottom-centre
    // This makes the target genuinely harder to find — no obvious "A or B" layout
    if (shapes.length >= 3) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: FigureWidget(data: shapes[0], size: s),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: FigureWidget(data: shapes[1], size: s),
            ),
            Positioned(
              bottom: 0,
              left: size / 2 - s / 2,
              child: FigureWidget(data: shapes[2], size: s),
            ),
          ],
        ),
      );
    }

    // Fallback for legacy 2-shape options
    final offset = data['offset'] as int? ?? 1;
    final Alignment alignA;
    final Alignment alignB;
    switch (offset) {
      case 1:
        alignA = Alignment.bottomLeft;
        alignB = Alignment.topRight;
        break;
      case 2:
        alignA = Alignment.topLeft;
        alignB = Alignment.bottomRight;
        break;
      case 3:
        alignA = Alignment.topRight;
        alignB = Alignment.bottomLeft;
        break;
      default:
        alignA = Alignment.bottomRight;
        alignB = Alignment.topLeft;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: alignA,
            child: FigureWidget(data: shapes[0], size: s),
          ),
          Align(
            alignment: alignB,
            child: FigureWidget(data: shapes[1], size: s),
          ),
        ],
      ),
    );
  }
}

// ── Geo piece option painter (reuses same logic as question renderer) ─────────
class _GeoPieceOptionPainter extends CustomPainter {
  final Map<String, dynamic> data;
  static const Color _ink = Color(0xFF1E293B);
  static const Color _fill = Color(0xFFE2E8F0);
  const _GeoPieceOptionPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final int shape = (data['shape'] as num?)?.toInt() ?? 0;
    final int cut = (data['cut'] as num?)?.toInt() ?? 0;
    final int piece = (data['piece'] as num?)?.toInt() ?? 1;

    final stroke = Paint()
      ..color = _ink
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = _fill
      ..style = PaintingStyle.fill;

    final m = size.width * 0.1;
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
        path = _sq(l, t, r, b, cx, cy, cut, piece);
        break;
      case 1:
        path = _tr(l, t, r, b, cx, cy, cut, piece);
        break;
      default:
        path = _ci(cx, cy, rad, cut, piece);
        break;
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  static Path _sq(
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

  static Path _tr(
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
        {
          final my = t + (b - t) * 0.5;
          final mll = l + (my - t) / (b - t) * (cx - l);
          final mlr = cx + (my - t) / (b - t) * (r - cx);
          return piece == 0
              ? (Path()
                  ..moveTo(cx, t)
                  ..lineTo(mlr, my)
                  ..lineTo(mll, my)
                  ..close())
              : (Path()
                  ..moveTo(mll, my)
                  ..lineTo(mlr, my)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close());
        }
      case 1:
        return piece == 0
            ? (Path()
                ..moveTo(cx, t)
                ..lineTo(cx, b)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(cx, t)
                ..lineTo(r, b)
                ..lineTo(cx, b)
                ..close());
      case 2:
        {
          final mx = (cx + r) / 2;
          final my = (t + b) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(l, b)
                  ..lineTo(cx, t)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(l, b)
                  ..lineTo(mx, my)
                  ..lineTo(r, b)
                  ..close());
        }
      default:
        {
          final mx = (cx + l) / 2;
          final my = (t + b) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(r, b)
                  ..lineTo(cx, t)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(r, b)
                  ..lineTo(mx, my)
                  ..lineTo(l, b)
                  ..close());
        }
    }
  }

  static Path _ci(double cx, double cy, double r, int cut, int piece) {
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
  bool shouldRepaint(covariant _GeoPieceOptionPainter old) => old.data != data;
}

class _SymbolGridOption extends StatelessWidget {
  final List<String> symbols;
  final double size;

  const _SymbolGridOption({required this.symbols, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(size * 0.06),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: symbols
            .take(4)
            .map(
              (s) => Center(
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 18,
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
}
