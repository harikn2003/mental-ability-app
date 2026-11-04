import 'dart:ui' show Offset, Size;

import '../morph.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// Figure Match: a copy of the target flies onto the correct option,
/// turning or flipping on the way if the option is a turned copy, and covers
/// it exactly.
Scene? figureMatchScene(ReasoningQuestion q) {
  final puzzle = Morph.plain(q.puzzle);
  final answer = Morph.plain(q.options[q.correctIndex]);
  final target = puzzle['subtype'] == 'letter'
      ? <String, dynamic>{'type': 'mirror_text', 'content': puzzle['content'], 'is_clock': false, 'mirror_h': false, 'mirror_v': false}
      : puzzle['target'] is Map
          ? Morph.plain(puzzle['target'] as Map)
          : null;
  if (target == null) return null;
  final beats = Morph.diff(target, answer);
  if (beats == null || beats.any((b) => b is! TurnBeat && b is! FlipBeat)) return null;
  const size = 80.0;
  return Scene(
    extent: const Size(2 * size + 64, size + 12),
    slots: [
      Slot(figure: target, at: const Offset(0, 6), size: size),
      Slot(figure: answer, at: const Offset(size + 64, 6), size: size),
    ],
    steps: [FlyStep(0, 1, beats, figure: target, weight: 1.6), const RevealStep()],
    answerSlot: 1,
  );
}
