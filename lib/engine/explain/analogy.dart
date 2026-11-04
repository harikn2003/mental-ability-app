import 'dart:ui' show Offset, Size;

import '../morph.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// Analogy: a copy of A flies onto B changing as it goes (A : B); then a
/// copy of C makes the same changes and lands in the "?" (C : answer).
Scene? analogyScene(ReasoningQuestion q) {
  final p = Morph.plain(q.puzzle);
  if (p['A'] is! Map || p['B'] is! Map || p['C'] is! Map) return null;
  final a = Morph.plain(p['A'] as Map), b = Morph.plain(p['B'] as Map), c = Morph.plain(p['C'] as Map);
  final answer = Morph.plain(q.options[q.correctIndex]);
  final ab = Morph.diff(a, b);
  if (ab == null) return null;
  // A half turn goes the same way in both pairs.
  final sign = ab.whereType<TurnBeat>().any((t) => t.degrees < 0) ? -1 : 1;
  final cd = Morph.diff(c, answer, turnSign: sign);
  if (cd == null) return null;
  final size = a['type'] == 'line_fig' ? 80.0 : 72.0;
  const gap = 44.0, row = 22.0;
  return Scene(
    extent: Size(2 * size + gap, 2 * size + row + 8),
    slots: [
      Slot(figure: a, at: const Offset(0, 4), size: size),
      Slot(figure: b, at: Offset(size + gap, 4), size: size),
      Slot(figure: c, at: Offset(0, size + row + 4), size: size),
      Slot(at: Offset(size + gap, size + row + 4), size: size, question: true),
    ],
    steps: [
      FlyStep(0, 1, ab, figure: a, weight: 1.5),
      const PulseStep([1], weight: 0.5),
      FlyStep(2, 3, cd, figure: c, weight: 1.5),
      const RevealStep(),
    ],
    answerSlot: 3,
  );
}
