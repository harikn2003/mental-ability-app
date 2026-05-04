import 'dart:math';

import 'package:flutter/material.dart';

/// FigurePainter — single painter used for ALL shapes in ALL question types.
///
/// Shape codes:
///   0=circle  1=square  2=triangle(R)  3=diamond
///   4=cross   5=pentagon  6=hexagon    7=arrow(→)  8=L-shape
///
/// Data keys:
///   shape         int   0-8
///   filled        bool  solid fill vs outline
///   rotation      int   0-3  (×90°)
///   mirror        bool  horizontal flip
///   dots          int   0-4  small dots BELOW the shape (stable, not rotated)
///   inner         int   0=none, 1-8 = shape drawn inside at half size
///   lines         int   0-3  vertical lines crossing the shape (embedded)
///   missingCorner int   0=none, 1=TL, 2=TR, 3=BL, 4=BR — sides removed
///   isPiece       bool  (kept for compat, unused)
class FigurePainter extends CustomPainter {
  final Map<String, dynamic> data;
  static const Color _ink = Color(0xFF1E293B);

  const FigurePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final int shape = data['shape'] ?? 0;
    final bool filled = data['filled'] ?? false;
    final int rot = data['rotation'] ?? 0;
    final bool mirror = data['mirror'] ?? false;
    final int dots = data['dots'] ?? 0;
    final int inner = data['inner'] ?? 0;
    final int lines = data['lines'] ?? 0;
    final int missing = data['missingCorner'] ?? 0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    // Leave bottom margin for dots when present
    final r = size.width * (dots > 0 ? 0.27 : 0.32);

    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;

    // ── DOTS: always in screen space — never rotate with the shape ────────────
    // Bug fix: dots were drawn before canvas.save/rotate in previous version,
    // which caused them to shift position when the shape was rotated.
    // Now drawn last, after canvas.restore(), in stable coordinates.

    // ── missingCorner: drawn in UN-rotated screen space ───────────────────────
    // Each corner must look distinct — rotating would make TL look like TR etc.
    if (missing != 0) {
      _drawMissingCorner(canvas, r, cx, cy, missing, paint);
      _drawDots(canvas, dots, r, cx, cy, size);
      return; // no rotation, no inner, no lines needed for geo_completion
    }

    // ── Apply rotation + mirror ───────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx, cy);
    if (mirror) canvas.scale(-1.0, 1.0);
    canvas.rotate(rot * pi / 2);
    canvas.translate(-cx, -cy);

    final outerR = inner > 0 ? r * 1.10 : r;
    _drawShape(canvas, shape, outerR, cx, cy, paint);

    // Inner shape (outline only, made larger for better visibility when overlapping)
    // Enhanced visual rendering with improved contrast and depth
    if (inner > 0) {
      final innerR = r * 0.56;

      // Draw subtle shadow effect for depth perception
      final shadowPaint = Paint()
        ..color = _ink.withOpacity(0.08)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      _drawShape(canvas, inner - 1, innerR * 1.03, cx, cy, shadowPaint);

      // Draw main inner shape with improved stroke
      final innerPaint = Paint()
        ..color = _ink
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _drawShape(canvas, inner - 1, innerR, cx, cy, innerPaint);
    }

    // Vertical crossing lines (embedded figure questions)
    if (lines > 0) {
      final lp = Paint()
        ..color = _ink
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      for (int i = 1; i <= lines; i++) {
        final x = cx - r * 0.72 + (r * 1.44 / (lines + 1)) * i;
        canvas.drawLine(Offset(x, cy - r * 0.85), Offset(x, cy + r * 0.85), lp);
      }
    }

    canvas.restore();

