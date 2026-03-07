import 'package:flutter/material.dart';

import '../painters/shape_painter.dart';

class QuestionRenderer extends StatelessWidget {
  final Map<String, dynamic> puzzle;

  const QuestionRenderer({super.key, required this.puzzle});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 120),
      painter: ShapePainter(puzzle),
    );
  }
}
