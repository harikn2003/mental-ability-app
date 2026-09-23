import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a `'line_fig'` map (see lib/engine/line_figure.dart): a figure on an
/// integer lattice, scaled to fit and centred in the canvas.
class LineFigurePainter extends CustomPainter {
  final Map<String, dynamic> data;

  LineFigurePainter(this.data);

  static const Color _ink = Color(0xFF1E293B);
  static const Color _cellFill = Color(0xFFE2E8F0);

  @override
  void paint(Canvas canvas, Size size) {
    final int w = data['w'] as int? ?? 1;
    final int h = data['h'] as int? ?? 1;
    if (w <= 0 || h <= 0) return;

    final pad = size.shortestSide * 0.12;
    final unit = min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    var ox = (size.width - unit * w) / 2;
    var oy = (size.height - unit * h) / 2;

    List<List<int>> list(String k) => [for (final e in (data[k] as List? ?? const [])) (e as List).cast<int>()];

    // 'center': the lattice only sets the SCALE (e.g. geo pieces all drawn
    // at the same 4x4 scale as the square they're cut from, so size can be
    // compared); the content itself is centred in the canvas.
    if (data['center'] == true) {
      final xs = <int>[], ys = <int>[];
      for (final s in list('segs')) {
        xs..add(s[0])..add(s[2]);
        ys..add(s[1])..add(s[3]);
      }
      for (final c in [...list('cells'), ...list('dots'), ...list('tris')]) {
        xs..add(c[0])..add(c[0] + 1);
        ys..add(c[1])..add(c[1] + 1);
      }
      if (xs.isNotEmpty) {
        ox = size.width / 2 - (xs.reduce(min) + xs.reduce(max)) / 2 * unit;
        oy = size.height / 2 - (ys.reduce(min) + ys.reduce(max)) / 2 * unit;
      }
    }
    Offset p(num x, num y) => Offset(ox + x * unit, oy + y * unit);

    final stroke = Paint()
      ..color = _ink
      ..strokeWidth = max(1.6, size.shortestSide * 0.028)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.fill;

    // Filled cells first, so every line sits on top of them.
    final cellPaint = Paint()..color = _cellFill;
    for (final c in list('cells')) {
      // Slight overlap hides hairline seams between neighbouring cells.
      canvas.drawRect(Rect.fromPoints(p(c[0], c[1]), p(c[0] + 1, c[1] + 1)).inflate(0.4), cellPaint);
    }

    const corners = [(0, 0), (1, 0), (1, 1), (0, 1)];
    for (final t in list('tris')) {
      final (cx, cy, k) = (t[0], t[1], t[2]);
      // Right angle at corner k; the other two vertices are its neighbours.
      final a = corners[k], b = corners[(k + 1) % 4], c = corners[(k + 3) % 4];
      canvas.drawPath(
          Path()
            ..moveTo(p(cx + a.$1, cy + a.$2).dx, p(cx + a.$1, cy + a.$2).dy)
            ..lineTo(p(cx + b.$1, cy + b.$2).dx, p(cx + b.$1, cy + b.$2).dy)
            ..lineTo(p(cx + c.$1, cy + c.$2).dx, p(cx + c.$1, cy + c.$2).dy)
            ..close(),
          ink);
    }

    if (data['frame'] == true) {
      canvas.drawRect(Rect.fromPoints(p(0, 0), p(w, h)), stroke);
    }
    for (final s in list('segs')) {
      canvas.drawLine(p(s[0], s[1]), p(s[2], s[3]), stroke);
    }
    for (final d in list('dots')) {
      canvas.drawCircle(p(d[0] + 0.5, d[1] + 0.5), unit * 0.16, ink);
    }
    final ringPaint = Paint()
      ..color = _ink
      ..strokeWidth = stroke.strokeWidth * 0.8
      ..style = PaintingStyle.stroke;
    final ringFill = Paint()..color = Colors.white;
    for (final r in list('rings')) {
      canvas.drawCircle(p(r[0], r[1]), unit * 0.17, ringFill);
      canvas.drawCircle(p(r[0], r[1]), unit * 0.17, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineFigurePainter old) => old.data != data;
}
