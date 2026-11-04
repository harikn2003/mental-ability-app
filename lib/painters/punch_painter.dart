import 'dart:math';
import 'dart:typed_data';

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

  /// 'print': a printed paper is plain line art - the sheet is white.
  Color get _paperColor => data['print'] == true ? const Color(0xFFFFFFFF) : _paper;
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

    final paperPaint = Paint()..color = _paperColor;
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
    if (!unfolded) {
      // Which way each fold went (mentors: show arrows for the folds).
      if (axis == 0 || axis == 2) _foldArrow(canvas, rect, const Offset(0.8, 0.2), const Offset(0.35, 0.2));
      if (axis == 1) _foldArrow(canvas, rect, const Offset(0.2, 0.8), const Offset(0.2, 0.35));
      if (axis == 2) _foldArrow(canvas, rect, const Offset(0.2, 0.8), const Offset(0.2, 0.62));
    }
    _drawHoles(canvas, size, rect);
  }

  /// Where a point lands when folded over [fold]'s line (unit square).
  static Offset _across(String fold, Offset p) => switch (fold) {
        'v' => Offset(1 - p.dx, p.dy),
        'h' => Offset(p.dx, 1 - p.dy),
        'd' => Offset(p.dy, p.dx),
        _ => Offset(1 - p.dy, 1 - p.dx),
      };

  /// An arrow from [from] to [to] (unit square): the direction of a fold.
  void _foldArrow(Canvas canvas, Rect rect, Offset from, Offset to) {
    Offset at(Offset u) => Offset(rect.left + u.dx * rect.width, rect.top + u.dy * rect.height);
    final a = at(from), b = at(to);
    final paint = Paint()
      ..color = _hole
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, paint);
    final d = (b - a) / (b - a).distance, n = Offset(-d.dy, d.dx);
    final head = rect.width * 0.09;
    canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo((b - d * head + n * head * 0.55).dx, (b - d * head + n * head * 0.55).dy)
          ..lineTo((b - d * head - n * head * 0.55).dx, (b - d * head - n * head * 0.55).dy)
          ..close(),
        Paint()..color = _hole);
  }

  static Path _poly(Rect rect, List<Offset> pts) {
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
    canvas.drawPath(paper, Paint()..color = _paperColor);
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
      // Arrow from the flap's middle (the mean of points inside it; a
      // triangle's bounding box centre lies on the fold) to where it lands.
      var sum = Offset.zero;
      var count = 0;
      for (int i = 0; i < 20; i++) {
        for (int j = 0; j < 20; j++) {
          final q = Offset((i + 0.5) / 20, (j + 0.5) / 20);
          if (flap.contains(Offset(rect.left + q.dx * rect.width, rect.top + q.dy * rect.height))) {
            sum += q;
            count++;
          }
        }
      }
      final u = count == 0 ? const Offset(0.5, 0.5) : sum / count.toDouble();
      final v = _across(folds[step], u);
      _foldArrow(canvas, rect, Offset.lerp(u, v, 0.1)!, Offset.lerp(u, v, 0.8)!);
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

  void _drawHoles(Canvas canvas, Size size, Rect rect) => _paintHoles(canvas, size, rect, data['holes'] as List? ?? const []);

  static void _paintHoles(Canvas canvas, Size size, Rect rect, List holes) {
    final holePaint = Paint()
      ..color = _hole
      ..style = PaintingStyle.fill;
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

/// The answer explanation for a punch-hole question: the folded, punched
/// paper opening again, last fold first. [stages] are
/// [UnfoldExplanation.stages] (`stages[k]` = holes with k folds still
/// closed); [progress] runs from 0 (fully folded) to `folds.length` (fully
/// open, drawn exactly like the unfolded answer card).
class UnfoldPainter extends CustomPainter {
  final List<String> folds;
  final List<List<Map<String, dynamic>>> stages;
  final double progress;

  UnfoldPainter({required this.folds, required this.stages, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final margin = size.width * 0.06;
    final rect = Rect.fromLTWH(margin, margin, size.width - margin * 2, size.height - margin * 2);
    final p = progress.clamp(0.0, folds.length.toDouble());
    final opened = p.floor();
    final k = folds.length - opened; // folds still closed
    final t = p - opened; // how far the next fold has opened

    final square = PunchPainter._poly(rect, const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)]);
    PunchPainter._dashedPath(
        canvas,
        square,
        Paint()
          ..color = PunchPainter._foldLine.withValues(alpha: 0.35)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
        3,
        3);

    var paper = square;
    for (int i = 0; i < k; i++) {
      paper = Path.combine(PathOperation.intersect, paper, PunchPainter._poly(rect, PunchPainter._kept[folds[i]]!));
    }
    final border = Paint()
      ..color = PunchPainter._border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    void layer(Color fill) {
      canvas.drawPath(paper, Paint()..color = fill);
      canvas.drawPath(paper, border);
      PunchPainter._paintHoles(canvas, size, rect, stages[k]);
    }

    layer(PunchPainter._paper);
    if (k == 0 || t == 0) return;

    // The flap swings about the fold line: x' = x - (1+s)((x-p).n)n, from
    // s = -1 (lying on the paper) to s = 1 (opened out = mirror image).
    final l = PunchPainter._line[folds[k - 1]]!;
    final a = Offset(rect.left + l[0].dx * rect.width, rect.top + l[0].dy * rect.height);
    final b = Offset(rect.left + l[1].dx * rect.width, rect.top + l[1].dy * rect.height);
    final d = (b - a) / (b - a).distance;
    final nx = -d.dy, ny = d.dx;
    final s = -cos(pi * t);
    final f = 1 + s;
    final pn = a.dx * nx + a.dy * ny;
    final m = Float64List.fromList([
      1 - f * nx * nx, -f * nx * ny, 0, 0, //
      -f * nx * ny, 1 - f * ny * ny, 0, 0,
      0, 0, 1, 0,
      f * pn * nx, f * pn * ny, 0, 1,
    ]);
    canvas.save();
    canvas.transform(m);
    layer(Color.lerp(PunchPainter._fold, PunchPainter._paper, t)!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant UnfoldPainter old) => old.progress != progress || old.stages != stages;
}
