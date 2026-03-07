import 'dart:math';

import 'package:flutter/material.dart';

class ShapePainter extends CustomPainter {
  final Map<String, dynamic> data;

  ShapePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    int shape = data["shape"] ?? 0;

    int rotation = data["rotation"] ?? 0;

    bool mirror = data["mirror"] ?? false;

    canvas.save();

    /// Apply rotation
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * pi / 2);

    /// Apply mirror
    if (mirror) {
      canvas.scale(-1, 1);
    }

    canvas.translate(-size.width / 2, -size.height / 2);

    switch (shape) {
      case 0:
        _drawCircle(canvas, size, paint);
        break;

      case 1:
        _drawSquare(canvas, size, paint);
        break;

      case 2:
        _drawTriangle(canvas, size, paint);
        break;

      default:
        _drawCircle(canvas, size, paint);
    }

    canvas.restore();
  }

  void _drawCircle(Canvas canvas, Size size, Paint paint) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.3,
      paint,
    );
  }

  void _drawSquare(Canvas canvas, Size size, Paint paint) {
    Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.6,
    );

    canvas.drawRect(rect, paint);
  }

  void _drawTriangle(Canvas canvas, Size size, Paint paint) {
    Path path = Path();

    path.moveTo(size.width / 2, size.height * 0.2);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.8, size.height * 0.8);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
