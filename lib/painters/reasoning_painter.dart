import 'dart:math';

import 'package:flutter/material.dart';

class ReasoningPainter extends CustomPainter {
  final int shape;
  final int rotation;
  final int elements;

  ReasoningPainter({
    required this.shape,
    required this.rotation,
    required this.elements,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * pi / 2);

    switch (shape) {
      case 0:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 80, height: 80),
          paint,
        );
        break;

      case 1:
        canvas.drawCircle(Offset.zero, 40, paint);
        break;

      case 2:
        Path triangle = Path();
        triangle.moveTo(0, -40);
        triangle.lineTo(40, 40);
        triangle.lineTo(-40, 40);
        triangle.close();
        canvas.drawPath(triangle, paint);
        break;

      case 3:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 80, height: 80),
          paint..color = Colors.blue,
        );
        break;

      case 4:
        canvas.drawLine(Offset(-40, -40), Offset(40, 40), paint);
        canvas.drawLine(Offset(-40, 40), Offset(40, -40), paint);
        break;
    }

    for (int i = 0; i < elements; i++) {
      canvas.drawCircle(
        Offset(-30 + i * 30, 30),
        5,
        Paint()..color = Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
