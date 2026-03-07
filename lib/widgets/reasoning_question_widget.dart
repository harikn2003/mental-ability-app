import 'package:flutter/material.dart';

import '../engine/question_rule.dart';
import '../painters/reasoning_painter.dart';

class ReasoningQuestionWidget extends StatelessWidget {
  final QuestionRule rule;

  const ReasoningQuestionWidget({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: ReasoningPainter(
        shape: rule.shape,
        rotation: rule.rotation,
        elements: rule.elements,
      ),
    );
  }
}
