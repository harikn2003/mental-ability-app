import 'dart:math';

import 'reasoning_question.dart';

class ReasoningGenerator {
  static final Random random = Random();

  static ReasoningQuestion generate(String category) {
    switch (category) {
      case "pattern":
        return _patternRotation();

      case "mirror":
        return _mirrorQuestion();

      case "odd_man":
        return _oddManQuestion();

      case "analogy":
        return _analogyQuestion();

      default:
        return _patternRotation();
    }
  }

  /// PATTERN ROTATION QUESTION
  /// Example: ▲ → ▲ rotated 90° → ▲ rotated 180° → ?

  static ReasoningQuestion _patternRotation() {
    int shape = random.nextInt(3); // 0 circle,1 square,2 triangle

    int startRotation = random.nextInt(4); // 0 90 180 270

    int correctRotation = (startRotation + 3) % 4;

    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({"shape": shape, "rotation": correctRotation});
      } else {
        options.add({"shape": shape, "rotation": random.nextInt(4)});
      }
    }

    return ReasoningQuestion(
      category: "pattern",
      type: "rotation",
      puzzle: {"shape": shape, "startRotation": startRotation},
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// MIRROR QUESTION

  static ReasoningQuestion _mirrorQuestion() {
    int shape = random.nextInt(3);

    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];

    for (int i = 0; i < 4; i++) {
      options.add({"shape": shape, "mirror": i == correctIndex});
    }

    return ReasoningQuestion(
      category: "mirror",
      type: "mirror",
      puzzle: {"shape": shape},
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// ODD MAN OUT

  static ReasoningQuestion _oddManQuestion() {
    int commonShape = random.nextInt(3);

    int oddShape = (commonShape + 1) % 3;

    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({"shape": oddShape});
      } else {
        options.add({"shape": commonShape});
      }
    }

    return ReasoningQuestion(
      category: "odd_man",
      type: "odd",
      puzzle: {},
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// ANALOGY QUESTION

  static ReasoningQuestion _analogyQuestion() {
    int shape = random.nextInt(3);

    int rotation = random.nextInt(4);

    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({"shape": shape, "rotation": rotation});
      } else {
        options.add({"shape": shape, "rotation": random.nextInt(4)});
      }
    }

    return ReasoningQuestion(
      category: "analogy",
      type: "analogy",
      puzzle: {"shape": shape},
      options: options,
      correctIndex: correctIndex,
    );
  }
}
