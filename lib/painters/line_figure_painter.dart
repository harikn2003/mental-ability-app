import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/line_figure.dart';

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
    List<(int, int, String)> glyphList() =>
        [for (final g in (data['glyphs'] as List? ?? const [])) ((g as List)[0] as int, g[1] as int, g[2] as String)];

    // 'center': the lattice only sets the SCALE (e.g. geo pieces all drawn
    // at the same 4x4 scale as the square they're cut from, so size can be
    // compared); the content itself is centred in the canvas.
    if (data['center'] == true) {
      final xs = <int>[], ys = <int>[];
      for (final s in list('segs')) {
        xs..add(s[0])..add(s[2]);
        ys..add(s[1])..add(s[3]);
      }
      for (final c in [...list('cells'), ...list('dots'), ...list('tris'), ...list('hatch'), for (final g in glyphList()) [g.$1, g.$2]]) {
        xs..add(c[0])..add(c[0] + 1);
        ys..add(c[1])..add(c[1] + 1);
      }
      for (final a in list('arrows')) {
        xs..add(a[0])..add(a[2]);
        ys..add(a[1])..add(a[3]);
      }
      for (final a in list('arcs')) {
        final (sx, sy) = LineFig.arcQuadrants[a[3]];
        xs..add((a[0] / 2).floor())..add(((a[0] + sx * a[2]) / 2).round());
        ys..add((a[1] / 2).floor())..add(((a[1] + sy * a[2]) / 2).round());
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
    Path region(int cx, int cy, int part) {
      if (part == 4) return Path()..addRect(Rect.fromPoints(p(cx, cy), p(cx + 1, cy + 1)));
      final a = corners[part], b = corners[(part + 1) % 4], c = corners[(part + 3) % 4];
      return Path()
        ..moveTo(p(cx + a.$1, cy + a.$2).dx, p(cx + a.$1, cy + a.$2).dy)
        ..lineTo(p(cx + b.$1, cy + b.$2).dx, p(cx + b.$1, cy + b.$2).dy)
        ..lineTo(p(cx + c.$1, cy + c.$2).dx, p(cx + c.$1, cy + c.$2).dy)
        ..close();
    }

    // Hatching: parallel stripes clipped to the cell / half-cell. Spacing is
    // wide enough that the stripe direction reads clearly at option size.
    final hatchPaint = Paint()
      ..color = _ink
      ..strokeWidth = max(1.0, stroke.strokeWidth * 0.6)
      ..style = PaintingStyle.stroke;
    // All regions with the same stripe direction are clipped as ONE path and
    // striped with a global phase, so stripes run on unbroken across cells
    // (per-cell clipping left seams at every cell edge).
    for (int dir = 0; dir < 4; dir++) {
      final cellsInDir = list('hatch').where((hc) => hc[3] == dir).toList();
      if (cellsInDir.isEmpty) continue;
      final clip = Path();
      for (final hc in cellsInDir) {
        clip.addPath(region(hc[0], hc[1], hc[2]), Offset.zero);
      }
      final (vx, vy) = LineFig.hatchDirs[dir];
      final len = sqrt((vx * vx + vy * vy).toDouble());
      final n = Offset(-vy / len, vx / len), d = Offset(vx / len, vy / len);
      // Stripe spacing divides one cell's width along the normal (unit for
      // straight stripes, unit/√2 for diagonal ones), so the pattern repeats
      // exactly from cell to cell.
      final gap = len > 1 ? unit / sqrt2 / 3 : unit / 4;
      final origin = p(0, 0);
      final b = clip.getBounds();
      final corners = [b.topLeft, b.topRight, b.bottomLeft, b.bottomRight].map((c) => (c - origin).dx * n.dx + (c - origin).dy * n.dy);
      final lo = (corners.reduce(min) / gap).floor(), hi = (corners.reduce(max) / gap).ceil();
      final reach = b.longestSide * 1.5;
      canvas.save();
      canvas.clipPath(clip);
      for (int k = lo; k <= hi; k++) {
        final o = origin + n * (k * gap) + d * ((b.center - origin).dx * d.dx + (b.center - origin).dy * d.dy);
        canvas.drawLine(o - d * reach, o + d * reach, hatchPaint);
      }
      canvas.restore();
    }

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
    for (final a in list('arcs')) {
      // Doubled coordinates; quadrant q starts at angle (q - 1) * 90° (y down).
      final r = a[2] / 2 * unit;
      canvas.drawArc(Rect.fromCircle(center: p(a[0] / 2, a[1] / 2), radius: r), (a[3] - 1) * pi / 2, pi / 2, false, stroke);
    }
    for (final a in list('arrows')) {
      // Filled head at (x2, y2), pointing away from (x1, y1).
      final tip = p(a[2], a[3]);
      final dir = tip - p(a[0], a[1]);
      final u = dir / dir.distance, n = Offset(-u.dy, u.dx);
      // Never smaller than on a 4x4 figure, so heads stay visible on finer
      // lattices (the 6x6 series arrow).
      final headLen = max(unit * 0.5, size.shortestSide * 0.095);
      final back = tip - u * headLen;
      final half = headLen * 0.48;
      canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((back + n * half).dx, (back + n * half).dy)
            ..lineTo((back - n * half).dx, (back - n * half).dy)
            ..close(),
          ink);
    }
    // Symbols: the glyph's local -2..2 box spans 60% of its cell.
    final glyphStroke = Paint()
      ..color = _ink
      ..strokeWidth = stroke.strokeWidth * 0.85
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (cx, cy, name) in glyphList()) {
      final shape = LineFig.glyphShapes[name];
      if (shape == null) continue;
      final g = unit * 0.15;
      final c = p(cx + 0.5, cy + 0.5);
      Offset q(int x, int y) => c + Offset(x * g, y * g);
      for (final (x1, y1, x2, y2) in shape.$1) {
        canvas.drawLine(q(x1, y1), q(x2, y2), glyphStroke);
      }
      for (final (x, y, r, filled) in shape.$2) {
        // Filled dots a little bigger: at r * 0.8 a 'dot' symbol was easy to miss.
        canvas.drawCircle(q(x, y), r * g * (filled ? 1.3 : 0.8), filled ? ink : glyphStroke);
      }
    }
    for (final d in list('dots')) {
      canvas.drawCircle(p(d[0] + 0.5, d[1] + 0.5), max(unit * 0.16, size.shortestSide * 0.03), ink); // 4x4 size at least
    }
    final ringPaint = Paint()
      ..color = _ink
      ..strokeWidth = stroke.strokeWidth * 0.8
      ..style = PaintingStyle.stroke;
    final ringFill = Paint()..color = Colors.white;
    for (final r in list('rings')) {
      final ringR = max(unit * 0.17, size.shortestSide * 0.032); // as on a 4x4 figure, at least
      canvas.drawCircle(p(r[0], r[1]), ringR, ringFill);
      canvas.drawCircle(p(r[0], r[1]), ringR, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineFigurePainter old) => old.data != data;
}
