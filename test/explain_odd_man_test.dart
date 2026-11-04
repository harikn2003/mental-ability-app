// Odd Man Out: the scene shows what the three alike options share, the odd
// one is outlined red, and the answer (the odd one) ends in green.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

List<SceneStep> _flat(List<SceneStep> steps) => [
      for (final s in steps)
        if (s is TogetherStep) ..._flat(s.steps) else s,
    ];

List<Map<String, dynamic>> _features(Map f) => [
      for (final l in f['layers'] as List)
        for (final x in (l as Map)['features'] as List) Morph.plain(x as Map),
    ];

/// (top + middle) dots against the bottom row's dots.
(int, int) _sums(Map f) {
  final dots = _features(f).where((x) => x['shape'] == 'ellipse').toList();
  int row(double y) => dots.where((d) => ((d['cy'] as num) - y).abs() < 0.05).length;
  return (row(0.2) + row(0.52), row(0.84));
}

void main() {
  test('every odd-man question', () {
    checkTopic('odd_man', {
      'odd_letters', 'odd_letters_medium', for (final v in [0, 1, 2, 3, 4, 5, 6, 7, 10, 11]) 'odd_v$v', 'odd_count',
      'odd_man_mirror', 'odd_man_rotational_repetition', 'odd_man_scaling_repetition',
      'odd_man_translational_numerosity', 'odd_man_arithmetic',
    }, rule: (ReasoningQuestion q, Scene scene) {
      final odd = q.correctIndex;
      final alike = [for (int i = 0; i < 4; i++) if (i != odd) i];
      final opts = [for (final o in q.options) Morph.plain(o)];
      expect(scene.answerSlot, odd);
      final steps = _flat(scene.steps);
      final red = steps.whereType<PulseStep>().where((p) => p.colour != const PulseStep([]).colour).toList();
      expect(red.map((p) => p.slots), [[odd]], reason: '${q.type}: the odd one is outlined red once');
      final flies = steps.whereType<FlyStep>().toList();
      final morphs = steps.whereType<MorphStep>().toList();
      final ticks = steps.whereType<TickStep>().toList();
      switch (q.type) {
        case 'odd_man_mirror' || 'odd_letters' || 'odd_letters_medium':
          // The alike ones line up with the first by turning (letters: gliding).
          final ref = flies.first.to;
          expect(alike, contains(ref));
          expect(flies.map((f) => f.from).toSet(), alike.toSet().difference({ref}));
          final ok = q.type == 'odd_man_mirror' ? (Beat b) => b is TurnBeat : (Beat b) => b is GlideBeat;
          for (final f in flies) {
            expect(f.to, ref);
            expect(f.beats.every(ok), isTrue, reason: '${q.type}: ${f.beats}');
          }
          final oddWay = Morph.diff(opts[odd], opts[ref]) ?? const [];
          expect(oddWay.every(ok), isFalse, reason: '${q.type}: the odd one lines up too');
        case 'odd_count' || 'odd_man_translational_numerosity':
          expect(ticks, hasLength(4));
          final n = {for (final t in ticks) t.slot: t.count};
          expect({for (final i in alike) n[i]}, hasLength(1), reason: '${q.type}: alike counts differ $n');
          expect(n[odd], isNot(n[alike.first]));
        case 'odd_man_arithmetic':
          expect(morphs.where((m) => m.slot == odd), hasLength(2), reason: 'the odd one slides down and back');
          for (final i in alike) {
            final (s, b) = _sums(opts[i]);
            expect(s, b, reason: 'alike option $i: top + middle != bottom');
          }
          final (s, b) = _sums(opts[odd]);
          expect(s, isNot(b));
        case 'odd_man_rotational_repetition' || 'odd_man_scaling_repetition':
          // After the inner copy turns / grows, it lines up with the outer one
          // in the alike options only.
          for (int i = 0; i < 4; i++) {
            final m = morphs.firstWhere((m) => m.slot == i);
            final f = _features(m.beats.last.to);
            final (outer, inner) = (f[0], f[1]);
            final same = q.type == 'odd_man_rotational_repetition'
                ? (((inner['rot'] as num) - (outer['rot'] as num)) % 360).abs() < 0.01
                : ((inner['w'] as num) - (outer['w'] as num)).abs() < 0.001;
            expect(same, i != odd, reason: '${q.type}: option $i');
          }
        default:
          // One part differs: the three alike are the same figure, and a copy
          // of one changes into the odd one.
          for (final i in alike) {
            expect(Morph.same(opts[i], opts[alike.first]), isTrue, reason: '${q.type}: alike options differ');
          }
          expect(flies, hasLength(1));
          expect(flies.single.to, odd);
          expect(flies.single.beats, isNotEmpty);
      }
    });
  });
}
