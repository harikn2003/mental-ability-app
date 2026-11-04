import 'dart:ui' show Offset, Size;

import '../line_figure.dart';
import '../morph.dart';
import '../morph_line.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// Geo Completion: the correct piece turns back the right way up (if it is
/// shown turned) and slides into the gap; the completed shape glows.
Scene? geoScene(ReasoningQuestion q) {
  final puzzle = Morph.plain(q.puzzle);
  final answer = Morph.plain(q.options[q.correctIndex]);
  if (puzzle['piece'] is! Map) return null;
  final shape = Morph.plain(puzzle['piece'] as Map);
  const size = 100.0, gap = 56.0;
  List<Beat> beats;
  Map<String, dynamic>? landed;
  if (shape['type'] == 'geo_piece') {
    // Jigsaw: both halves are drawn in their own place within the shape, so
    // the option's box lands on the puzzle's box.
    if (answer['type'] != 'geo_piece' || answer['shape'] != shape['shape'] || answer['cut'] != shape['cut']) return null;
    beats = const [];
  } else if (shape['type'] == 'line_fig' && answer['type'] == 'line_fig') {
    // Grid cut: the option is the missing piece turned and drawn centred.
    final n = shape['w'] as int;
    final turns = ((puzzle['answer_turn'] as num?)?.toInt() ?? 0) % 4;
    final shown = LineFig.fromMap(answer);
    final upright = shown.rot((4 - turns) % 4).normalized();
    final gapCells = {for (int x = 0; x < n; x++) for (int y = 0; y < n; y++) (x, y)}.difference(LineFig.fromMap(shape).cells);
    // Where the piece sits: the shift that puts its cells on the gap.
    final minX = gapCells.map((c) => c.$1).reduce((a, b) => a < b ? a : b), minY = gapCells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final placed = upright.shift(minX, minY, n, n);
    if (!placed.cells.containsAll(gapCells) || placed.cells.length != gapCells.length) return null;
    final uprightCentred = {...upright.shift(0, 0, n, n).toMap(), 'center': true};
    landed = placed.toMap();
    final turned = turns != 0 && !Morph.same(answer, uprightCentred);
    final moved = !Morph.same(uprightCentred, landed);
    // The piece always ends written in place (the last beat lands on
    // [landed], which looks the same as the centred piece if it doesn't move).
    beats = [
      if (turned) TurnBeat(answer, moved ? uprightCentred : landed, turns == 3 ? 90 : -90.0 * turns),
      if (moved) MoveBeat(MorphLine.uncentred(uprightCentred), landed),
    ];
  } else {
    return null;
  }
  return Scene(
    extent: const Size(2 * size + gap, size + 8),
    slots: [
      Slot(figure: shape, at: const Offset(0, 4), size: size),
      Slot(figure: answer, at: const Offset(size + gap, 4), size: size),
      const Slot(at: Offset(0, 4), size: size), // the piece, once in the gap
    ],
    steps: [
      FlyStep(1, 2, beats, figure: beats.isEmpty ? (landed ?? answer) : answer, weight: 1.8),
      const PulseStep([0]),
      const RevealStep(),
    ],
    answerSlot: 1,
  );
}
