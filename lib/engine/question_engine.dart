import 'dart:math';

import 'question_rule.dart';

class QuestionEngine {
  static final Random random = Random();

  static QuestionRule generate(String category) {
    switch (category) {
      case "pattern":
        return _patternRule();

      case "mirror":
        return _mirrorRule();

      case "analogy":
        return _analogyRule();

      case "odd_man":
        return _oddRule();

      default:
        return _patternRule();
    }
  }

  static QuestionRule _patternRule() {
    return QuestionRule(
      type: "pattern",
      shape: random.nextInt(5),
      rotation: random.nextInt(4),
      elements: random.nextInt(3),
      oddIndex: -1,
    );
  }

  static QuestionRule _mirrorRule() {
    return QuestionRule(
      type: "mirror",
      shape: random.nextInt(5),
      rotation: random.nextInt(4),
      elements: random.nextInt(3),
      oddIndex: -1,
    );
  }

  static QuestionRule _analogyRule() {
    return QuestionRule(
      type: "analogy",
      shape: random.nextInt(5),
      rotation: random.nextInt(4),
      elements: random.nextInt(3),
      oddIndex: -1,
    );
  }

  static QuestionRule _oddRule() {
    return QuestionRule(
      type: "odd",
      shape: random.nextInt(5),
      rotation: random.nextInt(4),
      elements: random.nextInt(3),
      oddIndex: random.nextInt(4),
    );
  }
}
