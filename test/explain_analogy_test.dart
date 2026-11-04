// Analogy: A changes into B change by change; then C makes the same changes
// and becomes the answer.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

/// What a change is, for comparing A:B with C:D (a turn's angle counts; a
/// swap's details don't, C is a different figure).
String _kind(Beat b) => switch (b) {
      TurnBeat(:final degrees, :final part) => 'turn ${((degrees % 360) + 360) % 360} ${part ?? ''}',
      FlipBeat() => 'flip',
      ResizeBeat() => 'resize',
      MoveBeat() => 'move',
      GlideBeat() => 'glide',
      RegroupBeat() => 'regroup',
      SwapBeat(:final changed) => 'swap ${(changed.toList()..sort()).join(',')}',
    };

void main() {
  test('every analogy: C changes the way A changed', () {
    checkTopic('analogy', {
      'analogy_exam_turn', 'analogy_exam_corners', 'analogy_exam_nest',
      for (int r = 0; r < 10; r++) 'analogy_r$r',
      'hard_analogy_sandia_3layer',
    }, rule: (q, scene) {
      final flies = scene.steps.whereType<FlyStep>().toList();
      expect(flies, hasLength(2));
      expect(flies.first.from, 0);
      expect(flies.first.to, 1);
      expect(flies.last.from, 2);
      expect(flies.last.to, scene.answerSlot);
      final ab = flies.first.beats.map(_kind).toList(), cd = flies.last.beats.map(_kind).toList();
      // Turns, flips and slides must be the same. A swap sets a part to a
      // value (e.g. "the inner shape becomes a circle"); when C already has
      // it there's nothing to change, so C:D's swaps are some of A:B's.
      final moves = (List<String> l) => l.where((k) => !k.startsWith('swap')).toList();
      final swaps = (List<String> l) => l.where((k) => k.startsWith('swap')).toSet();
      expect(moves(cd), moves(ab), reason: '${q.type}: A:B is $ab but C:D is $cd');
      if (q.type.startsWith('analogy_r')) {
        // Classic figures: a part changed in only one pair still ends with
        // the same value in B and in the answer (it was already there).
        final b = Morph.plain(q.puzzle['B'] as Map), d = Morph.plain(q.options[q.correctIndex]);
        for (final k in swaps(ab).difference(swaps(cd)).union(swaps(cd).difference(swaps(ab)))) {
          final key = k.substring(5);
          expect(b[key], d[key], reason: '${q.type}: $key differs between B and the answer ($ab / $cd)');
        }
      } else {
        expect(swaps(ab).containsAll(swaps(cd)), isTrue, reason: '${q.type}: A:B is $ab but C:D is $cd');
      }
      if (ab.isEmpty) expect(cd, isEmpty, reason: '${q.type}: A stays the same but C changes');
    });
  });
}
