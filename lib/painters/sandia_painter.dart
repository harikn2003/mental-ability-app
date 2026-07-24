import 'dart:math';
import 'package:flutter/material.dart';

/// SandiaPainter - Renders 3-4 layer dense composite geometric cells
/// matching the exact visual style of the Sandia Matrix Generation Tool.
class SandiaPainter extends CustomPainter {
  final Map<String, dynamic> data;

  SandiaPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data['empty'] == true) return;

    final layers = data['layers'] as List? ?? [];
    if (layers.isEmpty) {
      _drawLayer(canvas, size, data);
      return;
    }

    // Draw all stacked layers from bottom (background) to top (grid overlay)
    for (final layer in layers) {
      _drawLayer(canvas, size, Map<String, dynamic>.from(layer as Map));
    }
  }

  void _drawLayer(Canvas canvas, Size size, Map<String, dynamic> layerData) {
    final int surfaceType = layerData['surface'] as int? ?? 0;
    final int fillPattern = layerData['fill'] as int? ?? 0; // 0=White, 1=Grey10, 2=Grey40, 3=Black
    final double scaleRatio = ((layerData['scale'] as num? ?? 2) / 2.0).toDouble();
    final int rotation = layerData['rotation'] as int? ?? 0;
    final bool drawOutline = layerData['outline'] as bool? ?? true;
    final bool drawGridBox = layerData['grid_box'] as bool? ?? false;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = (size.width * 0.38) * scaleRatio;

    // Sandia Grayscale Fill Colors
    final Color fillColor = switch (fillPattern) {
      3 => const Color(0xFF1E293B), // Black
      2 => const Color(0xFF64748B), // Grey40
      1 => const Color(0xFFCBD5E1), // Grey10
      _ => Colors.white,            // White
    };

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation * pi / 2);
    canvas.translate(-cx, -cy);

    // Render outer bounding grid frame if enabled for this layer
    if (drawGridBox) {
      final gridRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.82,
        height: size.height * 0.82,
      );
      canvas.drawRect(gridRect, strokePaint);
    }

    final path = _getSurfacePath(cx, cy, baseR, surfaceType);

    // Fill surface
    canvas.drawPath(path, fillPaint);

    // Draw outline
    if (drawOutline) {
      canvas.drawPath(path, strokePaint);
    }

    // Internal line overlays & bisectors
    final int lines = layerData['lines'] as int? ?? 0;
    if (lines > 0) {
      final linePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      if (lines == 1) {
        // Vertical bisector
        canvas.drawLine(Offset(cx, cy - baseR), Offset(cx, cy + baseR), linePaint);
      } else if (lines == 2) {
        // Crosshair (+)
        canvas.drawLine(Offset(cx, cy - baseR), Offset(cx, cy + baseR), linePaint);
        canvas.drawLine(Offset(cx - baseR, cy), Offset(cx + baseR, cy), linePaint);
      } else if (lines >= 3) {
        // Complex multi-strand rays / V-lines
        canvas.drawLine(Offset(cx, cy - baseR * 0.9), Offset(cx - baseR * 0.6, cy + baseR * 0.9), linePaint);
        canvas.drawLine(Offset(cx, cy - baseR * 0.9), Offset(cx + baseR * 0.6, cy + baseR * 0.9), linePaint);
        canvas.drawLine(Offset(cx - baseR * 0.7, cy), Offset(cx + baseR * 0.7, cy), linePaint);
      }
    }

    canvas.restore();
  }

  Path _getSurfacePath(double cx, double cy, double r, int type) {
    final path = Path();
    switch (type) {
      case 0: // Trapezoid
        path.moveTo(cx - r * 0.5, cy - r * 0.85);
        path.lineTo(cx + r * 0.5, cy - r * 0.85);
        path.lineTo(cx + r * 0.95, cy + r * 0.85);
        path.lineTo(cx - r * 0.95, cy + r * 0.85);
        path.close();
        break;
      case 1: // Oval / Ellipse
        path.addOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.9, height: r * 1.15));
        break;
      case 2: // Rectangle
        path.addRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.75, height: r * 0.95));
        break;
      case 3: // Diamond / Kite
        path.moveTo(cx, cy - r * 1.05);
        path.lineTo(cx + r * 0.85, cy);
        path.lineTo(cx, cy + r * 1.25);
        path.lineTo(cx - r * 0.85, cy);
        path.close();
        break;
      case 4: // Acute Triangle
        path.moveTo(cx, cy - r * 1.05);
        path.lineTo(cx + r * 0.85, cy + r * 0.85);
        path.lineTo(cx - r * 0.85, cy + r * 0.85);
        path.close();
        break;
      case 5: // Tee (T-Shape)
        final w = r * 0.38;
        path.addRect(Rect.fromLTWH(cx - r * 0.85, cy - r * 0.85, r * 1.7, w));
        path.addRect(Rect.fromLTWH(cx - w / 2, cy - r * 0.85, w, r * 1.7));
        break;
      case 6: // Inverted Trapezoid
        path.moveTo(cx - r * 0.95, cy - r * 0.85);
        path.lineTo(cx + r * 0.95, cy - r * 0.85);
        path.lineTo(cx + r * 0.5, cy + r * 0.85);
        path.lineTo(cx - r * 0.5, cy + r * 0.85);
        path.close();
        break;
      default: // Circle
        path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant SandiaPainter old) => old.data != data;
}

/// Convenience Widget wrapping SandiaPainter
class SandiaWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const SandiaWidget({super.key, required this.data, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: SandiaPainter(data),
    );
  }
}