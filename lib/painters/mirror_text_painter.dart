import 'dart:math';

import 'package:flutter/material.dart';

/// MirrorTextPainter renders a letter, digit, or clock face —
/// optionally mirrored on horizontal or vertical axis.
///
/// data keys:
///   'content'       : String  — letter/digit e.g. "R", "3"
///   'is_clock'      : bool    — render as clock face instead
///   'clock_hour'    : int     — hour hand position (1-12)
///   'clock_minute'  : int     — minute (0-59)
///   'mirror_h'      : bool    — flip horizontally (left-right)
///   'mirror_v'      : bool    — flip vertically   (top-bottom)
class MirrorTextPainter extends CustomPainter {
  final Map<String, dynamic> data;

  MirrorTextPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final bool isClock = data['is_clock'] ?? false;
    final bool mirrorH = data['mirror_h'] ?? false;
    final bool mirrorV = data['mirror_v'] ?? false;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // Apply mirror transforms
    canvas.scale(mirrorH ? -1.0 : 1.0, mirrorV ? -1.0 : 1.0);

    if (isClock) {
      _drawClock(canvas, size);
    } else {
      _drawText(canvas, size);
    }

    canvas.restore();
  }

  void _drawText(Canvas canvas, Size size) {
    final content = (data['content'] as String? ?? 'A').toUpperCase();
    final fontSize = size.width * 0.60;

    final tp = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw centred (we're already at centre due to translate above)
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  void _drawClock(Canvas canvas, Size size) {
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

    // Face
    canvas.drawCircle(Offset.zero, r, fillPaint);
    canvas.drawCircle(Offset.zero, r, borderPaint);

    // Hour marks
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final inner = i % 3 == 0 ? r * 0.75 : r * 0.85;
      canvas.drawLine(
        Offset(sin(a) * inner, -cos(a) * inner),
        Offset(sin(a) * r * 0.95, -cos(a) * r * 0.95),
        handPaint,
      );
    }

    // Hour hand
    final hourAngle = (hour % 12 + minute / 60.0) * pi / 6;
    canvas.drawLine(
      Offset.zero,
      Offset(sin(hourAngle) * r * 0.55, -cos(hourAngle) * r * 0.55),
      handPaint..strokeWidth = 3.0,
    );

    // Minute hand
    final minuteAngle = minute * pi / 30;
    canvas.drawLine(
      Offset.zero,
      Offset(sin(minuteAngle) * r * 0.78, -cos(minuteAngle) * r * 0.78),
      handPaint..strokeWidth = 1.8,
    );

    // Centre dot
    canvas.drawCircle(Offset.zero, r * 0.07, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
