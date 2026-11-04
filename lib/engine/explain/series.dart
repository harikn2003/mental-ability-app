import 'dart:ui' show Offset, Size;

import '../morph.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// Figure Series: a copy of each frame flies to the next one changing on
/// the way - the same change every step - and the last frame flies into the
/// "?" making that change once more, becoming the answer.
Scene? seriesScene(ReasoningQuestion q) {
  final p = Morph.plain(q.puzzle);
  if (p['sequence'] is! List) return null;
  final seq = [for (final f in p['sequence'] as List) Morph.plain(f as Map)];
  if (seq.isEmpty) return null;
  final answer = Morph.plain(q.options[q.correctIndex]);
  final frames = [...seq, answer];
  // A half turn goes the way the series turns.
  var sign = 1;
  for (int i = 0; i + 1 < frames.length; i++) {
    final turn = Morph.diff(frames[i], frames[i + 1])?.whereType<TurnBeat>().where((t) => t.degrees.abs() != 180).firstOrNull;
    if (turn != null) {
      sign = turn.degrees < 0 ? -1 : 1;
      break;
    }
  }
  final steps = <SceneStep>[];
  for (int i = 0; i + 1 < frames.length; i++) {
    final beats = Morph.diff(frames[i], frames[i + 1], turnSign: sign);
    if (beats == null) return null;
    steps.add(FlyStep(i, i + 1, beats, figure: frames[i], weight: i + 2 == frames.length ? 1.2 : 1));
  }
  final size = seq.first['type'] == 'line_fig' || seq.first['type'] == 'mirror_text' ? 80.0 : 68.0;
  const gap = 18.0;
  final n = frames.length;
  return Scene(
    extent: Size(n * size + (n - 1) * gap, size + 8),
    slots: [
      for (int i = 0; i < n; i++) Slot(figure: i < seq.length ? seq[i] : null, at: Offset(i * (size + gap), 4), size: size, question: i == seq.length),
    ],
    steps: [...steps, const RevealStep()],
    answerSlot: seq.length,
  );
}
