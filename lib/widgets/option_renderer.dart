import 'package:flutter/material.dart';

import '../painters/figure_painter.dart';
import '../painters/mirror_text_painter.dart';
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

    if (type == 'mirror_text') {
      return CustomPaint(
          size: Size(size, size), painter: MirrorTextPainter(data));
    }
    if (type == 'punch_hole') {
      return CustomPaint(size: Size(size, size), painter: PunchPainter(data));
    }
    if (type == 'geo_cell') {
      return _GeoCell(data: data, size: size);
    }
    if (type == 'embedded_option') {
      return _EmbeddedOption(data: data, size: size);
    }
    return FigureWidget(data: data, size: size);
  }
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
        width: s, height: s,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    // cross
    return SizedBox(
      width: s, height: s,
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

  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Embedded figure option — two shapes overlaid / adjacent
// Shows two small shapes so student can see if the target is one of them
// ─────────────────────────────────────────────────────────────────────────────
class _EmbeddedOption extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;

  const _EmbeddedOption({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final shapes = (data['shapes'] as List).cast<Map<String, dynamic>>();
    final offset = data['offset'] as int? ?? 1;
    final s = size * 0.48; // each sub-shape size

    // offset 1=TR, 2=BR, 3=BL, 4=TL — where shape B sits relative to A
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
      width: size, height: size,
      child: Stack(
        children: [
          Align(
            alignment: alignA,
            child: FigureWidget(data: shapes[0], size: s),
          ),
          Align(
            alignment: alignB,
            child: FigureWidget(data: shapes[1], size: s),
          ),
        ],
      ),
    );
  }
}