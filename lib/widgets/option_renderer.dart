import 'package:flutter/material.dart';

import '../painters/figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';

/// OptionRenderer — renders one answer option.
/// mirror_text and punch_hole have their own painters;
/// everything else uses FigurePainter.
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
    return FigureWidget(data: data, size: size);
  }
}