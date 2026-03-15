import 'package:flutter/material.dart';

/// PunchPainter renders a square piece of paper showing:
///   - fold_axis: 0=Vertical, 1=Horizontal, 2=Double Fold
///   - holes: list of {x,y} in 0..1 normalised space
///   - unfolded: true/false
class PunchPainter extends CustomPainter {
  final Map<String, dynamic> data;

  PunchPainter(this.data);

  static const Color _paper = Color(0xFFFAFAF0);
  static const Color _border = Color(0xFF334155);
  static const Color _fold = Color(0xFFCBD5E1);
  static const Color _hole = Color(0xFF0F172A);
  static const Color _foldLine = Color(0xFF64748B);

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.width * 0.06;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );

    final paperPaint = Paint()..color = _paper;
    final borderPaint = Paint()
      ..color = _border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final foldPaint = Paint()..color = _fold;
    final holePaint = Paint()
      ..color = _hole
      ..style = PaintingStyle.fill;
    final foldLinePaint = Paint()
      ..color = _foldLine
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Paper background
    canvas.drawRect(rect, paperPaint);

    final bool unfolded = data['unfolded'] ?? false;
    final int axis = data['fold_axis'] ?? 0; // 0=V, 1=H, 2=Double
    final List holes = data['holes'] ?? [];

    if (!unfolded) {
      final cx = rect.left + rect.width / 2;
      final cy = rect.top + rect.height / 2;

      if (axis == 0) {
        // Vertical Fold (Right side folded over Left)
        canvas.drawRect(
          Rect.fromLTRB(cx, rect.top, rect.right, rect.bottom),
          foldPaint,
        );
        canvas.drawLine(
          Offset(cx, rect.top),
          Offset(cx, rect.bottom),
          foldLinePaint,
        );
      } else if (axis == 1) {
        // Horizontal Fold (Bottom side folded over Top)
        canvas.drawRect(
          Rect.fromLTRB(rect.left, cy, rect.right, rect.bottom),
          foldPaint,
        );
        canvas.drawLine(
          Offset(rect.left, cy),
          Offset(rect.right, cy),
          foldLinePaint,
        );
      } else if (axis == 2) {
        // Double Fold (Top-Left quadrant remains)
        // Shading everything except TL quadrant
        canvas.drawRect(
          Rect.fromLTRB(cx, rect.top, rect.right, rect.bottom),
          foldPaint,
        ); // Right half
        canvas.drawRect(
          Rect.fromLTRB(rect.left, cy, cx, rect.bottom),
          foldPaint,
        ); // Bottom-left
        canvas.drawLine(
          Offset(cx, rect.top),
          Offset(cx, rect.bottom),
          foldLinePaint,
        );
        canvas.drawLine(
          Offset(rect.left, cy),
          Offset(rect.right, cy),
          foldLinePaint,
        );
      }
    }

    // Paper border
    canvas.drawRect(rect, borderPaint);

    // Draw holes
    final r = size.width * 0.07;
    for (final h in holes) {
      final px = rect.left + (h['x'] as num).toDouble() * rect.width;
      final py = rect.top + (h['y'] as num).toDouble() * rect.height;
      canvas.drawCircle(Offset(px, py), r, holePaint);
      canvas.drawCircle(
        Offset(px, py),
        r * 0.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
