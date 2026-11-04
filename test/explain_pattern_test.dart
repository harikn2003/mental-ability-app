// Pattern: the 2x2 quarter that the answer copies flips or turns into the
// gap; in a 3x3 matrix, a pair of cells that changes the same way is shown
// first, then the same change lands in the "?" (or, for a logic layer, the
// two cells that combine fly in together).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

List<String> _moves(List<Beat> beats) => [
      for (final b in beats)
        switch (b) {
          TurnBeat(:final degrees, :final part) => 'turn ${((degrees % 360) + 360) % 360} ${part ?? ''}',
          FlipBeat() => 'flip',
          ResizeBeat() => 'resize',
          MoveBeat() => 'move',
          GlideBeat() => 'glide',
          RegroupBeat() => 'regroup',
          SwapBeat(:final changed) => 'swap ${(changed.toList()..sort()).join(',')}',
        },
    ];

void main() {
  test('every pattern question', () {
    var alone = 0;
    checkTopic('pattern', {
      'pattern_quarter', 'matrix_shape_cycle', 'matrix_dot_rotation', 'matrix_inner_shape', 'matrix_dual_rule', 'sandia_full_matrix',
    }, rule: (q, scene) {
      final missing = q.puzzle['missing'] as int? ?? 8;
      expect(scene.answerSlot, missing, reason: 'the answer lands in the gap');
      final flies = scene.steps.whereType<FlyStep>().toList() + [for (final t in scene.steps.whereType<TogetherStep>()) ...t.steps.whereType<FlyStep>()];
      if (q.type == 'pattern_quarter') {
        final fly = flies.single;
        expect(fly.to, missing);
        expect(fly.beats.every((b) => b is TurnBeat || b is FlipBeat), isTrue, reason: 'a quarter is a turned or mirrored copy');
        return;
      }
      final together = scene.steps.whereType<TogetherStep>().toList();
      if (together.isNotEmpty) {
        // Logic: two cells of the gap's row or column fly in and combine.
        final pair = together.single.steps.whereType<FlyStep>().toList();
        expect(pair, hasLength(2));
        final row = missing ~/ 3, col = missing % 3;
        final same = pair.every((f) => f.from ~/ 3 == row) || pair.every((f) => f.from % 3 == col);
        expect(same, isTrue, reason: '${q.type}: combined cells not in one row or column');
        return;
      }
      if (flies.length == 1) {
        // No pair changes like the gap (rare mixed-rule Sandia grids): the
        // nearest neighbour changes into the answer on its own.
        expect(q.type, 'sandia_full_matrix', reason: '${q.type}: no example pair');
        expect(flies.single.to, missing);
        alone++;
        return;
      }
      // Example pair first, then the same change into the gap.
      expect(flies, hasLength(2));
      final (ref, ans) = (flies.first, flies.last);
      expect(ans.to, missing);
      final dr = (ref.to ~/ 3) - (ref.from ~/ 3), dc = (ref.to % 3) - (ref.from % 3);
      expect((missing ~/ 3) - (ans.from ~/ 3), dr, reason: 'the example pair is a different step');
      expect((missing % 3) - (ans.from % 3), dc, reason: 'the example pair is a different step');
      expect(_moves(ans.beats), _moves(ref.beats), reason: '${q.type}: the example changes differently');
    });
    expect(alone, lessThanOrEqualTo(5), reason: 'too many grids without an example pair');
  });
}
