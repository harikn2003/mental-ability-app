import 'package:flutter/material.dart';

/// PunchPainter renders a square piece of paper showing:
///   - fold_axis: 0=Vertical, 1=Horizontal, 2=Double Fold (legacy single-panel
///     folded state); -1 when 'folds' is used instead
///   - folds: optional list of fold codes ('v', 'h', 'd', 'a' - see
///     ExamStyleGenerator.punchHole) drawn as step panels; 'step' picks the
///     panel (0 = flat paper with the first fold marked, folds.length = fully
///     folded and punched)
///   - holes: list of {x, y} in 0..1 normalised space, optionally with
///     'shape' ('circle' default, 'square', 'tri') and 'dir' for triangles
///     (0 up, 1 right, 2 down, 3 left)
///   - unfolded: true/false
class PunchPainter extends CustomPainter {
  final Map<String, dynamic> data;

  PunchPainter(this.data);

  static const Color _paper = Color(0xFFFAFAF0);
  static const Color _border = Color(0xFF334155);
  static const Color _fold = Color(0xFFCBD5E1);
  static const Color _hole = Color(0xFF0F172A);
  static const Color _foldLine = Color(0xFF64748B);

  // Kept side of each fold, and the flap that folds over it (unit square).
  static const _kept = {
    'v': [Offset(0, 0), Offset(0.5, 0), Offset(0.5, 1), Offset(0, 1)],
    'h': [Offset(0, 0), Offset(1, 0), Offset(1, 0.5), Offset(0, 0.5)],
    'd': [Offset(0, 0), Offset(1, 1), Offset(0, 1)],
    'a': [Offset(0, 0), Offset(1, 0), Offset(0, 1)],
  };
  static const _flap = {
    'v': [Offset(0.5, 0), Offset(1, 0), Offset(1, 1), Offset(0.5, 1)],
    'h': [Offset(0, 0.5), Offset(1, 0.5), Offset(1, 1), Offset(0, 1)],
    'd': [Offset(0, 0), Offset(1, 0), Offset(1, 1)],
    'a': [Offset(1, 0), Offset(1, 1), Offset(0, 1)],
  };
  static const _line = {
    'v': [Offset(0.5, 0), Offset(0.5, 1)],
    'h': [Offset(0, 0.5), Offset(1, 0.5)],
    'd': [Offset(0, 0), Offset(1, 1)],
    'a': [Offset(1, 0), Offset(0, 1)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.width * 0.06;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );

    final bool unfolded = data['unfolded'] ?? false;
    final folds = (data['folds'] as List?)?.cast<String>();
    if (folds != null && !unfolded) {
      _paintFoldStep(canvas, size, rect, folds, data['step'] as int? ?? folds.length);
      return;
    }

    final paperPaint = Paint()..color = _paper;
    final borderPaint = Paint()
      ..color = _border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final foldPaint = Paint()..color = _fold;
    final foldLinePaint = Paint()
      ..color = _foldLine
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Paper background
    canvas.drawRect(rect, paperPaint);

    final int axis = data['fold_axis'] ?? 0; // 0=V, 1=H, 2=Double

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
    _drawHoles(canvas, size, rect);
  }

  Path _poly(Rect rect, List<Offset> pts) {
    final p = Path();
    for (int i = 0; i < pts.length; i++) {
      final o = Offset(rect.left + pts[i].dx * rect.width, rect.top + pts[i].dy * rect.height);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  /// One panel of the fold sequence: the paper after [step] folds; if more
  /// folds follow, the flap about to fold is shaded and the fold dashed.
  void _paintFoldStep(Canvas canvas, Size size, Rect rect, List<String> folds, int step) {
    // Faint outline of the whole sheet for orientation (dotted in the exam).
    final ghost = Paint()
      ..color = _foldLine.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _dashedPath(canvas, _poly(rect, const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)]), ghost, 3, 3);

    var paper = _poly(rect, const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)]);
    for (int i = 0; i < step && i < folds.length; i++) {
      paper = Path.combine(PathOperation.intersect, paper, _poly(rect, _kept[folds[i]]!));
    }
    canvas.drawPath(paper, Paint()..color = _paper);
    if (step < folds.length) {
      final flap = Path.combine(PathOperation.intersect, paper, _poly(rect, _flap[folds[step]]!));
      canvas.drawPath(flap, Paint()..color = _fold);
      canvas.save();
      canvas.clipPath(paper);
      final l = _line[folds[step]]!;
      final a = Offset(rect.left + l[0].dx * rect.width, rect.top + l[0].dy * rect.height);
      final b = Offset(rect.left + l[1].dx * rect.width, rect.top + l[1].dy * rect.height);
      _dashedPath(
          canvas,
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy),
          Paint()
            ..color = _border
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke,
          5,
          4);
      canvas.restore();
    }
    canvas.drawPath(
        paper,
        Paint()
          ..color = _border
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    if (step >= folds.length) _drawHoles(canvas, size, rect);
  }

  static void _dashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
      }
    }
  }

  void _drawHoles(Canvas canvas, Size size, Rect rect) {
    final holePaint = Paint()
      ..color = _hole
      ..style = PaintingStyle.fill;
    final List holes = data['holes'] ?? [];
    final r = size.width * 0.07;
    for (final h in holes) {
      final px = rect.left + (h['x'] as num).toDouble() * rect.width;
      final py = rect.top + (h['y'] as num).toDouble() * rect.height;
      switch (h['shape']) {
        case 'square':
          canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: r * 1.7, height: r * 1.7), holePaint);
          break;
        case 'tri':
          // Isosceles triangle pointing 'dir' (0 up, 1 right, 2 down, 3 left).
          const dirs = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];
          final d = dirs[(h['dir'] as int? ?? 0) % 4];
          final n = Offset(-d.dy, d.dx);
          final tip = Offset(px, py) + d * (r * 1.25);
          final base = Offset(px, py) - d * (r * 0.8);
          canvas.drawPath(
              Path()
                ..moveTo(tip.dx, tip.dy)
                ..lineTo((base + n * r).dx, (base + n * r).dy)
                ..lineTo((base - n * r).dx, (base - n * r).dy)
                ..close(),
              holePaint);
          break;
        default:
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
