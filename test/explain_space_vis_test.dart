// Space Visualisation: every piece turns into place and slides into the
// "?"; together they make exactly the answer figure.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

void main() {
  test('every space-vis question: the pieces tile the answer', () {
    checkTopic('space_vis', {'space_vis_pieces'}, rule: (q, scene) {
      final pieces = q.puzzle['pieces'] as List;
      final flies = scene.steps.whereType<FlyStep>().toList();
      expect(flies, hasLength(pieces.length), reason: 'one move per piece');
      expect(flies.map((f) => f.from).toSet(), hasLength(pieces.length), reason: 'every piece moves once');
      for (final f in flies) {
        expect(f.to, scene.answerSlot);
        expect(f.beats.every((b) => b is TurnBeat || b is FlipBeat || b is MoveBeat), isTrue, reason: '${f.beats}');
        expect(f.land, isNotNull, reason: 'a piece lands on the pieces already there');
      }
      // Each landing adds lines and keeps the ones already there.
      Set<String> segs(Map m) => {for (final s in m['segs'] as List) (s as List).join(',')};
      for (int i = 1; i < flies.length; i++) {
        expect(Morph.same(flies[i - 1].land!, flies[i].land!), isFalse);
        // (The last landing is the answer, drawn on its own lattice: checked below.)
        if (i < flies.length - 1) expect(segs(flies[i].land!).containsAll(segs(flies[i - 1].land!)), isTrue, reason: 'a landing drops lines already there');
      }
      expect(segs(flies.last.land!), segs(q.options[q.correctIndex]));
    });
  });
}
