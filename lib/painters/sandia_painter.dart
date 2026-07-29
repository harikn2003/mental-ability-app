import 'dart:math';
import 'package:flutter/material.dart';

/// ===========================================================================
/// SANDIA FILL PATTERNS
/// Ported from gov.sandia.cognition.generator.matrix.fillpattern.*
///
/// The Java tool stores each pattern as a semi-transparent Paint (color, alpha)
/// meant to be composited over a white AWT panel background:
///   White  -> Color(1.0, 1.0, 1.0, a=0.00)
///   Grey75 -> Color(0.75,0.75,0.75, a=0.40)
///   Grey40 -> Color(0.40,0.40,0.40, a=0.50)
///   Grey10 -> Color(0.10,0.10,0.10, a=0.60)
///   Black  -> Color(0.00,0.00,0.00, a=0.75)
/// Flutter's CustomPainter draws onto a transparent surface, so those alpha
/// blends are pre-flattened here (blended = src*a + white*(1-a)) into opaque
/// RGB so the on-screen result matches the original tool exactly.
/// ===========================================================================
class SandiaFill {
  static const Map<String, Color> palette = {
    'white': Color(0xFFFFFFFF), // WhiteSGMFillPattern
    'grey75': Color(0xFFE6E6E6), // Grey75SGMFillPattern (lightest grey)
    'grey40': Color(0xFFB3B3B3), // Grey40SGMFillPattern
    'grey10': Color(0xFF757575), // Grey10SGMFillPattern
    'black': Color(0xFF404040), // BlackSGMFillPattern (darkest)
  };

  /// Order used by ChangeFillPatternSGMStructureFeature /
  /// FillPatternRepetitionSGMStructureFeature's default generator pool
  /// (SupplementalSGMStructureFeatureGenerator), lightest -> darkest.
  static const List<String> cycle = [
    'white',
    'grey75',
    'grey40',
    'grey10',
    'black',
  ];

  static Color of(String? key) => palette[key] ?? palette['white']!;

  static String next(String key) {
    final i = cycle.indexOf(key);
    return cycle[(i < 0 ? 0 : i + 1) % cycle.length];
  }
}

/// ===========================================================================
/// SandiaPainter
///
/// Supports two cell schemas so existing 'pattern' / 'figure_series' /
/// 'analogy' generators keep working untouched:
///
///  LEGACY layer  (surface: int code 0-10, fill: int 0-3, ...)
///    -> rendered by [_drawLegacyLayer], unchanged from the original tool.
///
///  AUTHENTIC layer ({'features': [...] })
///    -> a faithful port of an SGMCell: a list of SGMSurfaceFeature-like
///       maps, each with its own shape/size/rotation/position/scale/fill,
///       exactly mirroring gov.sandia...surface.*SGMSurfaceFeature and
///       gov.sandia...structure.supplemental.* transform semantics.
///       Used by the odd-man-out generators.
/// ===========================================================================
class SandiaPainter extends CustomPainter {
  final Map<String, dynamic> data;

  SandiaPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data['empty'] == true) return;

    // Optional outer cell frame (authentic-schema cells)
    if (data['grid_box'] == true) {
      _drawFrame(canvas, size);
    }

    final layers = data['layers'] as List? ?? [];
    if (layers.isEmpty) {
      _drawLegacyLayer(canvas, size, data);
      return;
    }

    for (final layer in layers) {
      final Map<String, dynamic> lm = Map<String, dynamic>.from(layer as Map);
      if (lm.containsKey('features')) {
        _drawAuthenticLayer(canvas, size, lm);
      } else {
        _drawLegacyLayer(canvas, size, lm);
      }
    }
  }

  void _drawFrame(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.9,
        height: size.height * 0.9,
      ),
      gridPaint,
    );
  }

  // =========================================================================
  // AUTHENTIC RENDERER (ports SGMSurfaceFeature + SGMFillPattern)
  // =========================================================================

  void _drawAuthenticLayer(
      Canvas canvas, Size size, Map<String, dynamic> layer) {
    if (layer['grid_box'] == true) {
      _drawFrame(canvas, size);
    }
    final features = layer['features'] as List? ?? [];
    for (final f in features) {
      _drawSurfaceFeature(canvas, size, Map<String, dynamic>.from(f as Map));
    }
  }

  /// Renders one SGMSurfaceFeature-equivalent: {shape, w, h, rot, cx, cy,
  /// scale, fill}. w/h are fractions of the cell's short side; cx/cy are
  /// fractions of cell width/height (default 0.5 = centered); rot is in
  /// degrees, matching AbstractSGMSurfaceFeature.rotation (mod 360).
  void _drawSurfaceFeature(
      Canvas canvas, Size size, Map<String, dynamic> f) {
    final String shape = f['shape'] as String? ?? 'ellipse';
    final double wFrac = ((f['w'] as num?) ?? 0.5).toDouble();
    final double hFrac = ((f['h'] as num?) ?? 0.5).toDouble();
    final double scale = ((f['scale'] as num?) ?? 1.0).toDouble();
    final int rot = ((f['rot'] as num?) ?? 0).toInt();
    final double cxFrac = ((f['cx'] as num?) ?? 0.5).toDouble();
    final double cyFrac = ((f['cy'] as num?) ?? 0.5).toDouble();
    final String fillKey = f['fill'] as String? ?? 'white';

    final double cellPx = min(size.width, size.height);
    final double w = wFrac * cellPx * scale;
    final double h = hFrac * cellPx * scale;
    final Offset center = Offset(cxFrac * size.width, cyFrac * size.height);

    final fillPaint = Paint()
      ..color = SandiaFill.of(fillKey)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot * pi / 180.0);

    if (shape == 'line') {
      final linePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), linePaint);
    } else {
      final path = _buildShapePath(shape, w, h);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    canvas.restore();
  }

  /// Builds a Path centered at the local origin, matching the point math of
  /// gov.sandia...surface.*SGMSurfaceFeature.makePath()/constructors exactly
  /// (translated from "centered at `position`" to "centered at origin",
  /// since rotation here is applied via canvas transform instead of the
  /// AffineTransform Java used).
  Path _buildShapePath(String shape, double w, double h) {
    final path = Path();
    final halfW = w / 2.0;
    final halfH = h / 2.0;
    final quarterW = halfW / 2.0;
    final quarterH = halfH / 2.0;

    switch (shape) {
      case 'ellipse':
      // EllipseSGMSurfaceFeature
        path.addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
        break;

      case 'rectangle':
      // RectangleSGMSurfaceFeature
        path.addRect(Rect.fromCenter(center: Offset.zero, width: w, height: h));
        break;

      case 'triangle':
      // TriangleSGMSurfaceFeature
        path.moveTo(-halfW, halfH);
        path.lineTo(halfW, halfH);
        path.lineTo(0, -halfH);
        path.close();
        break;

      case 'tee':
      // TeeSGMSurfaceFeature
        path.moveTo(-halfW, -halfH);
        path.lineTo(halfW, -halfH);
        path.lineTo(halfW, -quarterH);
        path.lineTo(quarterW, -quarterH);
        path.lineTo(quarterW, halfH);
        path.lineTo(-quarterW, halfH);
        path.lineTo(-quarterW, -quarterH);
        path.lineTo(-halfW, -quarterH);
        path.close();
        break;

      case 'diamond':
      // BUGFIX: the original Java DiamondSGMSurfaceFeature is an
      // off-center kite (left/right points sit at quarterH, not 0), which
      // I ported verbatim for source fidelity. In practice this makes the
      // shape look inconsistent across rotations/sizes - sometimes
      // reading as a diamond, sometimes as a pentagon or lopsided
      // triangle - which breaks the "is this the same shape, just
      // scaled/rotated" comparisons several odd-man-out rules depend on.
      // Using a proper symmetric rhombus trades a little source fidelity
      // for a shape that is reliably recognizable as itself.
        path.moveTo(0, -halfH);
        path.lineTo(halfW, 0);
        path.lineTo(0, halfH);
        path.lineTo(-halfW, 0);
        path.close();
        break;

      case 'trapezoid':
      // TrapezoidSGMSurfaceFeature
        path.moveTo(-halfW, halfH);
        path.lineTo(halfW, halfH);
        path.lineTo(quarterW, -halfH);
        path.lineTo(-quarterW, -halfH);
        path.close();
        break;

      default:
        path.addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
    }
    return path;
  }

  // =========================================================================
  // LEGACY RENDERER (unchanged) - kept for 'pattern' / 'figure_series' /
  // 'analogy' generators, which are out of scope for this pass.
  // =========================================================================

  void _drawLegacyLayer(Canvas canvas, Size size, Map<String, dynamic> layerData) {
    final int surfaceType = layerData['surface'] as int? ?? 0;
    final int fillPattern = layerData['fill'] as int? ?? 0; // 0=White, 1=Grey10, 2=Grey40, 3=DarkSlate
    final double scaleRatio = ((layerData['scale'] as num? ?? 2) / 2.0).toDouble();
    final int rotation = layerData['rotation'] as int? ?? 0;
    final bool mirrorH = layerData['mirror_h'] as bool? ?? false;
    final bool drawOutline = layerData['outline'] as bool? ?? true;
    final bool drawGridBox = layerData['grid_box'] as bool? ?? false;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = (size.width * 0.38) * scaleRatio;

    final Color fillColor = switch (fillPattern) {
      3 => const Color(0xFF1E293B),
      2 => const Color(0xFF64748B),
      1 => const Color(0xFFCBD5E1),
      _ => Colors.white,
    };

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(cx, cy);
    if (mirrorH) {
      canvas.scale(-1.0, 1.0);
    }
    canvas.rotate(rotation * pi / 2);
    canvas.translate(-cx, -cy);

    if (drawGridBox) {
      final gridRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.84,
        height: size.height * 0.84,
      );
      canvas.drawRect(gridRect, strokePaint);
    }

    final path = _getLegacySurfacePath(cx, cy, baseR, surfaceType);

    canvas.drawPath(path, fillPaint);
    if (drawOutline) {
      canvas.drawPath(path, strokePaint);
    }

    final int lines = layerData['lines'] as int? ?? 0;
    if (lines > 0) {
      final linePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (lines == 1) {
        canvas.drawLine(Offset(cx, cy - baseR * 0.85), Offset(cx, cy + baseR * 0.85), linePaint);
      } else if (lines == 2) {
        canvas.drawLine(Offset(cx, cy - baseR * 0.85), Offset(cx, cy + baseR * 0.85), linePaint);
        canvas.drawLine(Offset(cx - baseR * 0.85, cy), Offset(cx + baseR * 0.85, cy), linePaint);
      } else if (lines == 3) {
        canvas.drawLine(Offset(cx - baseR * 0.7, cy - baseR * 0.7), Offset(cx + baseR * 0.7, cy + baseR * 0.7), linePaint);
        canvas.drawLine(Offset(cx + baseR * 0.7, cy - baseR * 0.7), Offset(cx - baseR * 0.7, cy + baseR * 0.7), linePaint);
      } else if (lines >= 4) {
        canvas.drawLine(Offset(cx, cy - baseR * 0.85), Offset(cx - baseR * 0.6, cy + baseR * 0.85), linePaint);
        canvas.drawLine(Offset(cx, cy - baseR * 0.85), Offset(cx + baseR * 0.6, cy + baseR * 0.85), linePaint);
        canvas.drawLine(Offset(cx - baseR * 0.7, cy), Offset(cx + baseR * 0.7, cy), linePaint);
      }
    }

    final int dotPos = layerData['dot_pos'] as int? ?? -1;
    if (dotPos >= 0) {
      final dotPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;

      final double angle = dotPos * pi / 2;
      final double dist = baseR * 1.25;
      final dotCx = cx + cos(angle) * dist;
      final dotCy = cy + sin(angle) * dist;

      canvas.drawCircle(Offset(dotCx, dotCy), size.width * 0.055, dotPaint);
    }

    canvas.restore();
  }

  Path _getLegacySurfacePath(double cx, double cy, double r, int type) {
    final path = Path();
    switch (type) {
      case 0:
        path.moveTo(cx - r * 0.5, cy - r * 0.85);
        path.lineTo(cx + r * 0.5, cy - r * 0.85);
        path.lineTo(cx + r * 0.95, cy + r * 0.85);
        path.lineTo(cx - r * 0.95, cy + r * 0.85);
        path.close();
        break;
      case 1:
        path.addOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.85, height: r * 1.15));
        break;
      case 2:
        path.addRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.75, height: r * 0.95));
        break;
      case 3:
        path.moveTo(cx, cy - r * 1.1);
        path.lineTo(cx + r * 0.85, cy);
        path.lineTo(cx, cy + r * 1.25);
        path.lineTo(cx - r * 0.85, cy);
        path.close();
        break;
      case 4:
        path.moveTo(cx - r * 0.8, cy - r * 0.8);
        path.lineTo(cx + r * 0.8, cy + r * 0.8);
        path.lineTo(cx - r * 0.8, cy + r * 0.8);
        path.close();
        break;
      case 5:
        final w = r * 0.38;
        path.addRect(Rect.fromLTWH(cx - r * 0.85, cy - r * 0.85, r * 1.7, w));
        path.addRect(Rect.fromLTWH(cx - w / 2, cy - r * 0.85, w, r * 1.7));
        break;
      case 6:
        path.moveTo(cx - r * 0.95, cy - r * 0.85);
        path.lineTo(cx + r * 0.95, cy - r * 0.85);
        path.lineTo(cx + r * 0.5, cy + r * 0.85);
        path.lineTo(cx - r * 0.5, cy + r * 0.85);
        path.close();
        break;
      case 7:
        final sw = r * 0.45;
        path.moveTo(cx - r * 0.75, cy - r * 0.85);
        path.lineTo(cx - r * 0.75 + sw, cy - r * 0.85);
        path.lineTo(cx - r * 0.75 + sw, cy + r * 0.85 - sw);
        path.lineTo(cx + r * 0.75, cy + r * 0.85 - sw);
        path.lineTo(cx + r * 0.75, cy + r * 0.85);
        path.lineTo(cx - r * 0.75, cy + r * 0.85);
        path.close();
        break;
      case 8:
        for (int i = 0; i < 10; i++) {
          final R = i.isEven ? r * 1.1 : r * 0.48;
          final angle = i * pi / 5 - pi / 2;
          final x = cx + R * cos(angle);
          final y = cy + R * sin(angle);
          if (i == 0) path.moveTo(x, y);
          else path.lineTo(x, y);
        }
        path.close();
        break;
      case 9:
        final cw = r * 0.5;
        path.addRect(Rect.fromLTWH(cx - r * 0.85, cy - cw / 2, r * 1.7, cw));
        path.addRect(Rect.fromLTWH(cx - cw / 2, cy - r * 0.85, cw, r * 1.7));
        break;
      default:
        path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant SandiaPainter old) => old.data != data;
}

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