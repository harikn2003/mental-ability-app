import 'package:flutter/material.dart';

import '../painters/shape_painter.dart';

class OptionRenderer extends StatelessWidget {
  final Map<String, dynamic> data;

  const OptionRenderer({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(60, 60), painter: ShapePainter(data));
  }
}
