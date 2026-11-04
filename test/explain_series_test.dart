// Figure Series: each frame changes into the next, the same change every
// step, and the last frame changes the same way into the "?".

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

/// The moves of a step (turns with their angle, flips, slides); swaps are
/// left out (a series may change a part to different values each step).
List<String> _moves(List<Beat> beats) => [
      for (final b in beats)
        switch (b) {
          TurnBeat(:final degrees, :final part) => 'turn ${((degrees % 360) + 360) % 360} ${part ?? ''}',
          FlipBeat() => 'flip',
          ResizeBeat() => 'resize',
          MoveBeat() => 'move',
          GlideBeat() => 'glide',
          RegroupBeat() => 'regroup',
          SwapBeat() => null,
        },
    ].whereType<String>().toList();

void main() {
  test('every series: frame to frame, then into the "?"', () {
    checkTopic('figure_series', {
      'series_exam_spokes', 'series_exam_symbols', 'series_exam_arrow', 'series_exam_turning',
      'series_letters', 'series_letters_medium', 'series_round', 'series_round_medium',
      'series_rotation', 'series_inner', 'series_inner_easy', 'series_dots', 'series_dots_rot',
      'series_fill_toggle', 'series_alt_dual', 'series_rot_fill', 'series_morph', 'hard_series_sandia_3layer',
    }, rule: (q, scene) {
      final seq = q.puzzle['sequence'] as List;
      final flies = scene.steps.whereType<FlyStep>().toList();
      expect(flies, hasLength(seq.length), reason: 'one move per step of the series');
      for (int i = 0; i < flies.length; i++) {
        expect(flies[i].from, i);
        expect(flies[i].to, i + 1);
      }
      expect(flies.last.to, scene.answerSlot);
      // The same move every step (every other step for alternating series).
      final every = q.type == 'series_alt_dual' ? 2 : 1;
      for (int i = every; i < flies.length; i++) {
        expect(_moves(flies[i].beats), _moves(flies[i - every].beats), reason: '${q.type}: step $i moves differently');
      }
    });
  });
}
