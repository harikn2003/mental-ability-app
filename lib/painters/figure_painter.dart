import 'dart:math';

import 'package:flutter/material.dart';

/// FigurePainter — single painter used for ALL shapes in ALL question types.
///
/// Shape codes:
///   0=circle  1=square  2=triangle(R) 3=diamond
///   4=cross   5=pentagon  6=hexagon     7=arrow(→)  8=L-shape
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
    final bool isPiece = data['isPiece'] ?? false;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.30;

    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = (filled && !isPiece)
          ? PaintingStyle.fill
          : PaintingStyle.stroke;

    // Dots at bottom (stable)
    if (!isPiece && dots > 0) {
      final dp = Paint()
        ..color = _ink
        ..style = PaintingStyle.fill;
      final dotR = r * 0.15;
      final spacing = dotR * 2.8;
      final totalW = (dots - 1) * spacing;
      final dotY = cy + r * 1.4;
      for (int i = 0; i < dots; i++) {
        final dx = cx - totalW / 2 + i * spacing;
        canvas.drawCircle(Offset(dx, dotY), dotR, dp);
      }
    }

    canvas.save();
    canvas.translate(cx, cy);
    if (mirror) canvas.scale(-1.0, 1.0);
    canvas.rotate(rot * pi / 2);
    canvas.translate(-cx, -cy);

    if (missing != 0) {
      _drawMissingCorner(canvas, r, cx, cy, shape, missing, paint, isPiece);
    } else if (!isPiece) {
      _drawShape(canvas, shape, r, cx, cy, paint);
    }

    if (!isPiece && inner > 0) {
      final ip = Paint()
        ..color = _ink
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _drawShape(canvas, inner - 1, r * 0.45, cx, cy, ip);
    }

    if (!isPiece && lines > 0) {
      final lp = Paint()
        ..color = _ink
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      for (int i = 1; i <= lines; i++) {
        final x = cx - r * 0.7 + (r * 1.4 / (lines + 1)) * i;
        canvas.drawLine(Offset(x, cy - r * 0.8), Offset(x, cy + r * 0.8), lp);
      }
    }

    canvas.restore();
  }

  static void _drawShape(
    Canvas canvas,
    int shape,
    double r,
    double cx,
    double cy,
    Paint paint,
  ) {
    switch (shape) {
      case 0: // Circle
        canvas.drawCircle(Offset(cx, cy), r, paint);
        break;
      case 1: // Square
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: r * 1.8,
            height: r * 1.8,
          ),
          paint,
        );
        break;
      case 2: // Right-angled Triangle (Asymmetric)
        canvas.drawPath(
          Path()
            ..moveTo(cx - r * 0.8, cy - r * 0.8)
            ..lineTo(cx + r * 0.8, cy + r * 0.8)
            ..lineTo(cx - r * 0.8, cy + r * 0.8)
            ..close(),
          paint,
        );
        break;
      case 3: // Diamond
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - r)
            ..lineTo(cx + r * 0.8, cy)
            ..lineTo(cx, cy + r)
            ..lineTo(cx - r * 0.8, cy)
            ..close(),
          paint,
        );
        break;
      case 4: // Cross
        final w = r * 0.4;
        canvas.drawPath(
          Path()
            ..addRect(
              Rect.fromCenter(
                center: Offset(cx, cy),
                width: w,
                height: r * 1.8,
              ),
            )
            ..addRect(
              Rect.fromCenter(
                center: Offset(cx, cy),
                width: r * 1.8,
                height: w,
              ),
            ),
          paint,
        );
        break;
      case 5: // Pentagon
        canvas.drawPath(_polygon(cx, cy, r, 5, -pi / 2), paint);
        break;
      case 6: // Hexagon
        canvas.drawPath(_polygon(cx, cy, r, 6, 0), paint);
        break;
      case 7: // Arrow (Asymmetric)
        canvas.drawPath(
          Path()
            ..moveTo(cx - r * 0.6, cy - r * 0.3)
            ..lineTo(cx + r * 0.1, cy - r * 0.3)
            ..lineTo(cx + r * 0.1, cy - r * 0.6)
            ..lineTo(cx + r * 0.8, cy)
            ..lineTo(cx + r * 0.1, cy + r * 0.6)
            ..lineTo(cx + r * 0.1, cy + r * 0.3)
            ..lineTo(cx - r * 0.6, cy + r * 0.3)
            ..close(),
          paint,
        );
        break;
      case 8: // L-Shape (Highly Asymmetric)
        final w = r * 0.5;
        canvas.drawPath(
          Path()
            ..moveTo(cx - r * 0.7, cy - r * 0.8)
            ..lineTo(cx - r * 0.7 + w, cy - r * 0.8)
            ..lineTo(cx - r * 0.7 + w, cy + r * 0.8 - w)
            ..lineTo(cx + r * 0.7, cy + r * 0.8 - w)
            ..lineTo(cx + r * 0.7, cy + r * 0.8)
            ..lineTo(cx - r * 0.7, cy + r * 0.8)
            ..close(),
          paint,
        );
        break;
      default:
        canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  static void _drawMissingCorner(
    Canvas canvas,
    double r,
    double cx,
    double cy,
    int shape,
    int corner,
    Paint paint, [
    bool isPiece = false,
  ]) {
    if (shape == 0) {
      // Circle
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      // corners: 1=TL, 2=TR, 3=BL, 4=BR
      // Quadrant angles: TL: -pi to -pi/2, TR: -pi/2 to 0, BR: 0 to pi/2, BL: pi/2 to pi
      double startAngle;
      double sweepAngle = 1.5 * pi;

      switch (corner) {
        case 1:
          startAngle = -pi / 2;
          break; // TL missing: draw from TR around to BL
        case 2:
          startAngle = 0;
          break; // TR missing
        case 3:
          startAngle = -pi;
          break; // BL missing
        case 4:
          startAngle = -3 * pi / 2;
          break; // BR missing
        default:
          startAngle = 0;
      }

      if (isPiece) {
        // Draw only the missing piece (a wedge/quadrant)
        final pieceStart = startAngle + 1.5 * pi;
        canvas.drawArc(rect, pieceStart, 0.5 * pi, true, paint);
      } else {
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
        // Draw lines to center to show it's a "piece" missing
        final endAngle = startAngle + sweepAngle;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + r * cos(startAngle), cy + r * sin(startAngle)),
          paint,
        );
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + r * cos(endAngle), cy + r * sin(endAngle)),
          paint,
        );
      }
    } else if (shape == 2) {
      // Triangle (R-angle)
      // Triangle is defined by TL, BR, BL corners.
      // We'll just stick to Square for now for reliable missing corners
      _drawSquareMissing(canvas, r, cx, cy, corner, paint, isPiece);
    } else {
      _drawSquareMissing(canvas, r, cx, cy, corner, paint, isPiece);
    }
  }

  static void _drawSquareMissing(
    Canvas canvas,
    double r,
    double cx,
    double cy,
    int corner,
    Paint paint,
    bool isPiece,
  ) {
    final half = r * 0.9;
    final tl = Offset(cx - half, cy - half);
    final tr = Offset(cx + half, cy - half);
    final br = Offset(cx + half, cy + half);
    final bl = Offset(cx - half, cy + half);
    final sides = [
      [tl, tr],
      [tr, br],
      [br, bl],
      [bl, tl],
    ];

    // For Square, corner also defines which sides to "skip"
    // 1=TL skip 0,3 | 2=TR skip 0,1 | 3=BL skip 2,3 | 4=BR skip 1,2
    int skip1 = (corner <= 2) ? 0 : 2;
    int skip2 = (corner == 1 || corner == 3) ? 3 : 1;

    for (int i = 0; i < 4; i++) {
      bool isSkipped = (i == skip1 || i == skip2);
      if (isPiece ? isSkipped : !isSkipped) {
        canvas.drawLine(sides[i][0], sides[i][1], paint);
      }
    }
    // Also draw the "inner" lines connecting to the center point to make it look like a puzzle
    if (!isPiece) {
      // Draw lines from center to the endpoints of the missing sides
      // If TL missing (1), connect center to T and L endpoints
      Offset p1, p2;
      switch (corner) {
        case 1:
          p1 = tr;
          p2 = bl;
          break; // TL missing
        case 2:
          p1 = tl;
          p2 = br;
          break; // TR
        case 3:
          p1 = tl;
          p2 = br;
          break; // BL - wait, logic for TR/BL/BR
        case 4:
          p1 = tr;
          p2 = bl;
          break;
        default:
          return;
      }
      // Actually, just connect center to the two points on the boundary
      // For TL (1): it's the top-mid and left-mid? No, it's the corner points tr and bl?
      // Let's just use the simpler logic for now: connect center to the missing corner's neighbors
      if (corner == 1) {
        canvas.drawLine(Offset(cx, cy), tr, paint);
        canvas.drawLine(Offset(cx, cy), bl, paint);
      }
      if (corner == 2) {
        canvas.drawLine(Offset(cx, cy), tl, paint);
        canvas.drawLine(Offset(cx, cy), br, paint);
      }
      if (corner == 3) {
        canvas.drawLine(Offset(cx, cy), tl, paint);
        canvas.drawLine(Offset(cx, cy), br, paint);
      }
      if (corner == 4) {
        canvas.drawLine(Offset(cx, cy), tr, paint);
        canvas.drawLine(Offset(cx, cy), bl, paint);
      }
    } else {
      // For the piece, connect the endpoints back to the center
      if (corner == 1) {
        canvas.drawLine(Offset(cx, cy), tr, paint);
        canvas.drawLine(Offset(cx, cy), bl, paint);
      }
      if (corner == 2) {
        canvas.drawLine(Offset(cx, cy), tl, paint);
        canvas.drawLine(Offset(cx, cy), br, paint);
      }
      if (corner == 3) {
        canvas.drawLine(Offset(cx, cy), tl, paint);
        canvas.drawLine(Offset(cx, cy), br, paint);
      }
      if (corner == 4) {
        canvas.drawLine(Offset(cx, cy), tr, paint);
        canvas.drawLine(Offset(cx, cy), bl, paint);
      }
    }
  }

  static Path _polygon(double cx, double cy, double r, int n, double start) {
    final p = Path();
    for (int i = 0; i < n; i++) {
      final a = start + 2 * pi * i / n;
      final x = cx + r * cos(a);
      final y = cy + r * sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant FigurePainter old) => old.data != data;
}

class FigureWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const FigureWidget({super.key, required this.data, this.size = 64});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: FigurePainter(data));
}
