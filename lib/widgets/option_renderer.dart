import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

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
        painter: EnhancedMirrorTextPainter(data),
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
    return EnhancedFigureWidget(data: data, size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enhanced Figure Widget & Painter with Density and Selective Mirror Trap
// ─────────────────────────────────────────────────────────────────────────────
class EnhancedFigureWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const EnhancedFigureWidget({super.key, required this.data, this.size = 64});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: EnhancedFigurePainter(data),
      );
}

class EnhancedFigurePainter extends CustomPainter {
  final Map<String, dynamic> data;
  static const Color _ink = Color(0xFF1E293B);

  const EnhancedFigurePainter(this.data);

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
    final bool dense = data['dense'] ?? false;
    final bool selectiveMirrorTrap = data['selective_mirror_trap'] ?? false;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * (dots > 0 ? 0.27 : 0.32);

    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;

    if (missing != 0) {
      _drawMissingCorner(canvas, r, cx, cy, missing, paint);
      _drawDots(canvas, dots, r, cx, cy, size);
      return;
    }

    canvas.save();
    canvas.translate(cx, cy);
    if (mirror) canvas.scale(-1.0, 1.0);
    canvas.rotate(rot * pi / 2);
    canvas.translate(-cx, -cy);

    final outerR = inner > 0 ? r * 1.10 : r;
    _drawShape(canvas, shape, outerR, cx, cy, paint);

    final strokeColor = filled ? Colors.white : _ink;

    // Inner shape with selective mirror trap support
    if (inner > 0) {
      canvas.save();
      // If selective mirror trap is active and shape is mirrored, cancel the horizontal scaling
      if (mirror && selectiveMirrorTrap) {
        canvas.translate(cx, cy);
        canvas.scale(-1.0, 1.0);
        canvas.translate(-cx, -cy);
      }

      final innerR = r * 0.56;
      final shadowPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.08)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      _drawShape(canvas, inner - 1, innerR * 1.03, cx, cy, shadowPaint);

      final innerPaint = Paint()
        ..color = strokeColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _drawShape(canvas, inner - 1, innerR, cx, cy, innerPaint);

