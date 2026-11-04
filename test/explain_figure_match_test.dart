// Figure Match: a copy of the target flies onto the correct option, turning
// or flipping first if the option is a turned copy, and covers it exactly.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

void main() {
  test('every figure match question: the target flies onto the answer', () {
    checkTopic('figure_match', {'figure_match', 'figure_match_exam', 'figure_match_hard'}, rule: (q, scene) {
      final fly = scene.steps.whereType<FlyStep>().single;
      expect(fly.to, scene.answerSlot);
      // A match never changes a part: only turns and flips.
      expect(fly.beats.every((b) => b is TurnBeat || b is FlipBeat), isTrue, reason: '${q.type}: ${fly.beats.map((b) => b.runtimeType)}');
      if (q.type == 'figure_match_hard') expect(fly.beats, isNotEmpty, reason: 'hard answers are turned copies');
    });
  });
}
