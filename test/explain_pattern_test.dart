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

/// What changes from [a] to [b], value by value: amounts by how much (turns
/// modulo a full turn), named things (shape, fill...) by what they become; on/off
/// switches by toggling. Two pairs make
/// "the same change" only if these are equal.
const _shades = ['white', 'grey40', 'grey10', 'black'];

Map<String, String> _change(Map a, Map b) {
  final fa = <String, dynamic>{}, fb = <String, dynamic>{};
  void flat(dynamic v, String path, Map<String, dynamic> out) {
    if (v is Map) {
      for (final e in v.entries) {
        flat(e.value, '$path.${e.key}', out);
      }
    } else if (v is List) {
      for (int i = 0; i < v.length; i++) {
        flat(v[i], '$path[$i]', out);
      }
    } else {
      out[path] = v;
    }
  }
  flat(a, '', fa);
  flat(b, '', fb);
  final out = <String, String>{};
  for (final k in {...fa.keys, ...fb.keys}) {
    final x = fa[k], y = fb[k];
    final key = k.substring(k.lastIndexOf('.') + 1);
    const named = {'shape', 'inner', 'filled', 'mirror', 'missingCorner', 'fill'};
    if (x is num && y is num && !named.contains(key)) {
      if ((x - y).abs() < 1e-9) continue;
      var d = y - x;
      if (k.endsWith('.rotation')) d %= 4;
      if (k.endsWith('.rot')) d %= 360;
      out[k] = 'by ${d.toStringAsFixed(4)}';
    } else if (k.endsWith('.fill') && _shades.contains(x) && _shades.contains(y)) {
      // Sandia fills step through a cycle of shades: compare the steps.
      out[k] = 'shade by ${(_shades.indexOf(y as String) - _shades.indexOf(x as String)) % _shades.length}';
    } else if (x is bool && y is bool) {
      if (x != y) out[k] = 'toggles';
    } else if ('$x' != '$y') {
      out[k] = 'to $y';
    }
  }
  return out;
}

void main() {
  test('every pattern question', () {
    final alone = <String, int>{};
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
        // (Dual-rule grids whose dots hit the generator's cap of 4 break
        // the count progression, so no pair shows the gap's change.)
        expect(q.type, anyOf('sandia_full_matrix', 'matrix_dual_rule'), reason: '${q.type}: no example pair');
        expect(flies.single.to, missing);
        alone[q.type] = (alone[q.type] ?? 0) + 1;
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
      final cells = [for (final c in q.puzzle['cells'] as List) Morph.plain(c as Map)];
      expect(_change(cells[ans.from], q.options[q.correctIndex]), _change(cells[ref.from], cells[ref.to]),
          reason: '${q.type}: the example changes by other amounts than the gap');
    });
    // Sandia grids whose rule spreads shapes and shades over a row (no cell
    // changes into the next) have no honest example pair: about a fifth.
    expect(alone['sandia_full_matrix'] ?? 0, lessThanOrEqualTo(120), reason: 'too many Sandia grids without an example pair: $alone');
    expect(alone['matrix_dual_rule'] ?? 0, lessThanOrEqualTo(5), reason: 'too many dual-rule grids without an example pair: $alone');
  });
}