    // Dots drawn after restore so they are always level/stable
    _drawDots(canvas, dots, r, cx, cy, size);
  }

  // ── Dots helper (screen-space, below the shape) ───────────────────────────
  static void _drawDots(Canvas canvas, int dots, double r,
      double cx, double cy, Size size) {
    if (dots <= 0) return;
    final dotR = size.width * 0.055;
    final gap = dotR * 2.6;
    final totalW = (dots - 1) * gap;
    final dotY = cy + r * 1.55;

    // Draw dot outline first (subtle shadow for depth)
    final outlinePaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < dots; i++) {
      final offset = Offset(cx - totalW / 2 + i * gap, dotY);
      canvas.drawCircle(offset, dotR * 1.05, outlinePaint);
    }

    // Draw filled dots with better contrast
    final dp = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < dots; i++) {
      canvas.drawCircle(
          Offset(cx - totalW / 2 + i * gap, dotY), dotR, dp);
    }
  }

  // ── Shape drawing ─────────────────────────────────────────────────────────
  static void _drawShape(Canvas canvas, int shape, double r,
      double cx, double cy, Paint paint) {
    switch (shape) {
      case 0: // Circle
        canvas.drawCircle(Offset(cx, cy), r, paint);
        break;
      case 1: // Square
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, cy), width: r * 1.9, height: r * 1.9),
            paint);
        break;
      case 2: // Right-angle triangle — clearly asymmetric
        canvas.drawPath(Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.85)
          ..lineTo(cx + r * 0.85, cy + r * 0.85)..lineTo(
              cx - r * 0.85, cy + r * 0.85)
          ..close(), paint);
        break;
      case 3: // Diamond
        canvas.drawPath(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r * 0.78, cy)..lineTo(cx, cy + r)..lineTo(
              cx - r * 0.78, cy)
          ..close(), paint);
        break;
      case 4: // Plus / cross
        final w = r * 0.38;
        canvas.drawPath(Path()
          ..addRect(Rect.fromCenter(
              center: Offset(cx, cy), width: w, height: r * 1.9))..addRect(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: r * 1.9, height: w)),
            paint);
        break;
      case 5: // Pentagon
        canvas.drawPath(_polygon(cx, cy, r, 5, -pi / 2), paint);
        break;
      case 6: // Hexagon
        canvas.drawPath(_polygon(cx, cy, r, 6, 0), paint);
        break;
      case 7: // Arrow →
        canvas.drawPath(Path()
          ..moveTo(cx - r * 0.58, cy - r * 0.30)
          ..lineTo(cx + r * 0.08, cy - r * 0.30)..lineTo(
              cx + r * 0.08, cy - r * 0.62)..lineTo(cx + r * 0.82, cy)..lineTo(
              cx + r * 0.08, cy + r * 0.62)..lineTo(
              cx + r * 0.08, cy + r * 0.30)..lineTo(
              cx - r * 0.58, cy + r * 0.30)
          ..close(), paint);
        break;
      case 8: // L-shape — highly asymmetric, great for rotation/mirror tests
        final sw = r * 0.52;
        canvas.drawPath(Path()
          ..moveTo(cx - r * 0.75, cy - r * 0.85)
          ..lineTo(cx - r * 0.75 + sw, cy - r * 0.85)..lineTo(
              cx - r * 0.75 + sw, cy + r * 0.85 - sw)..lineTo(
              cx + r * 0.75, cy + r * 0.85 - sw)..lineTo(
              cx + r * 0.75, cy + r * 0.85)..lineTo(
              cx - r * 0.75, cy + r * 0.85)
          ..close(), paint);
        break;
      default:
        canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  // ── Missing-corner square ─────────────────────────────────────────────────
  // Draws a square with exactly two adjacent sides removed at one corner.
  // FIX: removed the "pizza slice" lines to centre that made all variants
  //      look like wedge diagrams. Now it's simply an open square.
  //
  //  corner 1 = TL → skip top side  + left side
  //  corner 2 = TR → skip top side  + right side
  //  corner 3 = BL → skip bot side  + left side
  //  corner 4 = BR → skip bot side  + right side
  static void _drawMissingCorner(Canvas canvas, double r,
      double cx, double cy, int corner, Paint paint) {
    final h = r * 0.92;
    final tl = Offset(cx - h, cy - h);
    final tr = Offset(cx + h, cy - h);
    final br = Offset(cx + h, cy + h);
    final bl = Offset(cx - h, cy + h);

    final segs = [
      [tl, tr], // 0 = top
      [tr, br], // 1 = right
      [br, bl], // 2 = bottom
      [bl, tl], // 3 = left
    ];

    final int skipA = (corner == 1 || corner == 2) ? 0 : 2; // top or bottom
    final int skipB = (corner == 1 || corner == 3) ? 3 : 1; // left or right

    for (int i = 0; i < 4; i++) {
      if (i == skipA || i == skipB) continue;
      canvas.drawLine(segs[i][0], segs[i][1], paint);
    }
  }

  static Path _polygon(double cx, double cy, double r, int n, double start) {
    final p = Path();
    for (int i = 0; i < n; i++) {
      final a = start + 2 * pi * i / n;
      i == 0
          ? p.moveTo(cx + r * cos(a), cy + r * sin(a))
          : p.lineTo(cx + r * cos(a), cy + r * sin(a));
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant FigurePainter old) => old.data != data;
}

/// Convenience widget wrapping FigurePainter.
class FigureWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const FigureWidget({super.key, required this.data, this.size = 64});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(
        size: Size(size, size),
        painter: FigurePainter(data),
      );
}