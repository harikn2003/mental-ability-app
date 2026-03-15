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

  /// HARD PATTERN: Shape rotates AND toggles between Filled/Outlined.
  static ReasoningQuestion _patternRotation() {
    int shape = random.nextInt(5); // Now uses all 5 shapes
    int startRotation = random.nextInt(4);
    int step = random.nextBool() ? 1 : -1;
    bool startFill = random.nextBool();

    List<Map<String, dynamic>> sequence = [
      {"shape": shape, "rotation": startRotation, "filled": startFill},
      {
        "shape": shape,
        "rotation": (startRotation + step) % 4,
        "filled": !startFill
      },
      {
        "shape": shape,
        "rotation": (startRotation + step * 2) % 4,
        "filled": startFill
      },
    ];

    int correctRotation = (startRotation + step * 3) % 4;
    bool correctFill = !startFill; // 4th item toggles back
    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];
    List<String> usedSignatures = ["$correctRotation-$correctFill"];

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({
          "shape": shape,
          "rotation": correctRotation,
          "filled": correctFill
        });
      } else {
        int wrongRot;
        bool wrongFill;
        do {
          wrongRot = random.nextInt(4);
          wrongFill = random.nextBool();
        } while (usedSignatures.contains("$wrongRot-$wrongFill"));

        usedSignatures.add("$wrongRot-$wrongFill");
        options.add(
            {"shape": shape, "rotation": wrongRot, "filled": wrongFill});
      }
    }

    return ReasoningQuestion(
      category: "pattern",
      type: "rotation",
      puzzle: {"type": "series", "sequence": sequence},
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// MIRROR: (Standard, but uses the new shapes)
  static ReasoningQuestion _mirrorQuestion() {
    int shape = random.nextInt(5);
    int baseRotation = random.nextInt(4);
    bool isFilled = random.nextBool();
    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];
    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({
          "shape": shape,
          "rotation": baseRotation,
          "mirror": true,
          "filled": isFilled
        });
      } else {
        options.add({
          "shape": shape,
          "rotation": (baseRotation + 1 + i) % 4,
          "mirror": false,
          "filled": isFilled
        });
      }
    }

    return ReasoningQuestion(
      category: "mirror",
      type: "mirror",
      puzzle: {
        "type": "mirror",
        "target": {
          "shape": shape,
          "rotation": baseRotation,
          "mirror": false,
          "filled": isFilled
        }
      },
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// HARD ODD MAN OUT: Chirality Test. All 4 shapes are the SAME, but 1 is Mirrored.
  /// The user has to mentally rotate them to figure out which one is backward.
  static ReasoningQuestion _oddManQuestion() {
    int shape = random.nextInt(5);
    bool isFilled = random.nextBool();
    int correctIndex = random.nextInt(4);

    // We start with a base shape, and the "Odd Man" is the mirrored version of it.
    bool baseIsMirrored = random.nextBool();
    bool oddIsMirrored = !baseIsMirrored;

    List<Map<String, dynamic>> options = [];
    List<int> usedRotations = [];

    for (int i = 0; i < 4; i++) {
      int rot;
      do {
        rot = random.nextInt(4);
      } while (usedRotations.contains(rot));
      usedRotations.add(rot);

      if (i == correctIndex) {
        // The odd one out is mirrored differently, but still rotated randomly
        options.add({
          "shape": shape,
          "rotation": rot,
          "mirror": oddIsMirrored,
          "filled": isFilled
        });
      } else {
        // The 3 normal ones are identical, just rotated
        options.add({
          "shape": shape,
          "rotation": rot,
          "mirror": baseIsMirrored,
          "filled": isFilled
        });
      }
    }

    return ReasoningQuestion(
      category: "odd_man",
      type: "odd",
      puzzle: {"type": "odd_man", "variant_id": random.nextInt(10000)},
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// HARD ANALOGY: Shape advances + Fill state flips
  static ReasoningQuestion _analogyQuestion() {
    int shape1 = random.nextInt(5);
    int shape2 = (shape1 + 1 + random.nextInt(3)) %
        5; // A completely different shape

    // Rule: Rotate 90 degrees AND invert fill color
    bool fillA = random.nextBool();
    bool fillB = !fillA;
    int rotA = random.nextInt(4);
    int rotB = (rotA + 1) % 4;

    bool fillC = random.nextBool();
    bool fillD = !fillC; // Apply same rule to D
    int rotC = random.nextInt(4);
    int rotD = (rotC + 1) % 4; // Apply same rule to D

    int correctIndex = random.nextInt(4);

    List<Map<String, dynamic>> options = [];
    List<String> usedSignatures = ["$rotD-$fillD"];

    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add({"shape": shape2, "rotation": rotD, "filled": fillD});
      } else {
        int wrongRot;
        bool wrongFill;
        do {
          wrongRot = random.nextInt(4);
          wrongFill = random.nextBool();
        } while (usedSignatures.contains("$wrongRot-$wrongFill"));

        usedSignatures.add("$wrongRot-$wrongFill");
        options.add(
            {"shape": shape2, "rotation": wrongRot, "filled": wrongFill});
      }
    }

    return ReasoningQuestion(
      category: "analogy",
      type: "analogy",
      puzzle: {
        "type": "analogy",
        "A": {"shape": shape1, "rotation": rotA, "filled": fillA},
        "B": {"shape": shape1, "rotation": rotB, "filled": fillB},
        "C": {"shape": shape2, "rotation": rotC, "filled": fillC},
      },
      options: options,
      correctIndex: correctIndex,
    );
  }
}