      canvas.restore();
    }

    // Crossing lines with selective mirror trap support
    if (lines > 0) {
      final lp = Paint()
        ..color = strokeColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      canvas.save();
      // If selective mirror trap is active, draw the crossing lines unmirrored
      if (mirror && selectiveMirrorTrap) {
        canvas.translate(cx, cy);
        canvas.scale(-1.0, 1.0);
        canvas.translate(-cx, -cy);
      }

      for (int i = 1; i <= lines; i++) {
        final x = cx - r * 0.72 + (r * 1.44 / (lines + 1)) * i;
        canvas.drawLine(Offset(x, cy - r * 0.85), Offset(x, cy + r * 0.85), lp);
      }
      canvas.restore();
    }

    // Dense custom asymmetric decorator inside shape
    if (dense) {
      final densePaint = Paint()
        ..color = strokeColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.save();
      if (mirror && selectiveMirrorTrap) {
        canvas.translate(cx, cy);
        canvas.scale(-1.0, 1.0);
        canvas.translate(-cx, -cy);
      }

      // Draw asymmetric crossing lines at top right corner
      canvas.drawLine(
        Offset(cx + r * 0.45, cy - r * 0.45),
        Offset(cx + r * 0.75, cy - r * 0.45),
        densePaint,
      );
      canvas.drawLine(
        Offset(cx + r * 0.6, cy - r * 0.6),
        Offset(cx + r * 0.6, cy - r * 0.3),
        densePaint,
      );
      canvas.restore();
    }

    canvas.restore();

    _drawDots(canvas, dots, r, cx, cy, size);
  }

  static void _drawDots(Canvas canvas, int dots, double r,
      double cx, double cy, Size size) {
    if (dots <= 0) return;
    final dotR = size.width * 0.055;
    final gap = dotR * 2.6;
    final totalW = (dots - 1) * gap;
    final dotY = cy + r * 1.55;

    final outlinePaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < dots; i++) {
      final offset = Offset(cx - totalW / 2 + i * gap, dotY);
      canvas.drawCircle(offset, dotR * 1.05, outlinePaint);
    }

    final dp = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < dots; i++) {
      canvas.drawCircle(
          Offset(cx - totalW / 2 + i * gap, dotY), dotR, dp);
    }
  }

  static void _drawShape(Canvas canvas, int shape, double r,
      double cx, double cy, Paint paint) {
    switch (shape) {
      case 0:
        canvas.drawCircle(Offset(cx, cy), r, paint);
        break;
      case 1:
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, cy), width: r * 1.9, height: r * 1.9),
            paint);
        break;
      case 2:
        canvas.drawPath(Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.85)
          ..lineTo(cx + r * 0.85, cy + r * 0.85)..lineTo(
              cx - r * 0.85, cy + r * 0.85)
          ..close(), paint);
        break;
      case 3:
        canvas.drawPath(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r * 0.78, cy)..lineTo(cx, cy + r)..lineTo(
              cx - r * 0.78, cy)
          ..close(), paint);
        break;
      case 4:
        final w = r * 0.38;
        canvas.drawPath(Path()
          ..addRect(Rect.fromCenter(
              center: Offset(cx, cy), width: w, height: r * 1.9))..addRect(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: r * 1.9, height: w)),
            paint);
        break;
      case 5:
        canvas.drawPath(_polygon(cx, cy, r, 5, -pi / 2), paint);
        break;
      case 6:
        canvas.drawPath(_polygon(cx, cy, r, 6, 0), paint);
        break;
      case 7:
        canvas.drawPath(Path()
          ..moveTo(cx - r * 0.58, cy - r * 0.30)
          ..lineTo(cx + r * 0.08, cy - r * 0.30)..lineTo(
              cx + r * 0.08, cy - r * 0.62)..lineTo(cx + r * 0.82, cy)..lineTo(
              cx + r * 0.08, cy + r * 0.62)..lineTo(
              cx + r * 0.08, cy + r * 0.30)..lineTo(
              cx - r * 0.58, cy + r * 0.30)
          ..close(), paint);
        break;
      case 8:
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

  static void _drawMissingCorner(Canvas canvas, double r,
      double cx, double cy, int corner, Paint paint) {
    final h = r * 0.92;
    final tl = Offset(cx - h, cy - h);
    final tr = Offset(cx + h, cy - h);
    final br = Offset(cx + h, cy + h);
    final bl = Offset(cx - h, cy + h);

    final segs = [
      [tl, tr],
      [tr, br],
      [br, bl],
      [bl, tl],
    ];

    final int skipA = (corner == 1 || corner == 2) ? 0 : 2;
    final int skipB = (corner == 1 || corner == 3) ? 3 : 1;

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
  bool shouldRepaint(covariant EnhancedFigurePainter old) => old.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Enhanced Mirror Text Painter with Density and Selective Mirror Trap
// ─────────────────────────────────────────────────────────────────────────────
class EnhancedMirrorTextPainter extends CustomPainter {
  final Map<String, dynamic> data;

  EnhancedMirrorTextPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final bool isClock = data['is_clock'] ?? false;
    final bool mirrorH = data['mirror_h'] ?? false;
    final bool mirrorV = data['mirror_v'] ?? false;
    final bool dense = data['dense'] ?? false;
    final bool selectiveMirrorTrap = data['selective_mirror_trap'] ?? false;

    if (!isClock && (mirrorH || mirrorV)) {
      _paintWithTransform(canvas, size, mirrorH, mirrorV, dense, selectiveMirrorTrap);
    } else {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(mirrorH ? -1.0 : 1.0, mirrorV ? -1.0 : 1.0);

      if (isClock) {
        _drawClock(canvas, size, dense, selectiveMirrorTrap, mirrorH);
      } else {
        _drawText(canvas, size, dense, selectiveMirrorTrap);
      }

      canvas.restore();
    }
  }

  void _paintWithTransform(Canvas canvas, Size size, bool mirrorH, bool mirrorV, bool dense, bool selectiveMirrorTrap) {
    final recorder = PictureRecorder();
    final pictureCanvas = Canvas(recorder);

    pictureCanvas.translate(size.width / 2, size.height / 2);
    _drawText(pictureCanvas, size, dense, selectiveMirrorTrap);

    final picture = recorder.endRecording();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(mirrorH ? -1.0 : 1.0, mirrorV ? -1.0 : 1.0);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPicture(picture);
    canvas.restore();

    // If selective mirror trap is active for text, draw decorators outside of the mirrored scale
    if (dense && selectiveMirrorTrap) {
      _drawDecorators(canvas, size, false);
    }
  }

  void _drawText(Canvas canvas, Size size, bool dense, bool selectiveMirrorTrap) {
    final content = (data['content'] as String? ?? 'A').toUpperCase();

    final double fontSize;
    if (content.length == 1) {
      fontSize = size.width * 0.62;
    } else if (content.length <= 3) {
      fontSize = size.width * 0.42;
    } else if (content.length <= 6) {
      fontSize = size.width * 0.28;
    } else {
      fontSize = size.width * 0.22;
    }

    final double letterSpacing = content.length > 3 ? 1.5 : 0;
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0F172A),
      letterSpacing: letterSpacing,
    );

    // Measure each character to position them correctly
    final painters = <TextPainter>[];
    double totalWidth = 0;
    for (int i = 0; i < content.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: content[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
      totalWidth += tp.width + (i < content.length - 1 ? letterSpacing : 0);
    }

    double currentX = -totalWidth / 2;
    final int? trapIndex = data['trap_char_index'] as int?;

    for (int i = 0; i < content.length; i++) {
      final tp = painters[i];
      final charCenterX = currentX + tp.width / 2;

      canvas.save();
      // Translate to character center
      canvas.translate(charCenterX, 0.0);

      // If selective mirror trap is active for this character, apply a local scale(-1, 1)
      // to cancel out the global mirror scale(-1, 1).
      if (selectiveMirrorTrap && (trapIndex == i || trapIndex == -99)) {
        canvas.scale(-1.0, 1.0);
      }

      // Paint character centered
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      currentX += tp.width + letterSpacing;
    }

    // If NOT selective mirror trap, draw decorators inside transformed canvas
    if (dense && !selectiveMirrorTrap) {
      _drawDecorators(canvas, size, true);
    }
  }

  void _drawDecorators(Canvas canvas, Size size, bool isTransformed) {
    final double cx = isTransformed ? 0 : size.width / 2;
    final double cy = isTransformed ? 0 : size.height / 2;
    final double w = size.width;
    final double h = size.height;

    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    if (isTransformed) {
      // Coordinates inside translated/scaled canvas (centered around 0, 0)
      canvas.drawCircle(Offset(-w * 0.3, -h * 0.25), w * 0.04, dotPaint);
      canvas.drawLine(Offset(-w * 0.35, h * 0.3), Offset(w * 0.35, h * 0.3), paint);
      canvas.drawLine(Offset(w * 0.25, h * 0.3), Offset(w * 0.25, h * 0.38), paint);
    } else {
      // Coordinates in screen space (0 to w, 0 to h)
      canvas.drawCircle(Offset(w * 0.2, h * 0.25), w * 0.04, dotPaint);
      canvas.drawLine(Offset(w * 0.15, h * 0.8), Offset(w * 0.85, h * 0.8), paint);
      canvas.drawLine(Offset(w * 0.75, h * 0.8), Offset(w * 0.75, h * 0.88), paint);
    }
  }

  void _drawClock(Canvas canvas, Size size, bool dense, bool selectiveMirrorTrap, bool mirrorH) {
    final int hour = data['clock_hour'] ?? 3;
    final int minute = data['clock_minute'] ?? 0;
    final double r = size.width * 0.38;

    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, r, fillPaint);
    canvas.drawCircle(Offset.zero, r, borderPaint);

    // Highly dense concentric rings
    if (dense) {
      canvas.drawCircle(Offset.zero, r * 0.9, borderPaint..strokeWidth = 1.0);
      canvas.drawCircle(Offset.zero, r * 0.82, borderPaint..strokeWidth = 0.8);
    }

    // 12 Hour ticks
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final inner = i % 3 == 0 ? r * 0.75 : r * 0.85;
      canvas.drawLine(
        Offset(sin(a) * inner, -cos(a) * inner),
        Offset(sin(a) * r * 0.95, -cos(a) * r * 0.95),
        handPaint..strokeWidth = 2.0,
      );
    }

    // 60 Minute ticks if dense
    if (dense) {
      for (int i = 0; i < 60; i++) {
        if (i % 5 == 0) continue;
        final a = i * pi / 30;
        canvas.drawLine(
          Offset(sin(a) * r * 0.9, -cos(a) * r * 0.9),
          Offset(sin(a) * r * 0.95, -cos(a) * r * 0.95),
          handPaint..strokeWidth = 0.8,
        );
      }
    }

    // Draw hands - support selective mirror trap
    canvas.save();
    if (mirrorH && selectiveMirrorTrap) {
      canvas.scale(-1.0, 1.0); // cancel dialect flip
    }

    final hourAngle = (hour % 12 + minute / 60.0) * pi / 6;
    canvas.drawLine(
      Offset.zero,
      Offset(sin(hourAngle) * r * 0.55, -cos(hourAngle) * r * 0.55),
      handPaint..strokeWidth = 3.0,
    );

    final minuteAngle = minute * pi / 30;
    canvas.drawLine(
      Offset.zero,
      Offset(sin(minuteAngle) * r * 0.78, -cos(minuteAngle) * r * 0.78),
      handPaint..strokeWidth = 1.8,
    );

    canvas.restore();

    canvas.drawCircle(Offset.zero, r * 0.07, dotPaint);
  }

  @override
  bool shouldRepaint(covariant EnhancedMirrorTextPainter old) => true;
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
// Embedded figure option — three shapes overlaid / adjacent
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
    final s = size * 0.42;

    if (shapes.length >= 3) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: EnhancedFigureWidget(data: shapes[0], size: s),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: EnhancedFigureWidget(data: shapes[1], size: s),
            ),
            Positioned(
              bottom: 0,
              left: size / 2 - s / 2,
              child: EnhancedFigureWidget(data: shapes[2], size: s),
            ),
          ],
        ),
      );
    }

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
            child: EnhancedFigureWidget(data: shapes[0], size: s),
          ),
          Align(
            alignment: alignB,
            child: EnhancedFigureWidget(data: shapes[1], size: s),
          ),
        ],
      ),
    );
  }
}

// ── Geo piece option painter ─────────────────────────────────────────────────
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
